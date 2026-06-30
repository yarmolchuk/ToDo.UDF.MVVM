# Flow Integration (#5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Assemble the running app the house way — list (root) → push form → save → push success → back to list — via a Ledger-shaped coordinator built through a composition root, with the App launching the feature instead of the SwiftData template.

**Architecture:** Pure-SwiftUI MVVM+Coordinator+Clean (mirrors Ledger). The App holds the `ModelContainer` in `@State` and builds use cases once via `AppComposition`; `TaskFlowView` owns a `@State` coordinator built from `Router` + `TaskFlowFeature.Dependencies`; navigation is `NavigationStack(path:)` + `.navigationDestination(for: TaskRoute.self)` (all-push); the coordinator's `handle(effect)` does push/pop/popToRoot and pokes a retained root `listViewModel` to reload after save.

**Tech Stack:** SwiftUI, Observation (`@Observable`/`@State`/`@Bindable`), SwiftData, Swift Testing, Swift concurrency.

## Global Constraints

- Platform iOS 26.2; module `ToDo_UDF_MVVM`; scheme `ToDo.UDF.MVVM`.
- Test command: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.3.1' -parallel-testing-enabled NO`; single suite: append `-only-testing:ToDo.UDF.MVVMTests/<SuiteType>`. Green = `** TEST SUCCEEDED **`; build-error red = `** TEST BUILD FAILED **`.
- **Run SERIAL** (`-parallel-testing-enabled NO`). If a run hangs or shows `ipc/mig server died` or `Application failed preflight checks` / `Busy`, it is a simulator flake — run `xcrun simctl shutdown all; killall Simulator`, wait ~5s, retry.
- Swift Testing only (`@Test`, `#expect`, `@MainActor struct`).
- `@Observable`/`@MainActor`; NO Combine. Coordinator dependencies/internal state `@ObservationIgnored`.
- Ledger-faithful shapes: `Coordinator { var onComplete: (any Coordinator) -> Void { get }; func start() }` (`handle` is concrete, NOT in the protocol); `TaskFlowFeature.Dependencies` (router + factory closure); `@Observable` coordinator with a retained `lazy var listViewModel`; coordinator held by `@State` in `TaskFlowView`; **NO `AppCoordinator`**.
- All-push navigation (no `.sheet`); success pushed on top of the form; `finishCreated`→`popToRoot`.
- `CoordinatorEffect.saveRequested` carries a `TaskSummary`; the list refreshes by re-firing the existing `.load` async event (no new `.reload` event).
- Layers are folders; new files under `ToDo.UDF.MVVM/` and `ToDo.UDF.MVVMTests/` are auto-included (both `PBXFileSystemSynchronizedRootGroup`) — NO `project.pbxproj` edits.
- Comments in Ukrainian.
- Ordering keeps every commit compiling: Task 2 rewrites the whole coupled flow cluster together (protocol + effect + Feature + coordinator + view + `NewTaskViewModel.save` + `DataAssembly` cleanup); the App still launches the untouched `ContentView` until Task 3.

## File Structure

| Path | Responsibility |
|------|----------------|
| `Models/TaskSummary.swift` | (modify) `TaskSummary` becomes `Hashable` |
| `UI/Flow/TaskRoute.swift` | (create) stack routes |
| `Architecture/Coordinator.swift` | (modify) protocol → `{onComplete; start()}`; effect gains payload |
| `UI/Flow/TaskFlowFeature.swift` | (create) feature DI container |
| `UI/Flow/TaskFlowCoordinator.swift` | (rewrite) Ledger-shaped coordinator |
| `UI/Flow/TaskFlowView.swift` | (rewrite) NavigationStack host, list root + destinations |
| `UI/NewTask/NewTaskViewModel.swift` | (modify) `.save` emits `.saveRequested(summary)` |
| `Data/Composition/DataAssembly.swift` | (modify) drop `makeLiveUseCases`, default store URL |
| `Composition/AppComposition.swift` | (create) composition root |
| `ToDo_UDF_MVVMApp.swift` | (rewrite) hold container, launch feature |
| `ContentView.swift`, `Item.swift` | (delete) template |

---

## Task 1: `TaskSummary: Hashable` + `TaskRoute`

**Files:**
- Modify: `ToDo.UDF.MVVM/Models/TaskSummary.swift`
- Create: `ToDo.UDF.MVVM/UI/Flow/TaskRoute.swift`
- Test: `ToDo.UDF.MVVMTests/TaskRouteTests.swift`

