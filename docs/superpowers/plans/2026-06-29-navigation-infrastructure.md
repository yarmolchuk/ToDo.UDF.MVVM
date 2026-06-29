# Navigation Infrastructure + Success Pilot Implementation Plan (Sub-project 1/4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lay the navigation layer (Router + Coordinator + UIFactory + FlowView, Ledger-style) and prove it end-to-end on the already-UDF TaskCreatedView.

**Architecture:** A `@Observable` `Router` wraps `NavigationPath`. A `Coordinator` receives `CoordinatorEffect`s emitted by ViewModels and drives the Router. A `UIFactory` builds ViewModels wired with an `onEffect` closure. `TaskFlowView` hosts the `NavigationStack` and renders screens via the coordinator. The pilot consumer is `TaskCreatedView`, whose VM migrates from a bare `onContinue` callback to `onEffect(CoordinatorEffect)`.

**Tech Stack:** SwiftUI, Observation (`@Observable`), Swift Testing.

## Global Constraints

- iOS deployment target **26.2**; module **`ToDo_UDF_MVVM`**.
- Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`) with `@testable import ToDo_UDF_MVVM`. Suites touching `@MainActor` types are annotated `@MainActor`.
- Navigation types (`Router`, `Coordinator`, `TaskFlowCoordinator`, `UIFactory`) are `@MainActor`; `Router`/`TaskFlowCoordinator` are `@Observable`; injected deps are `@ObservationIgnored private let`.
- **Minimal inline comments** — only file headers / non-obvious-why.
- **App root (`App`/`ContentView`) is NOT touched.** Infrastructure is verified via `#Preview` and a temporary `ContentView` swap that is reverted. `project.pbxproj` is NOT edited (file-system-synchronized groups, objectVersion 77).
- `CoordinatorEffect` carries only `.finishCreated` in this sub-project; it grows in sub-projects 2–4.
- Build/test simulator: **iPhone 17**, id `93EC3745-46A5-4F90-A4CE-6411DB70C816`.

---

### Task 1: Router

**Files:**
- Create: `ToDo.UDF.MVVM/Architecture/Router.swift`
- Test: `ToDo.UDF.MVVMTests/RouterTests.swift`

**Interfaces:**
- Produces: `@MainActor @Observable final class Router` with `var path: NavigationPath`, `func push<R: Hashable>(_:)`, `func pop()`, `func popToRoot()`.

- [ ] **Step 1: Write the failing test**

Create `ToDo.UDF.MVVMTests/RouterTests.swift`:
```swift
import Testing
import SwiftUI
@testable import ToDo_UDF_MVVM

@MainActor
struct RouterTests {
    @Test func pushAppends() {
        let router = Router()
        #expect(router.path.isEmpty)
        router.push("a")
        #expect(router.path.count == 1)
    }

    @Test func popRemovesLast() {
        let router = Router()
        router.push("a")
        router.push("b")
        router.pop()
        #expect(router.path.count == 1)
    }

    @Test func popOnEmptyDoesNotCrash() {
        let router = Router()
        router.pop()
        #expect(router.path.isEmpty)
    }

    @Test func popToRootClears() {
        let router = Router()
        router.push("a")
        router.push("b")
        router.popToRoot()
        #expect(router.path.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination 'id=93EC3745-46A5-4F90-A4CE-6411DB70C816' -only-testing:ToDo.UDF.MVVMTests/RouterTests 2>&1 | tail -20`
Expected: FAIL — `Cannot find 'Router' in scope`.

- [ ] **Step 3: Write the implementation**

Create `ToDo.UDF.MVVM/Architecture/Router.swift`:
```swift
//
//  Router.swift
//  ToDo.UDF.MVVM
//
//  Навігаційний стек поверх NavigationPath (push/pop/popToRoot).
//

import SwiftUI

@MainActor
@Observable
final class Router {
    var path = NavigationPath()

    func push<R: Hashable>(_ route: R) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path = NavigationPath() }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination 'id=93EC3745-46A5-4F90-A4CE-6411DB70C816' -only-testing:ToDo.UDF.MVVMTests/RouterTests 2>&1 | tail -20`
Expected: PASS (4/4).

- [ ] **Step 5: Commit**

```bash
git add ToDo.UDF.MVVM/Architecture/Router.swift ToDo.UDF.MVVMTests/RouterTests.swift
git commit -m "feat: add Router (NavigationPath wrapper)"
```

---

### Task 2: CoordinatorEffect + migrate TaskCreatedViewModel to onEffect

