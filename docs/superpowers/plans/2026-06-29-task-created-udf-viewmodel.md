# TaskCreated UDF ViewModel + Infrastructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port a minimal UDF core (UdfViewModel + AnyUdfViewModel) into ToDo.UDF.MVVM and migrate TaskCreatedView from presentational to a UDF ViewModel as the pilot.

**Architecture:** Ledger-style UDF — a `UdfViewModel` protocol with `Props`/`SyncEvent`/`AsyncEvent`, type-erased through `AnyUdfViewModel` so Views hold the eraser while Observation tracks the concrete `@Observable` ViewModel. No Coordinator/UIFactory; the ViewModel is created at the call-site.

**Tech Stack:** SwiftUI, Observation (`@Observable`), Swift Testing (`import Testing`).

## Global Constraints

- iOS deployment target **26.2**; module name **`ToDo_UDF_MVVM`**.
- Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`) with `@testable import ToDo_UDF_MVVM`. ViewModel/eraser are `@MainActor`, so test suites that touch them are annotated `@MainActor`.
- UDF types are `@MainActor`; ViewModels are `@Observable`; injected deps are `@ObservationIgnored private let`.
- **Minimal inline comments** — the project owner strips doc-comments; keep only file-header and non-obvious-why comments.
- **No Coordinator/UIFactory** — VM is created at the call-site (`#Preview`).
- Build/test simulator: **iPhone 17**, id `93EC3745-46A5-4F90-A4CE-6411DB70C816`.
- New files fall under the app target's existing source globs (file-system-synchronized Xcode project, `objectVersion = 77`); `project.pbxproj` is NOT edited.

---

### Task 1: UDF Infrastructure (UdfViewModel + AnyUdfViewModel)

**Files:**
- Create: `ToDo.UDF.MVVM/Architecture/UdfViewModel.swift`
- Create: `ToDo.UDF.MVVM/Architecture/AnyUdfViewModel.swift`
- Test: `ToDo.UDF.MVVMTests/AnyUdfViewModelTests.swift`

**Interfaces:**
- Produces:
  - `protocol UdfViewModel: AnyObject` (`@MainActor`) with `associatedtype Props/SyncEvent/AsyncEvent`, `var props: Props { get }`, `func onEvent(_:)`, `func onAsyncEvent(_:) async`.
  - `func eraseToAnyViewModel() -> AnyUdfViewModel<Props, SyncEvent, AsyncEvent>` (extension on `UdfViewModel`).
  - `final class MockUdfViewModel<P, S, A>: UdfViewModel` (`@Observable`, `var props: P`, no-op handlers).
  - `final class AnyUdfViewModel<Props, SyncEvent, AsyncEvent>` (`@MainActor`) with `var props`, `func onEvent(_:)`, `func onAsync(_:) async`.

- [ ] **Step 1: Write the failing test**

Create `ToDo.UDF.MVVMTests/AnyUdfViewModelTests.swift`:
```swift
import Testing
@testable import ToDo_UDF_MVVM

@MainActor
struct AnyUdfViewModelTests {
    @Test func forwardsLiveProps() {
        let mock = MockUdfViewModel<Int, String, String>(0)
        let erased = mock.eraseToAnyViewModel()
        #expect(erased.props == 0)
        mock.props = 42
        #expect(erased.props == 42)
    }

    @Test func onAsyncDoesNotCrash() async {
        let mock = MockUdfViewModel<Int, String, String>(1)
        let erased = mock.eraseToAnyViewModel()
        erased.onEvent("noop")
        await erased.onAsync("noop")
        #expect(erased.props == 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination 'id=93EC3745-46A5-4F90-A4CE-6411DB70C816' -only-testing:ToDo.UDF.MVVMTests/AnyUdfViewModelTests 2>&1 | tail -20`
Expected: FAIL — `Cannot find 'MockUdfViewModel' in scope` (types not defined yet).

- [ ] **Step 3: Write the protocol + Mock**