**Interfaces:**
- Produces: `struct TaskSummary: Hashable` (fields unchanged); `enum TaskRoute: Hashable { case newTask; case created(TaskSummary) }`.

- [ ] **Step 1: Write the failing test**

Create `ToDo.UDF.MVVMTests/TaskRouteTests.swift`:
```swift
import Testing
@testable import ToDo_UDF_MVVM

@MainActor
struct TaskRouteTests {
    @Test func routesAreHashableAndDistinct() {
        let set: Set<TaskRoute> = [.newTask, .created(.sample)]
        #expect(set.contains(.newTask))
        #expect(set.contains(.created(.sample)))
        #expect(set.count == 2)
    }

    @Test func createdRouteEqualsBySummary() {
        #expect(TaskRoute.created(.sample) == TaskRoute.created(.sample))
        #expect(TaskRoute.created(.sample) != TaskRoute.newTask)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.3.1' -parallel-testing-enabled NO -only-testing:ToDo.UDF.MVVMTests/TaskRouteTests`
Expected: `** TEST BUILD FAILED **` — `cannot find type 'TaskRoute'`; and `Set<TaskRoute>` would require `TaskSummary: Hashable`.

- [ ] **Step 3: Make `TaskSummary` Hashable**

Replace the `struct TaskSummary` declaration line in `ToDo.UDF.MVVM/Models/TaskSummary.swift`:
```swift
struct TaskSummary: Equatable {
```
with:
```swift
struct TaskSummary: Hashable {
```
(The `extension TaskSummary { static let sample … }` and the fields stay as they are. `TaskPriority` is a `String`-raw enum, so it is already `Hashable`, and synthesis succeeds.)

- [ ] **Step 4: Create `TaskRoute`**

Create `ToDo.UDF.MVVM/UI/Flow/TaskRoute.swift`:
```swift
//
//  TaskRoute.swift
//  ToDo.UDF.MVVM
//
//  Маршрути навігаційного стека todo-флоу.
//

enum TaskRoute: Hashable {
    case newTask
    case created(TaskSummary)
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.3.1' -parallel-testing-enabled NO -only-testing:ToDo.UDF.MVVMTests/TaskRouteTests`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add ToDo.UDF.MVVM/Models/TaskSummary.swift ToDo.UDF.MVVM/UI/Flow/TaskRoute.swift ToDo.UDF.MVVMTests/TaskRouteTests.swift
git commit -m "$(cat <<'EOF'
feat: add TaskRoute and make TaskSummary Hashable

Stack routes for the flow (.newTask, .created(TaskSummary)); TaskSummary
becomes Hashable so it can ride in a Hashable route.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: The coupled flow rewrite

Rewriting the `Coordinator` protocol and `CoordinatorEffect.saveRequested` ripples through the coordinator, the flow view, and `NewTaskViewModel` — so they all change in one commit. At the end the flow works end-to-end (verified by an integration test), but the App still launches the untouched `ContentView` (Task 3 switches it).

**Files:**
- Modify: `ToDo.UDF.MVVM/Architecture/Coordinator.swift`
- Create: `ToDo.UDF.MVVM/UI/Flow/TaskFlowFeature.swift`
- Rewrite: `ToDo.UDF.MVVM/UI/Flow/TaskFlowCoordinator.swift`
- Rewrite: `ToDo.UDF.MVVM/UI/Flow/TaskFlowView.swift`
- Modify: `ToDo.UDF.MVVM/UI/NewTask/NewTaskViewModel.swift`
- Modify: `ToDo.UDF.MVVM/Data/Composition/DataAssembly.swift`
- Rewrite: `ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift`
- Modify: `ToDo.UDF.MVVMTests/NewTaskViewModelTests.swift`
- Create: `ToDo.UDF.MVVMTests/TaskFlowIntegrationTests.swift`

**Interfaces:**
- Consumes: `TaskRoute`, `TaskSummary` (Task 1); `TasksUseCases`, `DataAssembly.makeUseCases`, `InMemoryTasksRepository`, `DefaultUIFactory`, `Router`, `AnyUdfViewModel`, the `TaskList`/`NewTask`/`TaskCreated` view types.
- Produces: `protocol Coordinator { var onComplete: (any Coordinator) -> Void { get }; func start() }`; `CoordinatorEffect.saveRequested(TaskSummary)`; `TaskFlowFeature.Dependencies { router; factory }` + `static func live(router:useCases:)`; `TaskFlowCoordinator(dependencies: TaskFlowFeature.Dependencies, onComplete:)` with `lazy var listViewModel`, `var router`, `handle(_:)`, `makeNewTaskViewModel()`, `makeTaskCreatedViewModel(task:)`; `TaskFlowView(useCases: TasksUseCases)`.

