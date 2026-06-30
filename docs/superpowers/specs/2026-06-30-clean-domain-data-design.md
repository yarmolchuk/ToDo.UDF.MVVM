# Clean Architecture — Domain & Data Foundation (#4) — Design

**Status:** Approved design, ready for plan.
**Date:** 2026-06-30
**Context:** First of two sub-projects in the full-Clean pivot. #4 introduces the Domain + Data layers and rewires the existing UDF ViewModels to consume them. #5 (separate spec) assembles the flow: full coordinator lifecycle, routing, save→list refresh, App-root switch.
**References:** canonical house doc `/Users/MAC/Downloads/MVVM+Coordinator+Clean_Architecture_overview.pdf`; concrete reference impl = Ledger (`/Users/MAC/Documents/Ledger`, Transactions feature). Mirror Ledger's exact shapes.

---

## Goal

Take ToDo from UI-only (sample array passed into the list VM) to a real Clean stack: a SwiftData-backed `TasksRepository` behind stateless UseCases, consumed by the existing `@Observable` UDF ViewModels. Screen behaviour is preserved; tasks now persist; toggling and saving go through the data layer.

## Scope

**In #4:** Domain layer (entities, repository protocol, use cases); Data layer (SwiftData entity + repository + in-memory repository + composition/seed); rewire `TaskListViewModel` and `NewTaskViewModel` to consume use cases (toggle/save become async, list loads on appear); minimal DI to build the use-case bundle and inject it through `UIFactory`.

**Out of #4 → deferred to #5:** `TaskRoute` + `navigationDestination`; wiring `createTaskRequested`/`saveRequested`/`dismissForm`/`finishCreated` to real navigation; success screen carrying the created task; full coordinator lifecycle (`onComplete`/`start()` + `Feature` enum + `AppCoordinator` + composition root); switching the App root to the feature; deleting `Item.swift`/`ContentView.swift`/the template `sharedModelContainer`.

During #4 the new `TaskEntity` container coexists with the untouched template `sharedModelContainer(Item)`; #5 removes the template.

## Architecture

Dependency direction (source deps point inward; Domain is independent):

```
Presentation (UI/ — Views, UDF ViewModels)  ─┐
                                              ├─→  Domain (Entities, Repository protocols, UseCases)
Data (SwiftData impl, in-memory impl)        ─┘
```

Layers are **folders, not SPM modules** (single app target), matching Ledger. Observation is the `@Observable` macro throughout; no Combine. Use cases are **stateless** (no internal `ObservableValue`) because the ViewModels manage `props` directly — this is the pairing the doc prescribes.

---

## Components

### Domain (`ToDo.UDF.MVVM/Domain/`)

**`Entities/TodoTask.swift`** — moved from `Models/`. Pure domain entity:
```swift
struct TodoTask: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var title: String
    var notes: String?
    var time: String          // "HH:mm"
    var priority: TaskPriority
    var isDone: Bool

    init(id: UUID = UUID(), title: String, notes: String? = nil,
         time: String, priority: TaskPriority, isDone: Bool = false)
}
extension TodoTask { static let sampleList: [TodoTask] }   // seed/preview fixture (same 6 items)
```

**`Entities/TaskPriority.swift`** — moved out of `TaskSummary.swift`; pure enum with a raw value for persistence mapping:
```swift
enum TaskPriority: String, CaseIterable, Sendable { case low, medium, high }
```
The presentation extension (`title`, `indicatorColor: Color`) moves to `UI/Shared/TaskPriority+UI.swift` so the domain enum never imports SwiftUI.

**`Repositories/TasksRepository.swift`** — protocol only (impl lives in Data):
```swift
protocol TasksRepository: Sendable {
    func fetchAll() async throws -> [TodoTask]      // sorted by time ascending ("HH:mm" lexicographic)
    func add(_ task: TodoTask) async throws
    func toggleDone(id: UUID) async throws
}
```

