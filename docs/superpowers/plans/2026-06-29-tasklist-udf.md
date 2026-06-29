# TaskListView → UDF Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Перевести `TaskListView` з presentational-`@State` на UDF (Props/Events + `@Observable` ViewModel + `AnyUdfViewModel`), підключивши FAB через `onEffect`/Coordinator/UIFactory.

**Architecture:** Дзеркало `TaskCreated` (#1). VM тримає мутабельний `[TodoTask]` як джерело істини й деривує незмінний `Props` (`[TaskRow]` + `progress`); `TaskRow` — окрема view-проекція, тож Props не залежить від моделі. `toggle` несе `reduceMotion` і анімується у VM; FAB емітує `CoordinatorEffect.createTaskRequested` (no-op стаб до #4).

**Tech Stack:** SwiftUI (iOS 26.2), Observation (`@Observable`, `@ObservationIgnored`), Swift Testing.

## Global Constraints

- Модуль тестів: `@testable import ToDo_UDF_MVVM`; Swift Testing (`import Testing`, `@Test`, `#expect`, `@MainActor` suite).
- UDF: `@MainActor @Observable final class … : UdfViewModel`; `private(set) var props`; `@ObservationIgnored private let onEffect`; ерейзинг через `eraseToAnyViewModel()`.
- `Props: Equatable` — нуль логіки, нуль `TodoTask`; уся деривація у VM.
- `[weak self]` у замиканні `onEffect`, що передається у VM.
- Xcode synchronized groups (objectVersion 77) — **НЕ редагувати `project.pbxproj`** (нові `.swift` підхоплюються самі).
- Мінімум коментарів (стиль проекту).
- **App root (`App`/`ContentView`) і `TaskFlowView` НЕ чіпати** (тимчасова підміна `ContentView` у Task 4 — лише для скріншоту, з обов'язковим ревертом).
- Симулятор iPhone 17, id `93EC3745-46A5-4F90-A4CE-6411DB70C816`; перед `xcodebuild` — `xcrun simctl boot "$SIM" 2>/dev/null; xcrun simctl bootstatus "$SIM" -b`. Повний прогон тестів — лише `-only-testing:ToDo.UDF.MVVMTests` (UI-тести template зависають на симуляторі).
- SourceKit може хибно підсвічувати cross-file scope до першого білда — довіряти білду.

**Команда тестів (підставляти `-only-testing` за потреби):**
```bash
SIM=93EC3745-46A5-4F90-A4CE-6411DB70C816
xcrun simctl boot "$SIM" 2>/dev/null; xcrun simctl bootstatus "$SIM" -b
xcodebuild test -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM \
  -destination "id=$SIM" -only-testing:ToDo.UDF.MVVMTests 2>&1 | tail -25
```

---

## File Structure

**Нові:**
- `ToDo.UDF.MVVM/Models/TaskRow.swift` — незмінна view-проекція рядка (`Equatable, Identifiable`).
- `ToDo.UDF.MVVM/Screens/TaskListProps.swift` — `extension TaskListView { Props / SyncEvent / AsyncEvent }`.
- `ToDo.UDF.MVVM/Screens/TaskListViewModel.swift` — UDF ViewModel списку.
- `ToDo.UDF.MVVMTests/TaskListViewModelTests.swift` — тести VM.

**Змінені:**
- `ToDo.UDF.MVVM/Architecture/Coordinator.swift` — `+ case createTaskRequested`.
- `ToDo.UDF.MVVM/Screens/TaskFlowCoordinator.swift` — `handle` стаб + `makeTaskListViewModel`.
- `ToDo.UDF.MVVM/Screens/UIFactory.swift` — `+ taskListViewModel(tasks:onEffect:)`.
- `ToDo.UDF.MVVM/Components/TaskListRow.swift`, `CompletedTaskRow.swift` — вхід `TodoTask` → `TaskRow`.
- `ToDo.UDF.MVVM/Screens/TaskListView.swift` — UDF-driven.
- `ToDo.UDF.MVVMTests/UIFactoryTests.swift`, `TaskFlowCoordinatorTests.swift` — нові кейси.

**Без змін:** `Models/TodoTask.swift` (модель/джерело істини; `Equatable` не потрібен).

---

## Task 1: CoordinatorEffect.createTaskRequested + handle-стаб

**Files:**
- Modify: `ToDo.UDF.MVVM/Architecture/Coordinator.swift:13-15`
- Modify: `ToDo.UDF.MVVM/Screens/TaskFlowCoordinator.swift:19-24`
- Test: `ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift`

**Interfaces:**
- Consumes: наявний `TaskFlowCoordinator` (`let router`, `func handle(_:)`), `Router` (`push`, `path`).
- Produces: `CoordinatorEffect.createTaskRequested`; `TaskFlowCoordinator.handle(.createTaskRequested)` — no-op (router.path не змінюється). Це споживають Task 2 (VM емітує) і Task 3 (coordinator будує VM з `onEffect: handle`).

- [ ] **Step 1: Дописати падаючий тест** у `ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift` (після `makesViewModelCarryingTask`, перед закриваючою `}` структури):

```swift
    @Test func createTaskRequestedIsNoOp() {
        let coordinator = TaskFlowCoordinator()
        coordinator.handle(.createTaskRequested)
        #expect(coordinator.router.path.isEmpty)
    }
```

- [ ] **Step 2: Переконатися, що падає (компіляція)**

Run: `-only-testing:ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests`
Expected: FAIL — `type 'CoordinatorEffect' has no member 'createTaskRequested'`.

- [ ] **Step 3: Додати кейс** — повний новий вміст `ToDo.UDF.MVVM/Architecture/Coordinator.swift`:

```swift
//
//  Coordinator.swift
//  ToDo.UDF.MVVM
//

import Foundation

@MainActor
protocol Coordinator: AnyObject {
    func handle(_ effect: CoordinatorEffect)
}

enum CoordinatorEffect: Equatable {
    case finishCreated
    case createTaskRequested
}
```

- [ ] **Step 4: Зробити switch вичерпним** — замінити метод `handle` у `ToDo.UDF.MVVM/Screens/TaskFlowCoordinator.swift`:

```swift
    func handle(_ effect: CoordinatorEffect) {
        switch effect {
        case .finishCreated:
            router.popToRoot()
        case .createTaskRequested:
            break
        }
    }
```

- [ ] **Step 5: Переконатися, що проходить**

Run: `-only-testing:ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests`
Expected: PASS — `finishCreatedPopsToRoot`, `makesViewModelCarryingTask`, `createTaskRequestedIsNoOp`.

- [ ] **Step 6: Коміт**

```bash
git add ToDo.UDF.MVVM/Architecture/Coordinator.swift ToDo.UDF.MVVM/Screens/TaskFlowCoordinator.swift ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift
git commit -m "feat: add CoordinatorEffect.createTaskRequested (no-op stub)"
```

---

## Task 2: TaskRow + Props/Events + TaskListViewModel

**Files:**
- Create: `ToDo.UDF.MVVM/Models/TaskRow.swift`
- Create: `ToDo.UDF.MVVM/Screens/TaskListProps.swift`
- Create: `ToDo.UDF.MVVM/Screens/TaskListViewModel.swift`
- Test: `ToDo.UDF.MVVMTests/TaskListViewModelTests.swift`

**Interfaces:**
- Consumes: `CoordinatorEffect.createTaskRequested` (Task 1); `TodoTask` (`let id: UUID`, `var title: String`, `var notes: String?`, `var time: String`, `var priority: TaskPriority`, `var isDone: Bool`, `static let sampleList: [TodoTask]` — 4 активні + 2 виконані); `UdfViewModel`, `eraseToAnyViewModel()`.
- Produces:
  - `struct TaskRow: Equatable, Identifiable` з `init(id:title:notes:time:priority:isDone:)`.
  - `extension TaskListView`: `struct Props: Equatable { var active: [TaskRow]; var completed: [TaskRow]; var progress: Double }`; `enum SyncEvent: Equatable { case toggle(id: UUID, reduceMotion: Bool); case addTapped }`; `enum AsyncEvent: Equatable {}`.
  - `final class TaskListViewModel: UdfViewModel` з `init(tasks: [TodoTask] = TodoTask.sampleList, onEffect: @escaping (CoordinatorEffect) -> Void = { _ in })`, `private(set) var props: TaskListView.Props`.

- [ ] **Step 1: Написати падаючі тести** — створити `ToDo.UDF.MVVMTests/TaskListViewModelTests.swift`:

```swift
import Testing
@testable import ToDo_UDF_MVVM

@MainActor
struct TaskListViewModelTests {
    @Test func initialPropsSplitTasks() {
        let vm = TaskListViewModel()
        #expect(vm.props.active.count == 4)
        #expect(vm.props.completed.count == 2)
        #expect(abs(vm.props.progress - 2.0 / 6.0) < 0.0001)
    }

    @Test func toggleActiveMovesToCompleted() {
        let vm = TaskListViewModel()
        let target = vm.props.active[0]
        vm.onEvent(.toggle(id: target.id, reduceMotion: true))
        #expect(!vm.props.active.contains { $0.id == target.id })
        #expect(vm.props.completed.contains { $0.id == target.id })
        #expect(vm.props.completed.count == 3)
    }

    @Test func toggleCompletedMovesToActive() {
        let vm = TaskListViewModel()
        let target = vm.props.completed[0]
        vm.onEvent(.toggle(id: target.id, reduceMotion: true))
        #expect(vm.props.active.contains { $0.id == target.id })
        #expect(vm.props.completed.count == 1)
    }

    @Test func toggleUnknownIdDoesNothing() {
        let vm = TaskListViewModel()
        vm.onEvent(.toggle(id: UUID(), reduceMotion: true))
        #expect(vm.props.active.count == 4)
        #expect(vm.props.completed.count == 2)
    }

    @Test func addTappedEmitsCreateTaskRequested() {
        var received: CoordinatorEffect?
        let vm = TaskListViewModel(onEffect: { received = $0 })
        vm.onEvent(.addTapped)
        #expect(received == .createTaskRequested)
    }
}
```

- [ ] **Step 2: Переконатися, що падає**

Run: `-only-testing:ToDo.UDF.MVVMTests/TaskListViewModelTests`
Expected: FAIL — `cannot find 'TaskListViewModel' in scope` (і `TaskRow`/Props ще немає).

- [ ] **Step 3: Створити `ToDo.UDF.MVVM/Models/TaskRow.swift`**

```swift
//
//  TaskRow.swift
//  ToDo.UDF.MVVM
//
//  Незмінна view-проекція рядка задачі. Її споживають Props і компоненти
//  рядків — не TodoTask. Мапінг TodoTask → TaskRow живе у ViewModel.
//

import Foundation

struct TaskRow: Equatable, Identifiable {
    let id: UUID
    let title: String
    let notes: String?
    let time: String
    let priority: TaskPriority
    let isDone: Bool
}
```

- [ ] **Step 4: Створити `ToDo.UDF.MVVM/Screens/TaskListProps.swift`**

```swift
//
//  TaskListProps.swift
//  ToDo.UDF.MVVM
//
//  UDF-стан і події екрана списку задач.
//

import Foundation

extension TaskListView {
    struct Props: Equatable {
        var active: [TaskRow]
        var completed: [TaskRow]
        var progress: Double
    }

    enum SyncEvent: Equatable {
        case toggle(id: UUID, reduceMotion: Bool)
        case addTapped
    }

    enum AsyncEvent: Equatable {}
}
```

- [ ] **Step 5: Створити `ToDo.UDF.MVVM/Screens/TaskListViewModel.swift`**

```swift
//
//  TaskListViewModel.swift
//  ToDo.UDF.MVVM
//
//  UDF-ViewModel списку задач. Тримає [TodoTask] як джерело істини
//  й деривує Props ([TaskRow] + progress).
//

import SwiftUI

@MainActor
@Observable
final class TaskListViewModel: UdfViewModel {
    typealias Props = TaskListView.Props
    typealias SyncEvent = TaskListView.SyncEvent
    typealias AsyncEvent = TaskListView.AsyncEvent

    private(set) var props: Props

    @ObservationIgnored private var tasks: [TodoTask]
    @ObservationIgnored private let onEffect: (CoordinatorEffect) -> Void

    init(
        tasks: [TodoTask] = TodoTask.sampleList,
        onEffect: @escaping (CoordinatorEffect) -> Void = { _ in }
    ) {
        self.tasks = tasks
        self.onEffect = onEffect
        self.props = Self.makeProps(from: tasks)
    }

    func onEvent(_ event: SyncEvent) {
        switch event {
        case let .toggle(id, reduceMotion):
            guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
            tasks[i].isDone.toggle()
            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
                props = Self.makeProps(from: tasks)
            }
        case .addTapped:
            onEffect(.createTaskRequested)
        }
    }

    func onAsyncEvent(_ event: AsyncEvent) async {}

    private static func makeProps(from tasks: [TodoTask]) -> Props {
        let rows = tasks.map {
            TaskRow(id: $0.id, title: $0.title, notes: $0.notes,
                    time: $0.time, priority: $0.priority, isDone: $0.isDone)
        }
        let active = rows.filter { !$0.isDone }
        let completed = rows.filter { $0.isDone }
        let progress = rows.isEmpty ? 0 : Double(completed.count) / Double(rows.count)
        return Props(active: active, completed: completed, progress: progress)
    }
}
```

- [ ] **Step 6: Переконатися, що проходить**

Run: `-only-testing:ToDo.UDF.MVVMTests/TaskListViewModelTests`
Expected: PASS — усі 5 тестів.

- [ ] **Step 7: Коміт**

```bash
git add ToDo.UDF.MVVM/Models/TaskRow.swift ToDo.UDF.MVVM/Screens/TaskListProps.swift ToDo.UDF.MVVM/Screens/TaskListViewModel.swift ToDo.UDF.MVVMTests/TaskListViewModelTests.swift
git commit -m "feat: add TaskRow + TaskListViewModel (UDF state & logic)"
```

---

## Task 3: UIFactory + TaskFlowCoordinator обв'язка

**Files:**
- Modify: `ToDo.UDF.MVVM/Screens/UIFactory.swift`
- Modify: `ToDo.UDF.MVVM/Screens/TaskFlowCoordinator.swift`
- Test: `ToDo.UDF.MVVMTests/UIFactoryTests.swift`, `ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift`

**Interfaces:**
- Consumes: `TaskListViewModel(tasks:onEffect:)`, `TaskListView.Props/SyncEvent/AsyncEvent`, `TaskRow` (Task 2); `CoordinatorEffect.createTaskRequested` (Task 1); `TodoTask.sampleList`; `eraseToAnyViewModel()`.
- Produces:
  - `UIFactory.taskListViewModel(tasks: [TodoTask], onEffect: @escaping (CoordinatorEffect) -> Void) -> TaskListViewModel`.
  - `TaskFlowCoordinator.makeTaskListViewModel(tasks: [TodoTask] = TodoTask.sampleList) -> AnyUdfViewModel<TaskListView.Props, TaskListView.SyncEvent, TaskListView.AsyncEvent>`.

- [ ] **Step 1: Дописати падаючі тести.** У `ToDo.UDF.MVVMTests/UIFactoryTests.swift` (перед закриваючою `}`):

```swift
    @Test func buildsTaskListViewModelCarryingTasks() {
        let factory = DefaultUIFactory()
        let vm = factory.taskListViewModel(tasks: TodoTask.sampleList, onEffect: { _ in })
        #expect(vm.props.active.count + vm.props.completed.count == TodoTask.sampleList.count)
    }

    @Test func builtTaskListViewModelEmitsEffect() {
        var received: CoordinatorEffect?
        let factory = DefaultUIFactory()
        let vm = factory.taskListViewModel(tasks: TodoTask.sampleList, onEffect: { received = $0 })
        vm.onEvent(.addTapped)
        #expect(received == .createTaskRequested)
    }
```

У `ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift` (перед закриваючою `}`):

```swift
    @Test func makesTaskListViewModelCarryingTasks() {
        let coordinator = TaskFlowCoordinator()
        let vm = coordinator.makeTaskListViewModel()
        #expect(vm.props.active.count + vm.props.completed.count == TodoTask.sampleList.count)
    }
```

- [ ] **Step 2: Переконатися, що падає**

Run: `-only-testing:ToDo.UDF.MVVMTests/UIFactoryTests -only-testing:ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests`
Expected: FAIL — `value of type 'DefaultUIFactory' has no member 'taskListViewModel'` / `…'TaskFlowCoordinator' has no member 'makeTaskListViewModel'`.

- [ ] **Step 3: Розширити `UIFactory`** — повний новий вміст `ToDo.UDF.MVVM/Screens/UIFactory.swift`:

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

    func taskListViewModel(
        tasks: [TodoTask],
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> TaskListViewModel
}

@MainActor
final class DefaultUIFactory: UIFactory {
    nonisolated init() {}

    func taskCreatedViewModel(
        task: TaskSummary,
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> TaskCreatedViewModel {
        TaskCreatedViewModel(task: task, onEffect: onEffect)
    }

    func taskListViewModel(
        tasks: [TodoTask],
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> TaskListViewModel {
        TaskListViewModel(tasks: tasks, onEffect: onEffect)
    }
}
```

- [ ] **Step 4: Додати `makeTaskListViewModel`** у `ToDo.UDF.MVVM/Screens/TaskFlowCoordinator.swift` (після `makeTaskCreatedViewModel`, перед закриваючою `}` класу):

```swift
    func makeTaskListViewModel(
        tasks: [TodoTask] = TodoTask.sampleList
    ) -> AnyUdfViewModel<TaskListView.Props, TaskListView.SyncEvent, TaskListView.AsyncEvent> {
        factory
            .taskListViewModel(tasks: tasks, onEffect: { [weak self] effect in self?.handle(effect) })
            .eraseToAnyViewModel()
    }
```

- [ ] **Step 5: Переконатися, що проходить**

Run: `-only-testing:ToDo.UDF.MVVMTests/UIFactoryTests -only-testing:ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests`
Expected: PASS — нові 3 кейси + наявні.

- [ ] **Step 6: Коміт**

```bash
git add ToDo.UDF.MVVM/Screens/UIFactory.swift ToDo.UDF.MVVM/Screens/TaskFlowCoordinator.swift ToDo.UDF.MVVMTests/UIFactoryTests.swift ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift
git commit -m "feat: factory & coordinator build TaskListViewModel"
```

---

## Task 4: Міграція TaskListView + рядків на TaskRow/UDF + верифікація

**Files:**
- Modify: `ToDo.UDF.MVVM/Components/TaskListRow.swift`
- Modify: `ToDo.UDF.MVVM/Components/CompletedTaskRow.swift`
- Modify: `ToDo.UDF.MVVM/Screens/TaskListView.swift`
- Verify-only (revert!): `ToDo.UDF.MVVM/ContentView.swift`

**Interfaces:**
- Consumes: `TaskRow` (Task 2); `TaskListView.Props/SyncEvent/AsyncEvent` (Task 2); `TaskListViewModel`, `eraseToAnyViewModel()`; `TaskFlowCoordinator.makeTaskListViewModel()` (Task 3); `AnyUdfViewModel`.
- Produces: UDF-driven `TaskListView(viewModel:)`; рядки `TaskListRow(row:onToggle:)`, `CompletedTaskRow(row:onToggle:)`.

Без нового unit-тесту: уся логіка покрита Task 1–3; екран перевіряємо білдом + повним прогоном + скріншотом (як #1 Task 5). Рядки й view міняємо разом — білд стає консистентним лише наприкінці Step 3.

- [ ] **Step 1: Перевести `TaskListRow` на `TaskRow`** — повний новий вміст `ToDo.UDF.MVVM/Components/TaskListRow.swift`:

```swift
//
//  TaskListRow.swift
//  ToDo.UDF.MVVM
//
//  Картка активної задачі: чекбокс, назва, опис, час і пріоритет.
//

import SwiftUI

struct TaskListRow: View {
    let row: TaskRow
    var onToggle: () -> Void = {}

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            CheckboxButton(isOn: row.isDone, title: row.title, size: 23, action: onToggle)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.system(size: 16, weight: .medium))
                    .tracking(-0.3)
                    .lineSpacing(4.8)
                    .foregroundStyle(AppColor.textPrimary)

                if let notes = row.notes {
                    Text(notes)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 7) {
                TimeBadge(time: row.time)
                PriorityTag(priority: row.priority)
            }
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color(hex: 0x111113).opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color(hex: 0x111113).opacity(0.04), radius: 1, x: 0, y: 1)
        .shadow(color: Color(hex: 0x111113).opacity(0.035), radius: 9, x: 0, y: 6)
    }
}