- [ ] **Step 1: Rewrite the test files (the failing spec)**

Replace `ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift` with:
```swift
import Testing
import SwiftUI
@testable import ToDo_UDF_MVVM

@MainActor
struct TaskFlowCoordinatorTests {
    private func makeCoordinator(seed: [TodoTask] = TodoTask.sampleList) -> TaskFlowCoordinator {
        let router = Router()
        let useCases = DataAssembly.makeUseCases(repository: InMemoryTasksRepository(seed: seed))
        let dependencies = TaskFlowFeature.Dependencies.live(router: router, useCases: useCases)
        return TaskFlowCoordinator(dependencies: dependencies, onComplete: { _ in })
    }

    @Test func createTaskRequestedPushesNewTask() {
        let c = makeCoordinator()
        c.handle(.createTaskRequested)
        #expect(c.router.path.count == 1)
    }

    @Test func saveRequestedPushesCreated() {
        let c = makeCoordinator()
        c.handle(.saveRequested(.sample))
        #expect(c.router.path.count == 1)
    }

    @Test func dismissFormPops() {
        let c = makeCoordinator()
        c.handle(.createTaskRequested)
        #expect(c.router.path.count == 1)
        c.handle(.dismissForm)
        #expect(c.router.path.isEmpty)
    }

    @Test func finishCreatedPopsToRoot() {
        let c = makeCoordinator()
        c.handle(.createTaskRequested)
        c.handle(.saveRequested(.sample))
        #expect(c.router.path.count == 2)
        c.handle(.finishCreated)
        #expect(c.router.path.isEmpty)
    }

    @Test func listViewModelIsRetainedStableInstance() {
        let c = makeCoordinator()
        #expect(c.listViewModel === c.listViewModel)
    }

    @Test func makesNewTaskViewModel() {
        let c = makeCoordinator()
        #expect(c.makeNewTaskViewModel().props.canSave)
    }

    @Test func makesTaskCreatedViewModelCarryingTask() {
        let c = makeCoordinator()
        #expect(c.makeTaskCreatedViewModel(task: .sample).props.task == .sample)
    }
}
```

In `ToDo.UDF.MVVMTests/NewTaskViewModelTests.swift`, replace the `savePersistsTaskAndEmitsEffect` test body's effect assertion. Replace this test:
```swift
    @Test func savePersistsTaskAndEmitsEffect() async throws {
        let repository = InMemoryTasksRepository(seed: [])
        var received: CoordinatorEffect?
        let vm = makeViewModel(repository: repository, onEffect: { received = $0 })
        vm.onEvent(.titleChanged("Купити каву"))
        vm.onEvent(.notesChanged(""))
        await vm.onAsyncEvent(.save)
        let stored = try await repository.fetchAll()
        #expect(stored.count == 1)
        #expect(stored[0].title == "Купити каву")
        #expect(stored[0].notes == nil)             // порожні notes → nil
        #expect(received == .saveRequested)
    }
```
with:
```swift
    @Test func savePersistsTaskAndEmitsEffect() async throws {
        let repository = InMemoryTasksRepository(seed: [])
        var received: CoordinatorEffect?
        let vm = makeViewModel(repository: repository, onEffect: { received = $0 })
        vm.onEvent(.titleChanged("Купити каву"))
        vm.onEvent(.notesChanged(""))
        await vm.onAsyncEvent(.save)
        let stored = try await repository.fetchAll()
        #expect(stored.count == 1)
        #expect(stored[0].title == "Купити каву")
        #expect(stored[0].notes == nil)             // порожні notes → nil
        #expect(received == .saveRequested(TaskSummary(title: "Купити каву", time: "09:30", priority: .medium)))
    }
```