**`UseCases/TaskUseCases.swift`** — three protocols + `Default…` structs (Ledger style, `callAsFunction`):
```swift
protocol FetchTasksUseCase: Sendable { func callAsFunction() async throws -> [TodoTask] }
protocol AddTaskUseCase:   Sendable { func callAsFunction(_ task: TodoTask) async throws }
protocol ToggleTaskUseCase: Sendable { func callAsFunction(id: UUID) async throws }

struct DefaultFetchTasksUseCase: FetchTasksUseCase  { /* repository.fetchAll() */ }
struct DefaultAddTaskUseCase:    AddTaskUseCase     { /* guard non-empty title else throw; repository.add */ }
struct DefaultToggleTaskUseCase: ToggleTaskUseCase  { /* repository.toggleDone(id:) */ }

enum TaskValidationError: Error, Equatable { case emptyTitle }
```
`AddTaskUseCase` validates a non-empty (trimmed) title — domain-side guard mirroring Ledger's amount check.

### Data (`ToDo.UDF.MVVM/Data/`)

**`Models/TaskEntity.swift`** — replaces `Item.swift`:
```swift
import SwiftData
@Model final class TaskEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String?
    var time: String
    var priorityRaw: String
    var isDone: Bool
    init(id:title:notes:time:priorityRaw:isDone:)
}
extension TaskEntity {
    func toDomain() -> TodoTask
    static func make(from task: TodoTask) -> TaskEntity
}
```

**`Repositories/SwiftDataTasksRepository.swift`** — production impl:
```swift
@MainActor final class SwiftDataTasksRepository: TasksRepository {
    private let context: ModelContext
    init(context: ModelContext)
    func fetchAll() async throws -> [TodoTask]   // FetchDescriptor sorted by \.time
    func add(_ task: TodoTask) async throws       // insert make(from:) + context.save()
    func toggleDone(id: UUID) async throws         // #Predicate by id, flip isDone, save
}
```

**`Repositories/InMemoryTasksRepository.swift`** — fast impl for previews and unit/integration tests:
```swift
@MainActor final class InMemoryTasksRepository: TasksRepository {
    init(seed: [TodoTask] = TodoTask.sampleList)
    // holds [TodoTask]; same three methods over the array
}
```