private struct PriorityTag: View {
    let priority: TaskPriority

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(priority.indicatorColor)
                .frame(width: 6, height: 6)
            Text(priority.title)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(0.5)
                .textCase(.uppercase)
                .lineLimit(1)
                .foregroundStyle(AppColor.priorityLabel)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TaskListRow(row: TaskRow(id: UUID(), title: "Підготувати презентацію",
                                 notes: nil, time: "09:30", priority: .high, isDone: false))
        TaskListRow(row: TaskRow(id: UUID(), title: "Дзвінок з командою дизайну",
                                 notes: "Обговорити нову сітку інтерфейсу", time: "11:00",
                                 priority: .medium, isDone: false))
    }
    .padding()
    .background(AppColor.background)
}
```

- [ ] **Step 2: Перевести `CompletedTaskRow` на `TaskRow`** — повний новий вміст `ToDo.UDF.MVVM/Components/CompletedTaskRow.swift`:

```swift
//
//  CompletedTaskRow.swift
//  ToDo.UDF.MVVM
//
//  Рядок виконаної задачі: заповнений чекбокс і закреслена назва. Без картки.
//

import SwiftUI

struct CompletedTaskRow: View {
    let row: TaskRow
    var onToggle: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            CheckboxButton(isOn: true, title: row.title, size: 32, action: onToggle)