**Files:**
- Create: `ToDo.UDF.MVVM/Architecture/Coordinator.swift` (holds `CoordinatorEffect` enum; the `Coordinator` protocol is added in Task 4 — this task only needs the enum)
- Modify: `ToDo.UDF.MVVM/Screens/TaskCreatedViewModel.swift` (onContinue → onEffect)
- Modify: `ToDo.UDF.MVVMTests/TaskCreatedViewModelTests.swift` (update the continue test)

**Interfaces:**
- Produces: `enum CoordinatorEffect: Equatable { case finishCreated }`; `TaskCreatedViewModel(task: TaskSummary, onEffect: @escaping (CoordinatorEffect) -> Void = { _ in })`.
- Consumes: `TaskCreatedView.Props/SyncEvent/AsyncEvent`, `TaskSummary`, `UdfViewModel`.

- [ ] **Step 1: Write the failing test (update existing suite)**

Replace the body of `ToDo.UDF.MVVMTests/TaskCreatedViewModelTests.swift` with:
```swift
import Testing
@testable import ToDo_UDF_MVVM

@MainActor
struct TaskCreatedViewModelTests {
    @Test func continueTappedEmitsFinishCreated() {
        var received: CoordinatorEffect?
        let vm = TaskCreatedViewModel(task: .sample, onEffect: { received = $0 })
        vm.onEvent(.continueTapped)
        #expect(received == .finishCreated)
    }

    @Test func appearSetsAppeared() async {
        let vm = TaskCreatedViewModel(task: .sample)
        #expect(vm.props.appeared == false)
        await vm.onAsyncEvent(.appear(reduceMotion: true))
        #expect(vm.props.appeared)
    }

    @Test func initialPropsCarryTask() {
        let vm = TaskCreatedViewModel(task: .sample)
        #expect(vm.props.task == .sample)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination 'id=93EC3745-46A5-4F90-A4CE-6411DB70C816' -only-testing:ToDo.UDF.MVVMTests/TaskCreatedViewModelTests 2>&1 | tail -20`
Expected: FAIL — `Cannot find type 'CoordinatorEffect' in scope` and/or `extra argument 'onEffect'`.

- [ ] **Step 3: Add CoordinatorEffect**

Create `ToDo.UDF.MVVM/Architecture/Coordinator.swift`:
```swift
//
//  Coordinator.swift
//  ToDo.UDF.MVVM
//
//  Навігаційні ефекти, які ViewModel передає координатору.
//

import Foundation

enum CoordinatorEffect: Equatable {
    case finishCreated
}
```

- [ ] **Step 4: Migrate the ViewModel**

In `ToDo.UDF.MVVM/Screens/TaskCreatedViewModel.swift`, replace:
```swift
    @ObservationIgnored private let onContinue: () -> Void

    init(task: TaskSummary, onContinue: @escaping () -> Void = {}) {
        self.props = .initial(task: task)
        self.onContinue = onContinue
    }

    func onEvent(_ event: SyncEvent) {
        switch event {
        case .continueTapped:
            onContinue()
        }
    }
```
with:
```swift
    @ObservationIgnored private let onEffect: (CoordinatorEffect) -> Void

    init(task: TaskSummary, onEffect: @escaping (CoordinatorEffect) -> Void = { _ in }) {
        self.props = .initial(task: task)
        self.onEffect = onEffect
    }

    func onEvent(_ event: SyncEvent) {
        switch event {
        case .continueTapped:
            onEffect(.finishCreated)
        }
    }
```
(The `#Preview` in `TaskCreatedView.swift` calls `TaskCreatedViewModel(task: .sample)` with no closure — it still compiles via the `{ _ in }` default, so it needs no change.)

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination 'id=93EC3745-46A5-4F90-A4CE-6411DB70C816' -only-testing:ToDo.UDF.MVVMTests/TaskCreatedViewModelTests 2>&1 | tail -20`
Expected: PASS (3/3).

- [ ] **Step 6: Commit**

```bash
git add ToDo.UDF.MVVM/Architecture/Coordinator.swift ToDo.UDF.MVVM/Screens/TaskCreatedViewModel.swift ToDo.UDF.MVVMTests/TaskCreatedViewModelTests.swift
git commit -m "feat: add CoordinatorEffect; TaskCreatedViewModel emits onEffect"
```

---

### Task 3: UIFactory

**Files:**
- Create: `ToDo.UDF.MVVM/Screens/UIFactory.swift`
- Test: `ToDo.UDF.MVVMTests/UIFactoryTests.swift`

**Interfaces:**
- Consumes: `TaskCreatedViewModel(task:onEffect:)`, `CoordinatorEffect`, `TaskSummary`.
- Produces: `@MainActor protocol UIFactory { func taskCreatedViewModel(task:onEffect:) -> TaskCreatedViewModel }`; `final class DefaultUIFactory: UIFactory`.

- [ ] **Step 1: Write the failing test**

Create `ToDo.UDF.MVVMTests/UIFactoryTests.swift`:
```swift
import Testing
@testable import ToDo_UDF_MVVM