Create `ToDo.UDF.MVVM/Architecture/UdfViewModel.swift`:
```swift
//
//  UdfViewModel.swift
//  ToDo.UDF.MVVM
//
//  Ядро UDF: протокол ViewModel зі знімком стану (Props) та подіями.
//

import SwiftUI

@MainActor
protocol UdfViewModel: AnyObject {
    associatedtype Props
    associatedtype SyncEvent
    associatedtype AsyncEvent

    var props: Props { get }
    func onEvent(_ event: SyncEvent)
    func onAsyncEvent(_ event: AsyncEvent) async
}

extension UdfViewModel {
    func eraseToAnyViewModel() -> AnyUdfViewModel<Props, SyncEvent, AsyncEvent> {
        AnyUdfViewModel(self)
    }
}

@MainActor
@Observable
final class MockUdfViewModel<P, S, A>: UdfViewModel {
    var props: P
    init(_ props: P) { self.props = props }
    func onEvent(_ event: S) {}
    func onAsyncEvent(_ event: A) async {}
}
```

- [ ] **Step 4: Write the type-eraser**

Create `ToDo.UDF.MVVM/Architecture/AnyUdfViewModel.swift`:
```swift
//
//  AnyUdfViewModel.swift
//  ToDo.UDF.MVVM
//
//  Type-eraser над UdfViewModel. Замикання захоплюють @Observable base,
//  тож Observation відстежує props крізь обгортку.
//

import SwiftUI

@MainActor
final class AnyUdfViewModel<Props, SyncEvent, AsyncEvent> {
    private let propsGetter: () -> Props
    private let eventHandler: (SyncEvent) -> Void
    private let asyncHandler: (AsyncEvent) async -> Void

    init<Base: UdfViewModel>(_ base: Base)
    where Base.Props == Props, Base.SyncEvent == SyncEvent, Base.AsyncEvent == AsyncEvent {
        propsGetter = { base.props }
        eventHandler = { base.onEvent($0) }
        asyncHandler = { await base.onAsyncEvent($0) }
    }

    var props: Props { propsGetter() }
    func onEvent(_ event: SyncEvent) { eventHandler(event) }
    func onAsync(_ event: AsyncEvent) async { await asyncHandler(event) }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination 'id=93EC3745-46A5-4F90-A4CE-6411DB70C816' -only-testing:ToDo.UDF.MVVMTests/AnyUdfViewModelTests 2>&1 | tail -20`
Expected: PASS (`Test Suite 'AnyUdfViewModelTests' passed`).

- [ ] **Step 6: Commit**

```bash
git add ToDo.UDF.MVVM/Architecture ToDo.UDF.MVVMTests/AnyUdfViewModelTests.swift
git commit -m "feat: add UDF core (UdfViewModel + AnyUdfViewModel)"
```

---

### Task 2: TaskSummary Equatable + TaskCreated Props/Events

**Files:**
- Modify: `ToDo.UDF.MVVM/Models/TaskSummary.swift` (line 33: `struct TaskSummary` → add `: Equatable`)
- Create: `ToDo.UDF.MVVM/Screens/TaskCreatedProps.swift`
- Test: `ToDo.UDF.MVVMTests/TaskCreatedPropsTests.swift`

**Interfaces:**
- Consumes: `TaskSummary` (now `Equatable`), `TaskCreatedView` (existing presentational type — the `extension` attaches to it).
- Produces:
  - `TaskCreatedView.Props` (`Equatable`): `let task: TaskSummary`, `var appeared: Bool`, `static func initial(task:) -> Props`.
  - `TaskCreatedView.SyncEvent`: `.continueTapped`.
  - `TaskCreatedView.AsyncEvent`: `.appear(reduceMotion: Bool)`.

- [ ] **Step 1: Write the failing test**

Create `ToDo.UDF.MVVMTests/TaskCreatedPropsTests.swift`:
```swift
import Testing
@testable import ToDo_UDF_MVVM

struct TaskCreatedPropsTests {
    @Test func initialPropsAreEquatableAndNotAppeared() {
        let a = TaskCreatedView.Props.initial(task: .sample)
        let b = TaskCreatedView.Props.initial(task: .sample)
        #expect(a == b)
        #expect(a.appeared == false)
        #expect(a.task == .sample)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination 'id=93EC3745-46A5-4F90-A4CE-6411DB70C816' -only-testing:ToDo.UDF.MVVMTests/TaskCreatedPropsTests 2>&1 | tail -20`
Expected: FAIL — `Type 'TaskCreatedView' has no member 'Props'` and/or `TaskSummary` not `Equatable`.