Create `ToDo.UDF.MVVMTests/TaskFlowIntegrationTests.swift`:
```swift
import Testing
@testable import ToDo_UDF_MVVM

@MainActor
struct TaskFlowIntegrationTests {
    private func makeCoordinator(seed: [TodoTask]) -> TaskFlowCoordinator {
        let router = Router()
        let useCases = DataAssembly.makeUseCases(repository: InMemoryTasksRepository(seed: seed))
        let dependencies = TaskFlowFeature.Dependencies.live(router: router, useCases: useCases)
        return TaskFlowCoordinator(dependencies: dependencies, onComplete: { _ in })
    }

    @Test func createSaveFinishFlow() async {
        let c = makeCoordinator(seed: [])
        await c.listViewModel.onAsync(.load)
        #expect(c.listViewModel.props.active.isEmpty)

        // FAB → form
        c.handle(.createTaskRequested)
        #expect(c.router.path.count == 1)

        // fill + save through the form VM (its onEffect routes into the coordinator)
        let form = c.makeNewTaskViewModel()
        form.onEvent(.titleChanged("Купити молоко"))
        await form.onAsync(.save)
        #expect(c.router.path.count == 2)   // pushed success

        // list reflects the new task (await the reload deterministically)
        await c.listViewModel.onAsync(.load)
        #expect(c.listViewModel.props.active.contains { $0.title == "Купити молоко" })

        // finish → back to the list
        c.handle(.finishCreated)
        #expect(c.router.path.isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.3.1' -parallel-testing-enabled NO`
Expected: `** TEST BUILD FAILED **` — `TaskFlowCoordinator(dependencies:onComplete:)`, `c.listViewModel`, `TaskFlowFeature`, and `.saveRequested(TaskSummary)` do not exist yet.

- [ ] **Step 3: Update `Coordinator.swift`**

Replace the full contents of `ToDo.UDF.MVVM/Architecture/Coordinator.swift` with:
```swift
//
//  Coordinator.swift
//  ToDo.UDF.MVVM
//

import Foundation

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

- [ ] **Step 4: Create `TaskFlowFeature.swift`**

Create `ToDo.UDF.MVVM/UI/Flow/TaskFlowFeature.swift`:
```swift
//
//  TaskFlowFeature.swift
//  ToDo.UDF.MVVM
//
//  DI-контейнер фічі: залежності координатора (router + фабрика UI).
//

import Foundation

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

- [ ] **Step 5: Rewrite `TaskFlowCoordinator.swift`**

Replace the full contents of `ToDo.UDF.MVVM/UI/Flow/TaskFlowCoordinator.swift` with:
```swift
//
//  TaskFlowCoordinator.swift
//  ToDo.UDF.MVVM
//
//  Координатор todo-флоу: тримає root-список, керує стеком, оживляє ефекти.
//

import SwiftUI

@MainActor
@Observable
final class TaskFlowCoordinator: Coordinator {
    let onComplete: (any Coordinator) -> Void

    @ObservationIgnored private let dependencies: TaskFlowFeature.Dependencies
    @ObservationIgnored private lazy var factory: UIFactory = dependencies.factory(dependencies)

    @ObservationIgnored lazy var listViewModel: AnyUdfViewModel<TaskListView.Props, TaskListView.SyncEvent, TaskListView.AsyncEvent> =
        factory.taskListViewModel(onEffect: { [weak self] effect in self?.handle(effect) }).eraseToAnyViewModel()

    var router: Router { dependencies.router }

    init(
        dependencies: TaskFlowFeature.Dependencies,
        onComplete: @escaping (any Coordinator) -> Void
    ) {
        self.dependencies = dependencies
        self.onComplete = onComplete
    }

    func start() {}

    func handle(_ effect: CoordinatorEffect) {
        switch effect {
        case .createTaskRequested:
            router.push(TaskRoute.newTask)
        case .saveRequested(let summary):
            Task { await listViewModel.onAsync(.load) }   // re-fetch так, щоб список показав нову задачу
            router.push(TaskRoute.created(summary))
        case .dismissForm:
            router.pop()
        case .finishCreated:
            router.popToRoot()
        }
    }

    func makeNewTaskViewModel() -> AnyUdfViewModel<NewTaskView.Props, NewTaskView.SyncEvent, NewTaskView.AsyncEvent> {
        factory
            .newTaskViewModel(onEffect: { [weak self] effect in self?.handle(effect) })
            .eraseToAnyViewModel()
    }

    func makeTaskCreatedViewModel(
        task: TaskSummary
    ) -> AnyUdfViewModel<TaskCreatedView.Props, TaskCreatedView.SyncEvent, TaskCreatedView.AsyncEvent> {
        factory
            .taskCreatedViewModel(task: task, onEffect: { [weak self] effect in self?.handle(effect) })
            .eraseToAnyViewModel()
    }
}
```