**`Composition/DataAssembly.swift`** — container + seed + use-case bundle factory (the #4 minimal DI; #5 grows the real composition root):
```swift
@MainActor enum DataAssembly {
    static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer  // Schema([TaskEntity.self])
    static func seedIfNeeded(context: ModelContext)                                   // inserts TodoTask.sampleList if empty
    static func makeUseCases(repository: TasksRepository) -> TasksUseCases             // builds the 3 Default… use cases
    static func makeLiveUseCases() -> TasksUseCases                                    // persistent container + seed + SwiftData repo
}
```

### Presentation rewiring (`ToDo.UDF.MVVM/UI/`)

**Use-case bundle** `Domain/UseCases/TasksUseCases.swift` (DI struct, mirrors Ledger's `TransactionsUseCases`). It lives in **Domain** because it aggregates only domain use-case protocols — this lets `DataAssembly` build and return it without the Data layer depending on Presentation:
```swift
struct TasksUseCases {
    let fetchTasks: any FetchTasksUseCase
    let addTask:    any AddTaskUseCase
    let toggleTask: any ToggleTaskUseCase
}
```

**`UI/Shared/TaskTimeFormatter.swift`** (new) — shared `Date → "HH:mm"`; removes the duplicated formatter from `NewTaskView`; used by `NewTaskView` (display) and `NewTaskViewModel` (mapping):
```swift
enum TaskTimeFormatter { static func string(from date: Date) -> String }   // cached "HH:mm", en_US_POSIX
```

**`TaskListProps.swift`** — toggle moves to async; `.load` added:
```swift
struct Props: Equatable { var active: [TaskRow]; var completed: [TaskRow]; var progress: Double }
enum SyncEvent: Equatable { case addTapped }
enum AsyncEvent: Equatable { case load; case toggle(id: UUID, reduceMotion: Bool) }
```

**`TaskListViewModel.swift`** — use-case injected, fetch-driven:
```swift
init(fetchTasks: any FetchTasksUseCase, toggleTask: any ToggleTaskUseCase,
     onEffect: @escaping (CoordinatorEffect) -> Void = { _ in })
// props starts from makeProps(from: [])
// onEvent(.addTapped) -> onEffect(.createTaskRequested)
// onAsyncEvent(.load) -> reload(animated: false)
// onAsyncEvent(.toggle(id, reduceMotion)) -> try? await toggleTask(id:); reload(animated: !reduceMotion)
// private reload(animated:): tasks = (try? await fetchTasks()) ?? []; withAnimation(...) { props = makeProps(from: tasks) }
// makeProps(from:) unchanged (map -> TaskRow, split active/completed, progress)
```

**`TaskListView.swift`** — `.task { await viewModel.onAsync(.load) }`; row toggles dispatch via `Task { await viewModel.onAsync(.toggle(id:reduceMotion:)) }` (both active and completed rows). Preview builds the VM from an `InMemoryTasksRepository`-backed use case.

**`NewTaskProps.swift`** — save moves to async:
```swift
enum SyncEvent: Equatable { case titleChanged(String); case notesChanged(String); case whenChanged(TaskWhen)
                            case timeChanged(Date); case priorityChanged(TaskPriority)
                            case timePickerOpened; case timePickerClosed; case backTapped }
enum AsyncEvent: Equatable { case save }
// Props unchanged: title, notes, when, time, priority, isPickingTime, canSave
```

**`NewTaskViewModel.swift`** — use-case injected; builds the entity and persists:
```swift
init(addTask: any AddTaskUseCase, onEffect: @escaping (CoordinatorEffect) -> Void = { _ in })
// sync events unchanged except .saveTapped removed; .backTapped -> onEffect(.dismissForm)
// onAsyncEvent(.save):
//   guard props.canSave else { return }
//   let task = TodoTask(title: props.title,
//                       notes: props.notes.isEmpty ? nil : props.notes,
//                       time: TaskTimeFormatter.string(from: props.time),
//                       priority: props.priority)        // `when` intentionally not persisted
//   do { try await addTask(task); onEffect(.saveRequested) } catch { /* #4: log only; #5 may surface */ }
```
`canSave` stays as the UI guard; `AddTaskUseCase` is the domain guard. `NewTaskDraft` is **not** introduced — the VM (a presentation adapter) maps its own props to the entity; `Props`/`TaskRow` remain model-independent.

**`NewTaskView.swift`** — "Зберегти" dispatches `Task { await viewModel.onAsync(.save) }`; the private static `timeFormatter`/`timeString` are replaced by `TaskTimeFormatter.string(from:)`. Preview builds the VM from an `InMemoryTasksRepository`-backed `AddTaskUseCase`.

### DI / Coordinator / Factory (minimal for #4)

**`UIFactory.swift`** — built from the use-case bundle; list/new-task methods drop the `tasks:` parameter:
```swift
protocol UIFactory {
    func taskCreatedViewModel(task: TaskSummary, onEffect: @escaping (CoordinatorEffect) -> Void) -> TaskCreatedViewModel
    func taskListViewModel(onEffect: @escaping (CoordinatorEffect) -> Void) -> TaskListViewModel
    func newTaskViewModel(onEffect: @escaping (CoordinatorEffect) -> Void) -> NewTaskViewModel
}
final class DefaultUIFactory: UIFactory {
    init(useCases: TasksUseCases)
    // taskListViewModel -> TaskListViewModel(fetchTasks:, toggleTask:, onEffect:)
    // newTaskViewModel  -> NewTaskViewModel(addTask:, onEffect:)
    // taskCreatedViewModel -> unchanged
}
```

**`TaskFlowCoordinator.swift`** — unchanged `handle(_:)` (the four effect stubs stay until #5); construction updated:
```swift
init(factory: UIFactory)                                   // tests/previews inject (in-memory)
convenience init()                                         // production: DefaultUIFactory(useCases: DataAssembly.makeLiveUseCases())
```
`makeTaskListViewModel` loses its `tasks:` parameter. Nothing else in the coordinator changes in #4. The `convenience init()` keeps `TaskFlowView` (`@State coordinator = TaskFlowCoordinator()`) compiling unchanged. **Transitional seam:** this convenience makes the coordinator (Presentation) reference `DataAssembly` (Data) for construction — a deliberate #4 shortcut; #5's composition root builds the factory and injects it, removing the edge.

---

## Data flow

1. **Load:** `TaskListView.task` → `VM.onAsync(.load)` → `FetchTasksUseCase()` → `Repository.fetchAll()` → `[TodoTask]` → `VM` rebuilds `Props` → list renders.
2. **Toggle:** row tap → `Task { VM.onAsync(.toggle(id, reduceMotion)) }` → `ToggleTaskUseCase(id:)` → `Repository.toggleDone(id:)` + save → `VM` re-fetches → rebuilds `Props` (animated unless reduceMotion).
3. **Save:** "Зберегти" → `Task { VM.onAsync(.save) }` → `VM` builds `TodoTask` from props → `AddTaskUseCase(task)` (validates) → `Repository.add` + save → `onEffect(.saveRequested)`. Navigation/refresh on this effect is wired in **#5**.

## Error handling

- `AddTaskUseCase` throws `TaskValidationError.emptyTitle` on a blank title; `NewTaskViewModel` already guards `canSave`, and catches/logs the throw (no error Props in #4).
- `fetchAll`/`toggleDone` throws are absorbed with `try?` in the list VM (best-effort reload, matching Ledger). An empty fetch renders the existing `ContentUnavailableView`.
- No explicit `.loading` Props state in #4: before the first fetch, `Props` is empty (one frame of the existing empty state). Adding a `.loading` content state is a deliberate non-goal here.

## Testing strategy

New (Swift Testing, `@MainActor`):
- **`TaskUseCasesTests`** — Fetch returns repository contents; Add inserts; Add throws `.emptyTitle` on blank/whitespace title; Toggle flips. Backed by `InMemoryTasksRepository`.
- **`SwiftDataTasksRepositoryTests`** — in-memory `ModelContainer` (`DataAssembly.makeModelContainer(inMemory: true)`): add→fetchAll round-trips and maps correctly; toggleDone flips and persists; fetch ordering by time.
- **`TaskEntityMappingTests`** — `toDomain`/`make(from:)` round-trip, including `priorityRaw` ↔ `TaskPriority` and `notes == nil`.

Updated:
- **`TaskListViewModelTests`** — construct with `InMemoryTasksRepository`-backed use cases; `.load` populates active/completed/progress; `.toggle` moves a task between sections and recomputes progress.
- **`NewTaskViewModelTests`** — `.save` persists a `TodoTask` (title/notes(""→nil)/time "HH:mm"/priority) via the use case and emits `.saveRequested`; blank title → no persist; `when` is not persisted.
- **`UIFactoryTests`** — built from a `TasksUseCases` bundle; methods no longer take `tasks:`.
- **`TaskFlowCoordinatorTests`** — coordinator built with an in-memory factory; the four effect stubs unchanged.

## File changes

**Create:** `Domain/Entities/TaskPriority.swift`, `Domain/Repositories/TasksRepository.swift`, `Domain/UseCases/TaskUseCases.swift`, `Domain/UseCases/TasksUseCases.swift` (bundle), `Data/Models/TaskEntity.swift`, `Data/Repositories/SwiftDataTasksRepository.swift`, `Data/Repositories/InMemoryTasksRepository.swift`, `Data/Composition/DataAssembly.swift`, `UI/Shared/TaskTimeFormatter.swift`, `UI/Shared/TaskPriority+UI.swift`.

**Move:** `Models/TodoTask.swift` → `Domain/Entities/TodoTask.swift` (and extract `TaskPriority` out of `Models/TaskSummary.swift`).

**Modify:** `Models/TaskSummary.swift` (drop `TaskPriority`), `UI/TaskList/TaskListProps.swift`, `UI/TaskList/TaskListViewModel.swift`, `UI/TaskList/TaskListView.swift`, `UI/NewTask/NewTaskProps.swift`, `UI/NewTask/NewTaskViewModel.swift`, `UI/NewTask/NewTaskView.swift`, `UI/Flow/UIFactory.swift`, `UI/Flow/TaskFlowCoordinator.swift`.

**Delete:** none in #4 (`Item.swift`/`ContentView.swift` removed in #5).

## Deferred to #5

`TaskRoute` + `navigationDestination`; effect wiring (`createTaskRequested`→push form, `saveRequested`→push success + `listViewModel.onAsync(.reload)`, `dismissForm`→pop, `finishCreated`→popToRoot); success screen carrying the created `TaskSummary`; full coordinator lifecycle (`onComplete`/`start()`, `Feature` enum, `AppCoordinator`, composition root); App-root switch to the feature; deletion of `Item.swift`/`ContentView.swift`/template `sharedModelContainer`.