- [ ] **Step 3: Make TaskSummary Equatable**

In `ToDo.UDF.MVVM/Models/TaskSummary.swift`, change:
```swift
struct TaskSummary {
```
to:
```swift
struct TaskSummary: Equatable {
```

- [ ] **Step 4: Create the Props/Events**

Create `ToDo.UDF.MVVM/Screens/TaskCreatedProps.swift`:
```swift
//
//  TaskCreatedProps.swift
//  ToDo.UDF.MVVM
//
//  UDF-стан і події екрана «Задачу створено».
//

import Foundation

extension TaskCreatedView {
    struct Props: Equatable {
        let task: TaskSummary
        var appeared: Bool

        static func initial(task: TaskSummary) -> Props {
            Props(task: task, appeared: false)
        }
    }

    enum SyncEvent: Equatable {
        case continueTapped
    }

    enum AsyncEvent: Equatable {
        case appear(reduceMotion: Bool)
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination 'id=93EC3745-46A5-4F90-A4CE-6411DB70C816' -only-testing:ToDo.UDF.MVVMTests/TaskCreatedPropsTests 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add ToDo.UDF.MVVM/Models/TaskSummary.swift ToDo.UDF.MVVM/Screens/TaskCreatedProps.swift ToDo.UDF.MVVMTests/TaskCreatedPropsTests.swift
git commit -m "feat: add TaskCreated Props/Events; make TaskSummary Equatable"
```

---

### Task 3: TaskCreatedViewModel

**Files:**
- Create: `ToDo.UDF.MVVM/Screens/TaskCreatedViewModel.swift`
- Test: `ToDo.UDF.MVVMTests/TaskCreatedViewModelTests.swift`

**Interfaces:**
- Consumes: `UdfViewModel`, `TaskCreatedView.Props/SyncEvent/AsyncEvent`, `TaskSummary`.
- Produces: `TaskCreatedViewModel(task: TaskSummary, onContinue: @escaping () -> Void = {})`; conforms to `UdfViewModel`; `private(set) var props`.

- [ ] **Step 1: Write the failing test**

Create `ToDo.UDF.MVVMTests/TaskCreatedViewModelTests.swift`:
```swift
import Testing
@testable import ToDo_UDF_MVVM

@MainActor
struct TaskCreatedViewModelTests {
    @Test func continueTappedInvokesCallback() {
        var continued = false
        let vm = TaskCreatedViewModel(task: .sample, onContinue: { continued = true })
        vm.onEvent(.continueTapped)
        #expect(continued)
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
Expected: FAIL — `Cannot find 'TaskCreatedViewModel' in scope`.

- [ ] **Step 3: Write the ViewModel**

Create `ToDo.UDF.MVVM/Screens/TaskCreatedViewModel.swift`:
```swift
//
//  TaskCreatedViewModel.swift
//  ToDo.UDF.MVVM
//
//  UDF-ViewModel екрана «Задачу створено».
//

import SwiftUI

@MainActor
@Observable
final class TaskCreatedViewModel: UdfViewModel {
    typealias Props = TaskCreatedView.Props
    typealias SyncEvent = TaskCreatedView.SyncEvent
    typealias AsyncEvent = TaskCreatedView.AsyncEvent

    private(set) var props: Props

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