- [ ] **Step 6: Rewrite `TaskFlowView.swift`**

Replace the full contents of `ToDo.UDF.MVVM/UI/Flow/TaskFlowView.swift` with:
```swift
//
//  TaskFlowView.swift
//  ToDo.UDF.MVVM
//
//  Хост навігації todo-флоу: NavigationStack зі списком як коренем,
//  форма й success — push через TaskRoute.
//

import SwiftUI

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
        case .newTask:
            NewTaskView(viewModel: coordinator.makeNewTaskViewModel())
        case .created(let summary):
            TaskCreatedView(viewModel: coordinator.makeTaskCreatedViewModel(task: summary))
        }
    }
}

#Preview {
    TaskFlowView(useCases: DataAssembly.makeUseCases(repository: InMemoryTasksRepository()))
}
```

- [ ] **Step 7: Update `NewTaskViewModel.save` to emit the summary**

In `ToDo.UDF.MVVM/UI/NewTask/NewTaskViewModel.swift`, replace the `do { … } catch { … }` block inside the `.save` case:
```swift
            do {
                try await addTask(task)
                onEffect(.saveRequested)
            } catch {
                // #4: лише лог; показ помилки/навігація — у #5.
                Logger(subsystem: "ToDo.UDF.MVVM", category: "NewTask")
                    .error("Не вдалося зберегти задачу: \(error.localizedDescription, privacy: .public)")
            }
```
with:
```swift
            do {
                try await addTask(task)
                let summary = TaskSummary(title: task.title, time: task.time, priority: task.priority)
                onEffect(.saveRequested(summary))
            } catch {
                // #5: лог; показ помилки користувачу — поза обсягом.
                Logger(subsystem: "ToDo.UDF.MVVM", category: "NewTask")
                    .error("Не вдалося зберегти задачу: \(error.localizedDescription, privacy: .public)")
            }
```

- [ ] **Step 8: Clean up `DataAssembly.swift`**

In `ToDo.UDF.MVVM/Data/Composition/DataAssembly.swift`, replace `makeModelContainer` (drop the custom URL — `Item` is being removed, so no collision):
```swift
    static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([TaskEntity.self])
        // Окреме сховище "Tasks.store", щоб не конфліктувати зі стандартним
        // сховищем шаблонного Item, поки воно співіснує (#4). #5 спростить.
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema, url: URL.documentsDirectory.appending(path: "Tasks.store"))
        return try ModelContainer(for: schema, configurations: [configuration])
    }
```
with:
```swift
    static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([TaskEntity.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
```
Then DELETE the entire `makeLiveUseCases()` function (it is no longer referenced):
```swift
    static func makeLiveUseCases() -> TasksUseCases {
        do {
            let container = try makeModelContainer()
            seedIfNeeded(context: container.mainContext)
            return makeUseCases(repository: SwiftDataTasksRepository(container: container))
        } catch {
            fatalError("Не вдалося ініціалізувати сховище задач: \(error)")
        }
    }
```
(`seedIfNeeded` and `makeUseCases` stay.)

- [ ] **Step 9: Run the full suite to verify green**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.3.1' -parallel-testing-enabled NO`
Expected: `** TEST SUCCEEDED **` — all suites pass, including `TaskFlowCoordinatorTests`, `NewTaskViewModelTests`, `TaskFlowIntegrationTests`. (The App still launches `ContentView`; `TaskFlowView` is exercised via its preview and tests.)

- [ ] **Step 10: Commit**