@MainActor
struct UIFactoryTests {
    @Test func buildsTaskCreatedViewModelCarryingTask() {
        let factory = DefaultUIFactory()
        let vm = factory.taskCreatedViewModel(task: .sample, onEffect: { _ in })
        #expect(vm.props.task == .sample)
    }

    @Test func builtViewModelEmitsEffect() {
        var received: CoordinatorEffect?
        let factory = DefaultUIFactory()
        let vm = factory.taskCreatedViewModel(task: .sample, onEffect: { received = $0 })
        vm.onEvent(.continueTapped)
        #expect(received == .finishCreated)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination 'id=93EC3745-46A5-4F90-A4CE-6411DB70C816' -only-testing:ToDo.UDF.MVVMTests/UIFactoryTests 2>&1 | tail -20`
Expected: FAIL — `Cannot find 'DefaultUIFactory' in scope`.

- [ ] **Step 3: Write the implementation**

Create `ToDo.UDF.MVVM/Screens/UIFactory.swift`:
```swift
//
//  UIFactory.swift
//  ToDo.UDF.MVVM
//
//  Будує ViewModel-и фічі та інжектить у них onEffect-колбек.
//

import Foundation

@MainActor
protocol UIFactory {
    func taskCreatedViewModel(
        task: TaskSummary,
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> TaskCreatedViewModel
}

@MainActor
final class DefaultUIFactory: UIFactory {
    func taskCreatedViewModel(
        task: TaskSummary,
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> TaskCreatedViewModel {
        TaskCreatedViewModel(task: task, onEffect: onEffect)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination 'id=93EC3745-46A5-4F90-A4CE-6411DB70C816' -only-testing:ToDo.UDF.MVVMTests/UIFactoryTests 2>&1 | tail -20`
Expected: PASS (2/2).

- [ ] **Step 5: Commit**

```bash
git add ToDo.UDF.MVVM/Screens/UIFactory.swift ToDo.UDF.MVVMTests/UIFactoryTests.swift
git commit -m "feat: add UIFactory building TaskCreatedViewModel with onEffect"
```

---

### Task 4: Coordinator protocol + TaskFlowCoordinator

**Files:**
- Modify: `ToDo.UDF.MVVM/Architecture/Coordinator.swift` (add the `Coordinator` protocol next to the existing `CoordinatorEffect`)
- Create: `ToDo.UDF.MVVM/Screens/TaskFlowCoordinator.swift`
- Test: `ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift`

**Interfaces:**
- Consumes: `Router`, `UIFactory`/`DefaultUIFactory`, `CoordinatorEffect`, `AnyUdfViewModel`, `TaskCreatedView.Props/SyncEvent/AsyncEvent`, `TaskSummary`.
- Produces: `@MainActor protocol Coordinator: AnyObject { func handle(_:) }`; `@MainActor @Observable final class TaskFlowCoordinator: Coordinator` with `let router: Router`, `init(factory: UIFactory = DefaultUIFactory())`, `func handle(_:)`, `func makeTaskCreatedViewModel(task:) -> AnyUdfViewModel<…>`.

- [ ] **Step 1: Write the failing test**

Create `ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift`:
```swift
import Testing
@testable import ToDo_UDF_MVVM

@MainActor
struct TaskFlowCoordinatorTests {
    @Test func finishCreatedPopsToRoot() {
        let coordinator = TaskFlowCoordinator()
        coordinator.router.push("x")
        #expect(coordinator.router.path.count == 1)
        coordinator.handle(.finishCreated)
        #expect(coordinator.router.path.isEmpty)
    }

    @Test func makesViewModelCarryingTask() {
        let coordinator = TaskFlowCoordinator()
        let vm = coordinator.makeTaskCreatedViewModel(task: .sample)
        #expect(vm.props.task == .sample)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination 'id=93EC3745-46A5-4F90-A4CE-6411DB70C816' -only-testing:ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests 2>&1 | tail -20`
Expected: FAIL — `Cannot find 'TaskFlowCoordinator' in scope`.

- [ ] **Step 3: Add the Coordinator protocol**

In `ToDo.UDF.MVVM/Architecture/Coordinator.swift`, add above the enum (keep the existing `CoordinatorEffect`):
```swift
@MainActor
protocol Coordinator: AnyObject {
    func handle(_ effect: CoordinatorEffect)
}
```
Resulting file:
```swift
//
//  Coordinator.swift
//  ToDo.UDF.MVVM
//
//  Координатор навігації та ефекти, які йому передає ViewModel.
//

import Foundation

@MainActor
protocol Coordinator: AnyObject {
    func handle(_ effect: CoordinatorEffect)
}

enum CoordinatorEffect: Equatable {
    case finishCreated
}
```

- [ ] **Step 4: Write TaskFlowCoordinator**

Create `ToDo.UDF.MVVM/Screens/TaskFlowCoordinator.swift`:
```swift
//
//  TaskFlowCoordinator.swift
//  ToDo.UDF.MVVM
//
//  Координатор todo-флоу: тримає Router/UIFactory, обробляє ефекти.
//

import SwiftUI

@MainActor
@Observable
final class TaskFlowCoordinator: Coordinator {
    let router = Router()

    @ObservationIgnored private let factory: UIFactory

    init(factory: UIFactory = DefaultUIFactory()) {
        self.factory = factory
    }

    func handle(_ effect: CoordinatorEffect) {
        switch effect {
        case .finishCreated:
            router.popToRoot()
        }
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

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination 'id=93EC3745-46A5-4F90-A4CE-6411DB70C816' -only-testing:ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests 2>&1 | tail -20`
Expected: PASS (2/2).

- [ ] **Step 6: Commit**

```bash
git add ToDo.UDF.MVVM/Architecture/Coordinator.swift ToDo.UDF.MVVM/Screens/TaskFlowCoordinator.swift ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift
git commit -m "feat: add Coordinator protocol + TaskFlowCoordinator"
```

---

### Task 5: TaskFlowView + end-to-end verification

**Files:**
- Create: `ToDo.UDF.MVVM/Screens/TaskFlowView.swift`

**Interfaces:**
- Consumes: `TaskFlowCoordinator`, `Router`, `TaskCreatedView`, `TaskSummary.sample`.
- Produces: `struct TaskFlowView: View`.

- [ ] **Step 1: Write TaskFlowView**

Create `ToDo.UDF.MVVM/Screens/TaskFlowView.swift`:
```swift
//
//  TaskFlowView.swift
//  ToDo.UDF.MVVM
//
//  Хост навігації todo-флоу: NavigationStack, прив'язаний до Router.
//

import SwiftUI

struct TaskFlowView: View {
    @State private var coordinator = TaskFlowCoordinator()

    var body: some View {
        @Bindable var router = coordinator.router
        NavigationStack(path: $router.path) {
            TaskCreatedView(viewModel: coordinator.makeTaskCreatedViewModel(task: .sample))
        }
    }
}

#Preview {
    TaskFlowView()
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -sdk iphonesimulator -destination 'id=93EC3745-46A5-4F90-A4CE-6411DB70C816' -configuration Debug build 2>&1 | grep -iE ' error:|BUILD SUCCEEDED|BUILD FAILED' | head`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Visual verification on simulator**

Temporarily point `ContentView.body` at `TaskFlowView()` (keep a note of the original body), build+install+launch on the iPhone 17 sim, capture a burst of screenshots into the scratchpad (first frame is often a blank launch fade), Read the screenshot, and confirm the success screen renders through the coordinator/UIFactory identically (badge, "Задачу створено", task card, "До списку" button). Then **revert `ContentView` to its original state**.

Expected: success screen renders identically; `ContentView` reverted (unchanged from its committed state).

- [ ] **Step 4: Full test suite**

Run: `xcodebuild test -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination 'id=93EC3745-46A5-4F90-A4CE-6411DB70C816' 2>&1 | grep -iE 'TEST SUCCEEDED|TEST FAILED|BUILD FAILED' | tail`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add ToDo.UDF.MVVM/Screens/TaskFlowView.swift
git commit -m "feat: add TaskFlowView hosting the navigation stack"
```

---

## Notes for the implementer

- SourceKit may show transient "Cannot find … in scope" across new files until the first build re-indexes the synchronized groups — trust the build, not live diagnostics.
- The simulator powers down between shell invocations in some environments; `xcrun simctl boot <id> 2>/dev/null; xcrun simctl bootstatus <id> -b` before install, and capture a short burst of screenshots.
- Do NOT touch `App`/`ContentView` in committed code — the Step-3 swap in Task 5 is temporary and must be reverted before the commit.
- `NavigationPath` exposes `.count` and `.isEmpty`, used by the Router tests.