    func onAsyncEvent(_ event: AsyncEvent) async {
        switch event {
        case .appear(let reduceMotion):
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7)) {
                props.appeared = true
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination 'id=93EC3745-46A5-4F90-A4CE-6411DB70C816' -only-testing:ToDo.UDF.MVVMTests/TaskCreatedViewModelTests 2>&1 | tail -20`
Expected: PASS (all 3 tests).

- [ ] **Step 5: Commit**

```bash
git add ToDo.UDF.MVVM/Screens/TaskCreatedViewModel.swift ToDo.UDF.MVVMTests/TaskCreatedViewModelTests.swift
git commit -m "feat: add TaskCreatedViewModel (UDF)"
```

---

### Task 4: Migrate TaskCreatedView to AnyUdfViewModel

**Files:**
- Modify: `ToDo.UDF.MVVM/Screens/TaskCreatedView.swift` (replace `task`/`onContinue` stored props with an `AnyUdfViewModel`; read `viewModel.props`; route the button + `.task`)

**Interfaces:**
- Consumes: `AnyUdfViewModel<TaskCreatedView.Props, .SyncEvent, .AsyncEvent>`, `TaskCreatedViewModel`, `TaskSummary.sample`.
- Produces: `TaskCreatedView(viewModel:)` initializer.

- [ ] **Step 1: Replace the View's stored state and init**

In `ToDo.UDF.MVVM/Screens/TaskCreatedView.swift`, replace:
```swift
struct TaskCreatedView: View {
    let task: TaskSummary
    /// Дія кнопки «До списку». За замовчуванням порожня — щоб працювало в Preview.
    var onContinue: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
```
with:
```swift
struct TaskCreatedView: View {
    @State private var viewModel: AnyUdfViewModel<Props, SyncEvent, AsyncEvent>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: AnyUdfViewModel<Props, SyncEvent, AsyncEvent>) {
        _viewModel = State(initialValue: viewModel)
    }
```

- [ ] **Step 2: Point the body at `viewModel.props` and route events**

In the same file's `body`, apply these substitutions:
- `SuccessBadge()` modifiers — replace `appeared || reduceMotion ? 1 : 0.6` with `viewModel.props.appeared ? 1 : 0.6`, and `appeared ? 1 : 0` with `viewModel.props.appeared ? 1 : 0`.
- The card block — replace `TaskSummaryCard(task: task)` with `TaskSummaryCard(task: viewModel.props.task)`; replace `.opacity(appeared ? 1 : 0)` with `.opacity(viewModel.props.appeared ? 1 : 0)`; replace `.offset(y: appeared || reduceMotion ? 0 : 12)` with `.offset(y: viewModel.props.appeared ? 0 : 12)`.
- The button — replace:
  ```swift
  Button("До списку", action: onContinue)
      .buttonStyle(PrimaryButtonStyle())
  ```
  with:
  ```swift
  Button("До списку") { viewModel.onEvent(.continueTapped) }
      .buttonStyle(PrimaryButtonStyle())
  ```
- Replace the trailing `.onAppear { withAnimation(...) { appeared = true } }` block:
  ```swift
  .onAppear {
      withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
          appeared = true
      }
  }
  ```
  with:
  ```swift
  .task {
      await viewModel.onAsync(.appear(reduceMotion: reduceMotion))
  }
  ```

(`SuccessBadge` private struct stays unchanged.)

- [ ] **Step 3: Update the Preview**

Replace the existing `#Preview { TaskCreatedView(task: .sample) }` with:
```swift
#Preview {
    TaskCreatedView(viewModel: TaskCreatedViewModel(task: .sample).eraseToAnyViewModel())
}
```

- [ ] **Step 4: Build to verify it compiles**

Run: `xcodebuild -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -sdk iphonesimulator -destination 'id=93EC3745-46A5-4F90-A4CE-6411DB70C816' -configuration Debug build 2>&1 | grep -iE ' error:|BUILD SUCCEEDED|BUILD FAILED' | head`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Visual verification on simulator**

Temporarily point `ContentView.body` at `TaskCreatedView(viewModel: TaskCreatedViewModel(task: .sample).eraseToAnyViewModel())`, build+install+launch on the iPhone 17 sim, capture a screenshot, confirm the success screen looks identical to before (badge scales in, "Задачу створено", task card, "До списку" button), then revert `ContentView`.

Expected: screen identical to the pre-UDF version; tapping "До списку" calls the injected `onContinue` (verified via the unit test in Task 3).

- [ ] **Step 6: Run the full test suite + final build**

Run: `xcodebuild test -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination 'id=93EC3745-46A5-4F90-A4CE-6411DB70C816' 2>&1 | grep -iE 'TEST (SUCCEEDED|FAILED)|BUILD FAILED' | tail`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add ToDo.UDF.MVVM/Screens/TaskCreatedView.swift
git commit -m "refactor: drive TaskCreatedView through UDF ViewModel"
```

---

## Notes for the implementer

- SourceKit may show transient "Cannot find … in scope" across the new files until the first build re-indexes the synchronized groups — trust the build, not the live diagnostics.
- The simulator powers down between shell invocations in some environments; re-`boot` + `bootstatus -b` before install, and capture a short burst of screenshots (the first frame can be a blank launch fade).