```bash
git add ToDo.UDF.MVVM/Architecture/Coordinator.swift ToDo.UDF.MVVM/UI/Flow ToDo.UDF.MVVM/UI/NewTask/NewTaskViewModel.swift ToDo.UDF.MVVM/Data/Composition/DataAssembly.swift ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift ToDo.UDF.MVVMTests/NewTaskViewModelTests.swift ToDo.UDF.MVVMTests/TaskFlowIntegrationTests.swift
git commit -m "$(cat <<'EOF'
feat: wire the task flow (routes, effects, Ledger-shaped coordinator)

Coordinator protocol -> {onComplete; start()} (handle is concrete);
saveRequested carries TaskSummary; TaskFlowFeature.Dependencies + a
@State-held coordinator retaining the root listViewModel; TaskFlowView
roots at the list with TaskRoute navigationDestination (all-push);
effects do push/pop/popToRoot + reload-on-save. DataAssembly drops the
unused makeLiveUseCases and the custom store URL.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Composition root + App root + delete template

**Files:**
- Create: `ToDo.UDF.MVVM/Composition/AppComposition.swift`
- Rewrite: `ToDo.UDF.MVVM/ToDo_UDF_MVVMApp.swift`
- Delete: `ToDo.UDF.MVVM/ContentView.swift`, `ToDo.UDF.MVVM/Item.swift`
- Test: `ToDo.UDF.MVVMTests/AppCompositionTests.swift`

**Interfaces:**
- Consumes: `DataAssembly.makeModelContainer`/`seedIfNeeded`/`makeUseCases`, `SwiftDataTasksRepository`, `TasksUseCases`, `TaskFlowView(useCases:)` (Task 2).
- Produces: `enum AppComposition { static func bootstrap() -> ModelContainer; static func tasksUseCases(container: ModelContainer) -> TasksUseCases }`.

- [ ] **Step 1: Write the failing test**

Create `ToDo.UDF.MVVMTests/AppCompositionTests.swift`:
```swift
import Testing
import SwiftData
@testable import ToDo_UDF_MVVM

@MainActor
struct AppCompositionTests {
    @Test func tasksUseCasesBuildsWorkingBundle() async throws {
        let container = try DataAssembly.makeModelContainer(inMemory: true)
        let useCases = AppComposition.tasksUseCases(container: container)
        try await useCases.addTask(TodoTask(title: "X", time: "10:00", priority: .low))
        #expect(try await useCases.fetchTasks().count == 1)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.3.1' -parallel-testing-enabled NO -only-testing:ToDo.UDF.MVVMTests/AppCompositionTests`
Expected: `** TEST BUILD FAILED **` — `cannot find 'AppComposition' in scope`.

- [ ] **Step 3: Create `AppComposition.swift`**

Create `ToDo.UDF.MVVM/Composition/AppComposition.swift`:
```swift
//
//  AppComposition.swift
//  ToDo.UDF.MVVM
//
//  Корінь композиції: контейнер SwiftData → репозиторій → use cases.
//

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

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.3.1' -parallel-testing-enabled NO -only-testing:ToDo.UDF.MVVMTests/AppCompositionTests`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Switch the App root to the feature**

Replace the full contents of `ToDo.UDF.MVVM/ToDo_UDF_MVVMApp.swift` with:
```swift
//
//  ToDo_UDF_MVVMApp.swift
//  ToDo.UDF.MVVM
//

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

- [ ] **Step 6: Delete the SwiftData template**

```bash
rm ToDo.UDF.MVVM/ContentView.swift ToDo.UDF.MVVM/Item.swift
```
(Both were only referenced by the old App body, which no longer exists. The synchronized file group drops them automatically — no `project.pbxproj` edit.)

- [ ] **Step 7: Run the full suite to verify green + the App compiles**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.3.1' -parallel-testing-enabled NO`
Expected: `** TEST SUCCEEDED **` — every suite passes and the app target builds with `TaskFlowView` as the root and no `Item`/`ContentView`.

- [ ] **Step 8: Commit**

```bash
git add ToDo.UDF.MVVM/Composition/AppComposition.swift ToDo.UDF.MVVM/ToDo_UDF_MVVMApp.swift ToDo.UDF.MVVMTests/AppCompositionTests.swift
git add -A ToDo.UDF.MVVM/ContentView.swift ToDo.UDF.MVVM/Item.swift
git commit -m "$(cat <<'EOF'
feat: launch the task feature as the App root

AppComposition builds the ModelContainer + use cases once; the App holds
the container in @State and shows TaskFlowView(useCases:). Deletes the
SwiftData ContentView/Item template.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Done

The migration is complete: the App launches the list, the FAB pushes the form, saving persists via the use case and shows the success screen, and "До списку" returns to the list with the new task. Navigation, the composition root, and the full Ledger-shaped coordinator lifecycle are in place; the SwiftData template is gone.

**Final whole-branch review focus:** the coordinator's retained `listViewModel` reloads correctly after save (the `Task { … .load }` fire-and-forget plus the deterministic await in the integration test); `@State`-held coordinator with no `AppCoordinator`; the App holds the `ModelContainer` alive; `ContentView`/`Item` fully removed with no dangling references; all suites green (serial).