            Text(row.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)
                .strikethrough(true, color: AppColor.textSecondary)
                .accessibilityHidden(true)

            Spacer(minLength: 0)
        }
        .padding(.leading, 14)
    }
}

#Preview {
    CompletedTaskRow(row: TaskRow(id: UUID(), title: "Оновити залежності",
                                  notes: nil, time: "08:00", priority: .low, isDone: true))
        .padding()
        .background(AppColor.background)
}
```

- [ ] **Step 3: Перевести `TaskListView` на UDF** — повний новий вміст `ToDo.UDF.MVVM/Screens/TaskListView.swift`:

```swift
//
//  TaskListView.swift
//  ToDo.UDF.MVVM
//
//  Екран списку задач. Керується UDF через AnyUdfViewModel:
//  toggle і прогрес приходять із Props, побудованих у ViewModel.
//

import SwiftUI

struct TaskListView: View {
    @State private var viewModel: AnyUdfViewModel<Props, SyncEvent, AsyncEvent>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: AnyUdfViewModel<Props, SyncEvent, AsyncEvent>) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            DotGridBackground()

            VStack(spacing: 0) {
                content
            }

            FloatingActionButton(action: { viewModel.onEvent(.addTapped) })
                .padding(24)
        }
        .sensoryFeedback(.selection, trigger: viewModel.props.completed.count)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                header

                if viewModel.props.active.isEmpty {
                    ContentUnavailableView(
                        "Усе виконано",
                        systemImage: "checkmark.circle",
                        description: Text("Активних задач немає")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    ForEach(viewModel.props.active) { row in
                        TaskListRow(row: row) {
                            viewModel.onEvent(.toggle(id: row.id, reduceMotion: reduceMotion))
                        }
                    }
                }

                if !viewModel.props.completed.isEmpty {
                    SectionLabel(text: "Виконано · \(viewModel.props.completed.count)")
                        .padding(.top, 16)
                        .padding(.leading, 4)

                    ForEach(viewModel.props.completed) { row in
                        CompletedTaskRow(row: row) {
                            viewModel.onEvent(.toggle(id: row.id, reduceMotion: reduceMotion))
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 120)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Сьогодні · 24 черв")

                Text("Задачі")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)

                Text("\(viewModel.props.active.count) активних · \(viewModel.props.completed.count) виконано")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColor.textSecondary)
            }

            Spacer(minLength: 12)

            ProgressRing(progress: viewModel.props.progress)
                .padding(.top, 16)
        }
        .padding(.top, 8)
    }
}

