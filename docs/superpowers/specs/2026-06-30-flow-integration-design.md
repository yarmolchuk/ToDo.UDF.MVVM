# Flow Integration (#5) — Design

**Status:** Approved design, ready for plan.
**Date:** 2026-06-30
**Context:** Final sub-project of the full-Clean pivot. #4 delivered the Domain + Data layers and rewired the ViewModels onto use cases. #5 assembles the running app the house way: the full coordinator lifecycle (Ledger's SwiftUI shape), stack navigation, effect wiring, and the App-root switch.
**References:** house doc `/Users/MAC/Downloads/MVVM+Coordinator+Clean_Architecture_overview.pdf`; concrete reference = Ledger (`/Users/MAC/Documents/Ledger`). Mirror Ledger's SwiftUI shapes (NOT the doc's UIKit AppDelegate example).

---

## Goal

Turn the three isolated screens into a working flow: **list (root) → push form → save → push success → back to list**, driven by a coordinator built through a composition root, with the App launching the feature instead of the SwiftData template.

## Scope

**In #5:** `TaskRoute` + `navigationDestination` (all-push); the Ledger-shaped coordinator lifecycle (`Coordinator { onComplete; start() }`, `TaskFlowFeature.Dependencies`, `@Observable` coordinator holding a retained root `listViewModel`, `handle` wiring the four effects); `CoordinatorEffect.saveRequested` gains a `TaskSummary` payload; `NewTaskViewModel.save` emits it; `AppComposition` composition root; `ToDo_UDF_MVVMApp` holds the `ModelContainer` and launches `TaskFlowView(useCases:)`; delete the `ContentView`/`Item` template; `DataAssembly` drops `makeLiveUseCases` and the custom store URL.