#Preview {
    TaskListView(viewModel: TaskListViewModel().eraseToAnyViewModel())
}
```

- [ ] **Step 4: Зібрати**

Run:
```bash
SIM=93EC3745-46A5-4F90-A4CE-6411DB70C816
xcrun simctl boot "$SIM" 2>/dev/null; xcrun simctl bootstatus "$SIM" -b
xcodebuild build -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination "id=$SIM" 2>&1 | tail -5
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Скріншот-верифікація (тимчасова підміна `ContentView`)**

Тимчасово замінити тіло `ToDo.UDF.MVVM/ContentView.swift` (рядки 15-40, метод `body`) на:
```swift
    var body: some View {
        TaskListView(viewModel: TaskFlowCoordinator().makeTaskListViewModel())
    }
```
Потім зібрати, встановити, запустити й зняти серію скріншотів:
```bash
SIM=93EC3745-46A5-4F90-A4CE-6411DB70C816
SCR=/private/tmp/claude-501/-Users-MAC-Documents-ToDo-UDF-MVVM/df986620-64a1-4401-9089-24764918e262/scratchpad
xcodebuild build -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination "id=$SIM" 2>&1 | tail -3
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "ToDo.UDF.MVVM.app" -path "*Debug-iphonesimulator*" | head -1)
xcrun simctl install "$SIM" "$APP"
BID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")
xcrun simctl launch "$SIM" "$BID"
for i in 1 2 3 4 5; do xcrun simctl io "$SIM" screenshot "$SCR/list_$i.png"; sleep 0.4; done
```
Прочитати `list_5.png` (Read tool) і підтвердити: хедер «Задачі» + дата + лічильники, прогрес-кільце, картки активних, секція «Виконано · 2», вигляд ідентичний поточному. (Опційно: тапнути по чекбоксу через `xcrun simctl io ... ` — необов'язково; анімація toggle покрита логікою у тестах.)

- [ ] **Step 6: Повний прогон тестів**

Run (повний таргет; UI-тести пропускаємо):
```bash
SIM=93EC3745-46A5-4F90-A4CE-6411DB70C816
xcodebuild test -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM \
  -destination "id=$SIM" -only-testing:ToDo.UDF.MVVMTests 2>&1 | tail -25
```
Expected: `TEST SUCCEEDED` — усі unit-тести (Router, Coordinator, UIFactory, TaskCreatedViewModel, TaskListViewModel, TaskFlowCoordinator).

- [ ] **Step 7: Повернути `ContentView` і закомітити**

```bash
git checkout -- ToDo.UDF.MVVM/ContentView.swift
git status --short ToDo.UDF.MVVM/ContentView.swift   # порожньо = реверт ок
git add ToDo.UDF.MVVM/Components/TaskListRow.swift ToDo.UDF.MVVM/Components/CompletedTaskRow.swift ToDo.UDF.MVVM/Screens/TaskListView.swift
git commit -m "feat: drive TaskListView via UDF (TaskRow projection)"
```
**Перевірити:** `git show --stat HEAD` не містить `ContentView.swift`.

---

## Self-Review (виконано автором плану)

- **Покриття спеки:** TaskRow (Task 2) ✓; Props без логіки/без TodoTask (Task 2) ✓; VM-деривація + toggle-у-VM + addTapped→ефект (Task 2) ✓; `CoordinatorEffect.createTaskRequested` + no-op стаб (Task 1) ✓; UIFactory/Coordinator обв'язка (Task 3) ✓; рядки на TaskRow + UDF-view (Task 4) ✓; верифікація скріншотом + реверт ContentView (Task 4) ✓; App root/TaskFlowView не чіпаємо ✓; TodoTask без Equatable ✓; AsyncEvent порожній ✓.
- **Плейсхолдери:** немає — кожен крок із коду містить повний код.
- **Узгодженість типів:** `TaskRow.id: UUID` ↔ `SyncEvent.toggle(id: UUID)` ↔ `row.id`; `Props.active/completed: [TaskRow]`, `.progress: Double` однаково в VM/тестах/view; `makeTaskListViewModel` повертає `AnyUdfViewModel<TaskListView.Props, …SyncEvent, …AsyncEvent>` — той самий тип, що у `@State` view; `taskListViewModel(tasks:onEffect:)` сигнатура однакова в протоколі, реалізації, тестах, координаторі.
- **Порядок/білд:** кейс enum (Task 1) додано до того, як VM його емітує (Task 2); рядки+view міняються разом (Task 4) — білд зелений на межах усіх задач.