**Decisions locked earlier:** all-push (keep the success screen; not Ledger's add-sheet, because we have a success step Ledger's add lacks); NO `AppCoordinator` (Ledger's SwiftUI reality holds the coordinator in `@State`); coordinator-imperative list refresh after save.

**Out of scope:** none deferred — #5 completes the migration.

## Architecture

Ledger's pure-SwiftUI composition (verified against Ledger):
```
@main App (holds ModelContainer in @State, builds use cases once)
  └─ WindowGroup { TaskFlowView(useCases:) .modelContainer(...) }
        └─ @State coordinator: TaskFlowCoordinator   (built from Router + Dependencies.live + onComplete:{_in})
              ├─ router (NavigationStack path)
              ├─ lazy listViewModel  (retained root VM — coordinator pokes it to reload)
              └─ handle(effect) → router push/pop/popToRoot + listViewModel reload
```
`AppComposition` (composition root) builds `ModelContainer → SwiftDataTasksRepository → TasksUseCases`. The coordinator is held alive by the View's `@State`; no `AppCoordinator`.

---

## Components

### `UI/Flow/TaskRoute.swift` (create)
```swift
enum TaskRoute: Hashable {
    case newTask
    case created(TaskSummary)
}
```
`TaskSummary` becomes `Hashable` (its fields `String`/`String`/`TaskPriority` are all Hashable).

### `Models/TaskSummary.swift` (modify)
`struct TaskSummary: Hashable` (was `Equatable`; `Hashable` implies `Equatable`). Body unchanged.

### `Architecture/Coordinator.swift` (modify)
```swift
@MainActor
protocol Coordinator: AnyObject {
    var onComplete: (any Coordinator) -> Void { get }
    func start()
}

enum CoordinatorEffect: Equatable {
    case finishCreated
    case createTaskRequested
    case saveRequested(TaskSummary)
    case dismissForm
}
```
`handle(_:)` leaves the protocol (it becomes a concrete method on `TaskFlowCoordinator`, called via the VMs' `onEffect` closures). `saveRequested` carries the created `TaskSummary`. `Equatable` still synthesizes (`TaskSummary: Hashable: Equatable`).

### `UI/Flow/TaskFlowFeature.swift` (create)
```swift
@MainActor
enum TaskFlowFeature {
    struct Dependencies {
        let router: Router
        let factory: @MainActor (Dependencies) -> UIFactory

        static func live(router: Router, useCases: TasksUseCases) -> Self {
            Dependencies(router: router, factory: { _ in DefaultUIFactory(useCases: useCases) })
        }
    }
}
```
(No `Feature.coordinator()` factory — the FlowView builds the concrete coordinator directly, as Ledger's FlowView does; YAGNI.)

### `UI/Flow/TaskFlowCoordinator.swift` (rewrite to Ledger shape)
```swift
@MainActor
@Observable
final class TaskFlowCoordinator: Coordinator {
    let onComplete: (any Coordinator) -> Void

    @ObservationIgnored private let dependencies: TaskFlowFeature.Dependencies
    @ObservationIgnored private lazy var factory: UIFactory = dependencies.factory(dependencies)

    @ObservationIgnored lazy var listViewModel: AnyUdfViewModel<TaskListView.Props, TaskListView.SyncEvent, TaskListView.AsyncEvent> =
        factory.taskListViewModel(onEffect: { [weak self] in self?.handle($0) }).eraseToAnyViewModel()

    var router: Router { dependencies.router }

    init(dependencies: TaskFlowFeature.Dependencies, onComplete: @escaping (any Coordinator) -> Void) {
        self.dependencies = dependencies
        self.onComplete = onComplete
    }

    func start() {}

    func handle(_ effect: CoordinatorEffect) {
        switch effect {
        case .createTaskRequested:
            router.push(TaskRoute.newTask)
        case .saveRequested(let summary):
            Task { await listViewModel.onAsync(.load) }   // re-fetch so the list reflects the new task
            router.push(TaskRoute.created(summary))
        case .dismissForm:
            router.pop()
        case .finishCreated:
            router.popToRoot()
        }
    }

    func makeNewTaskViewModel() -> AnyUdfViewModel<NewTaskView.Props, NewTaskView.SyncEvent, NewTaskView.AsyncEvent> {
        factory.newTaskViewModel(onEffect: { [weak self] in self?.handle($0) }).eraseToAnyViewModel()
    }

    func makeTaskCreatedViewModel(task: TaskSummary) -> AnyUdfViewModel<TaskCreatedView.Props, TaskCreatedView.SyncEvent, TaskCreatedView.AsyncEvent> {
        factory.taskCreatedViewModel(task: task, onEffect: { [weak self] in self?.handle($0) }).eraseToAnyViewModel()
    }
}
```
The retained `listViewModel` replaces the old `makeTaskListViewModel()`; the old `init(factory:)`/`convenience init()` are gone. Reload reuses the existing `.load` async event (it re-fetches from the repository); a separate `.reload` event is not added. `.task` does not re-fire on pop-back (the root never disappears), so the explicit reload is required.

### `UI/Flow/TaskFlowView.swift` (rewrite)
```swift
struct TaskFlowView: View {
    @State private var coordinator: TaskFlowCoordinator

    init(useCases: TasksUseCases) {
        let router = Router()
        let dependencies = TaskFlowFeature.Dependencies.live(router: router, useCases: useCases)
        _coordinator = State(initialValue: TaskFlowCoordinator(dependencies: dependencies, onComplete: { _ in }))
    }

    var body: some View {
        @Bindable var router = coordinator.router
        NavigationStack(path: $router.path) {
            TaskListView(viewModel: coordinator.listViewModel)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: TaskRoute.self) { route in
                    destination(for: route)
                        .toolbar(.hidden, for: .navigationBar)
                }
        }
        .onAppear { coordinator.start() }
    }

    @ViewBuilder
    private func destination(for route: TaskRoute) -> some View {
        switch route {
        case .newTask:            NewTaskView(viewModel: coordinator.makeNewTaskViewModel())
        case .created(let s):     TaskCreatedView(viewModel: coordinator.makeTaskCreatedViewModel(task: s))
        }
    }
}

#Preview {
    TaskFlowView(useCases: DataAssembly.makeUseCases(repository: InMemoryTasksRepository()))
}
```
System nav bar hidden on root + destinations (all three screens carry their own chrome).

### `Composition/AppComposition.swift` (create)
```swift
import Foundation
import SwiftData

@MainActor
enum AppComposition {
    static func bootstrap() -> ModelContainer {
        do {
            let container = try DataAssembly.makeModelContainer()
            DataAssembly.seedIfNeeded(context: container.mainContext)
            return container
        } catch {
            fatalError("Не вдалося ініціалізувати сховище задач: \(error)")
        }
    }

    static func tasksUseCases(container: ModelContainer) -> TasksUseCases {
        DataAssembly.makeUseCases(repository: SwiftDataTasksRepository(container: container))
    }
}
```

### `ToDo_UDF_MVVMApp.swift` (rewrite)
```swift
import SwiftUI
import SwiftData

@main
struct ToDo_UDF_MVVMApp: App {
    @State private var modelContainer: ModelContainer
    private let tasksUseCases: TasksUseCases

    init() {
        let container = AppComposition.bootstrap()
        _modelContainer = State(initialValue: container)
        tasksUseCases = AppComposition.tasksUseCases(container: container)
    }

    var body: some Scene {
        WindowGroup {
            TaskFlowView(useCases: tasksUseCases)
                .modelContainer(modelContainer)
        }
    }
}
```

### `Data/Composition/DataAssembly.swift` (modify)
- Remove `makeLiveUseCases()` (no longer used).
- `makeModelContainer` drops the custom `Tasks.store` URL and the `#4` comment — the default store, now that `Item` is gone:
```swift
static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
    let schema = Schema([TaskEntity.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
    return try ModelContainer(for: schema, configurations: [configuration])
}
```
`seedIfNeeded`/`makeUseCases` unchanged.

### `UI/NewTask/NewTaskViewModel.swift` (modify `.save`)
After persisting, build and emit the summary:
```swift
do {
    try await addTask(task)
    let summary = TaskSummary(title: task.title, time: task.time, priority: task.priority)
    onEffect(.saveRequested(summary))
} catch {
    // existing OSLog line
}
```

### Delete
`ToDo.UDF.MVVM/ContentView.swift`, `ToDo.UDF.MVVM/Item.swift` (synchronized group → no `project.pbxproj` edits).

---

## Data flow

1. **Create:** FAB → `TaskListViewModel` `.addTapped` → `onEffect(.createTaskRequested)` → coordinator `router.push(.newTask)` → `NewTaskView` pushed.
2. **Save:** form "Зберегти" → `NewTaskViewModel.save` builds `TodoTask` → `addTask` (persists) → builds `TaskSummary` → `onEffect(.saveRequested(summary))` → coordinator: `Task { await listViewModel.onAsync(.load) }` (re-fetch) + `router.push(.created(summary))` → success pushed (on top of the form).
3. **Finish:** success "До списку" → `onEffect(.finishCreated)` → `router.popToRoot()` → back to the list, which now shows the new task (reload completed).
4. **Back from form:** form NavBar back → `onEffect(.dismissForm)` → `router.pop()` → list.

## Error handling

- Save errors are logged in `NewTaskViewModel` (from #4); `canSave` guards the empty-title path; `AddTaskUseCase` re-validates.
- `AppComposition.bootstrap` `fatalError`s if the store cannot be created (Ledger pattern — unrecoverable at launch).
- The post-save reload is best-effort (`try?` inside the list VM's `reload`).

## Testing strategy

- **`TaskFlowCoordinatorTests`** (rewrite): build via `TaskFlowFeature.Dependencies.live(router:, useCases: DataAssembly.makeUseCases(repository: InMemoryTasksRepository()))` + `onComplete: { _ in }`. Assert each effect's navigation: `createTaskRequested` → path contains `.newTask`; `saveRequested(summary)` → path contains `.created(summary)`; `dismissForm` → pops; `finishCreated` → empties; `listViewModel` is the same retained instance across accesses.
- **`NewTaskViewModelTests`** (update): `.save` now emits `.saveRequested(TaskSummary(title:, time: "09:30"/mapped, priority:))` — assert the exact summary; persistence assertions unchanged.
- **`TaskFlowIntegrationTests`** (create): with one shared `InMemoryTasksRepository`, drive the real flow — `handle(.createTaskRequested)`, then the form VM's `.save` (sets title, `onAsync(.save)`), then assert `listViewModel` reload reflects the added task (`props.active` count grows) AND path ends on `.created`. This is the #5 payoff (end-to-end).
- **`AppCompositionTests`** (create, light): `tasksUseCases(container: DataAssembly.makeModelContainer(inMemory: true))` builds use cases that add+fetch. (`bootstrap()` itself is a thin disk-backed wrapper — not unit-tested.)
- Unchanged: `UIFactoryTests`, `TaskListViewModelTests`, `TaskUseCasesTests`, repository/mapping/DataAssembly suites.

## File changes

**Create:** `UI/Flow/TaskRoute.swift`, `UI/Flow/TaskFlowFeature.swift`, `Composition/AppComposition.swift`, plus tests `TaskFlowIntegrationTests.swift`, `AppCompositionTests.swift`.
**Modify:** `Models/TaskSummary.swift`, `Architecture/Coordinator.swift`, `UI/Flow/TaskFlowCoordinator.swift`, `UI/Flow/TaskFlowView.swift`, `UI/NewTask/NewTaskViewModel.swift`, `Data/Composition/DataAssembly.swift`, `ToDo_UDF_MVVMApp.swift`, and tests `TaskFlowCoordinatorTests.swift`, `NewTaskViewModelTests.swift`.
**Delete:** `ContentView.swift`, `Item.swift`.

## Decomposition (for the plan)

Roughly: (A) `TaskSummary: Hashable` + `TaskRoute` (additive); (B) the coupled flow cluster — `Coordinator` protocol + `CoordinatorEffect.saveRequested(TaskSummary)` + `TaskFlowFeature` + `TaskFlowCoordinator` rewrite + `TaskFlowView` rewrite + `NewTaskViewModel.save` + `DataAssembly` cleanup + their tests (one commit, like #4's list-rewire — the protocol/effect change ripples through all of them); (C) `AppComposition` + App-root switch + delete `ContentView`/`Item` + integration/composition tests. ~3–4 tasks.

## Notes / micro-decisions

- **Success transition:** pushed on top of the form (`[list, newTask, created]`); `finishCreated`→`popToRoot` clears both. Swipe-back from success reveals the form — accepted; pop+push for a clean `[list, created]` is the alternative if it feels wrong.
- **Reload event:** reuse `.load` (re-fetches); no new `.reload` event.
- **`.modelContainer(modelContainer)`** kept on the WindowGroup (no `@Query` consumers, but mirrors Ledger and retains the container).
- Test sim: iPhone 16e / iOS 26.3.1; run SERIAL (`-parallel-testing-enabled NO`).
