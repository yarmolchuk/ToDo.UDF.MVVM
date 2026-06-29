# NewTaskView → UDF Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Перевести форму `NewTaskView` з presentational-`@State` на UDF (Props/Events + `@Observable` ViewModel + `AnyUdfViewModel`), з `canSave`-валідацією та `onEffect` для save/back.

**Architecture:** Дзеркало `TaskCreated`/`TaskList` і домашнього патерну форм Ledger. VM тримає всі поля форми у Props; контроли біндяться інлайн `Binding(get:{props.x}, set:{onEvent(.xChanged($0))})`. `canSave` рахується у VM (title не порожній) і дизейблить «Зберегти». save/back — sync-стаб-ефекти (`.saveRequested`/`.dismissForm`), no-op до #4.

**Tech Stack:** SwiftUI (iOS 26.2), Observation (`@Observable`, `@ObservationIgnored`), Swift Testing.

## Global Constraints

- Модуль тестів: `@testable import ToDo_UDF_MVVM`; Swift Testing (`import Testing`, `@Test`, `#expect`, `@MainActor` suite). Тести з `Date`/`UUID` додають `import Foundation`.
- UDF: `@MainActor @Observable final class … : UdfViewModel`; `private(set) var props`; `@ObservationIgnored private let onEffect`; ерейзинг через `eraseToAnyViewModel()`.
- `Props: Equatable` — без логіки; валідація/деривація (`canSave`) живе у VM.
- Біндинг форм — **інлайн `Binding(get:set:)`**, без `@Bindable`/локального @State; еразер не чіпаємо.
- `[weak self]` у замиканні `onEffect`.
- Xcode synchronized groups (objectVersion 77) — **НЕ редагувати `project.pbxproj`**.
- Мінімум коментарів. **App root (`App`/`ContentView`) і `TaskFlowView` НЕ чіпати** (тимчасова підміна `ContentView` у Task 4 — лише для скріншоту, з ревертом).
- Симулятор iPhone 17, id `93EC3745-46A5-4F90-A4CE-6411DB70C816`; перед `xcodebuild` — boot + bootstatus. Прогон тестів — лише `-only-testing:ToDo.UDF.MVVMTests` (UI-тести template зависають).
- SourceKit може хибно підсвічувати cross-file scope до першого білда — довіряти білду.

**Команда тестів:**
```bash
SIM=93EC3745-46A5-4F90-A4CE-6411DB70C816
xcrun simctl boot "$SIM" 2>/dev/null; xcrun simctl bootstatus "$SIM" -b
xcodebuild test -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM \
  -destination "id=$SIM" -only-testing:ToDo.UDF.MVVMTests 2>&1 | tail -25
```

---

## File Structure

**Нові:** `Screens/NewTaskProps.swift` (Props/Events), `Screens/NewTaskViewModel.swift` (VM), `ToDo.UDF.MVVMTests/NewTaskViewModelTests.swift`.
**Змінені:** `Architecture/Coordinator.swift` (+2 ефекти), `Screens/TaskFlowCoordinator.swift` (handle-стаби + `makeNewTaskViewModel`), `Screens/UIFactory.swift` (+`newTaskViewModel`), `Screens/NewTaskView.swift` (UDF-driven), `UIFactoryTests.swift`, `TaskFlowCoordinatorTests.swift`.
**Без змін:** `Models/TaskWhen.swift`, `Models/TaskSummary.swift` (`TaskPriority`).

---

## Task 1: CoordinatorEffect += saveRequested/dismissForm + handle-стаби

**Files:**
- Modify: `ToDo.UDF.MVVM/Architecture/Coordinator.swift:13-16`
- Modify: `ToDo.UDF.MVVM/Screens/TaskFlowCoordinator.swift:19-26`
- Test: `ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift`

**Interfaces:**
- Consumes: наявний `TaskFlowCoordinator` (`router`, `handle(_:)`).
- Produces: `CoordinatorEffect.saveRequested`, `CoordinatorEffect.dismissForm`; `handle` обробляє обидва як no-op (`router.path` не змінюється). Споживають Task 2 (VM емітує) і Task 3.

- [ ] **Step 1: Дописати падаючі тести** у `ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift` (перед закриваючою `}` структури):

```swift
    @Test func saveRequestedIsNoOp() {
        let coordinator = TaskFlowCoordinator()
        coordinator.handle(.saveRequested)
        #expect(coordinator.router.path.isEmpty)
    }

    @Test func dismissFormIsNoOp() {
        let coordinator = TaskFlowCoordinator()
        coordinator.handle(.dismissForm)
        #expect(coordinator.router.path.isEmpty)
    }
```

- [ ] **Step 2: Переконатися, що падає (компіляція)**

Run: `-only-testing:ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests`
Expected: FAIL — `type 'CoordinatorEffect' has no member 'saveRequested'`.

- [ ] **Step 3: Додати кейси** — повний новий вміст `ToDo.UDF.MVVM/Architecture/Coordinator.swift`:

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
    case saveRequested
    case dismissForm
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
        case .saveRequested:
            break
        case .dismissForm:
            break
        }
    }
```

- [ ] **Step 5: Переконатися, що проходить**

Run: `-only-testing:ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests`
Expected: PASS — наявні + `saveRequestedIsNoOp`, `dismissFormIsNoOp`.

- [ ] **Step 6: Коміт**

```bash
git add ToDo.UDF.MVVM/Architecture/Coordinator.swift ToDo.UDF.MVVM/Screens/TaskFlowCoordinator.swift ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift
git commit -m "feat: add CoordinatorEffect.saveRequested/.dismissForm (no-op stubs)"
```

---

## Task 2: NewTaskProps + NewTaskViewModel

**Files:**
- Create: `ToDo.UDF.MVVM/Screens/NewTaskProps.swift`
- Create: `ToDo.UDF.MVVM/Screens/NewTaskViewModel.swift`
- Test: `ToDo.UDF.MVVMTests/NewTaskViewModelTests.swift`

**Interfaces:**
- Consumes: `CoordinatorEffect.saveRequested`/`.dismissForm` (Task 1); `TaskWhen` (`.today`/`.tomorrow`/`.later`, `CaseIterable`, `.title`); `TaskPriority` (`.low`/`.medium`/`.high`, `CaseIterable`, `.title`, `.indicatorColor`); `UdfViewModel`, `eraseToAnyViewModel()`.
- Produces:
  - `extension NewTaskView`: `struct Props: Equatable { var title: String; var notes: String; var when: TaskWhen; var time: Date; var priority: TaskPriority; var isPickingTime: Bool; var canSave: Bool }`; `enum SyncEvent: Equatable { titleChanged(String); notesChanged(String); whenChanged(TaskWhen); timeChanged(Date); priorityChanged(TaskPriority); timePickerOpened; timePickerClosed; saveTapped; backTapped }`; `enum AsyncEvent: Equatable {}`.
  - `final class NewTaskViewModel: UdfViewModel` з `init(onEffect: @escaping (CoordinatorEffect) -> Void = { _ in })`, `private(set) var props: NewTaskView.Props`.

- [ ] **Step 1: Написати падаючі тести** — створити `ToDo.UDF.MVVMTests/NewTaskViewModelTests.swift`:

```swift
import Testing
import Foundation
@testable import ToDo_UDF_MVVM

@MainActor
struct NewTaskViewModelTests {
    @Test func fieldEventsUpdateProps() {
        let vm = NewTaskViewModel()
        vm.onEvent(.titleChanged("Нова"))
        vm.onEvent(.notesChanged("деталі"))
        vm.onEvent(.whenChanged(.tomorrow))
        vm.onEvent(.priorityChanged(.high))
        #expect(vm.props.title == "Нова")
        #expect(vm.props.notes == "деталі")
        #expect(vm.props.when == .tomorrow)
        #expect(vm.props.priority == .high)
    }

    @Test func timeChangedUpdatesProps() {
        let vm = NewTaskViewModel()
        let newTime = Date(timeIntervalSince1970: 1_000_000)
        vm.onEvent(.timeChanged(newTime))
        #expect(vm.props.time == newTime)
    }

    @Test func emptyTitleDisablesCanSave() {
        let vm = NewTaskViewModel()
        #expect(vm.props.canSave)               // демо-title непорожній
        vm.onEvent(.titleChanged("   "))
        #expect(!vm.props.canSave)
        vm.onEvent(.titleChanged("Назва"))
        #expect(vm.props.canSave)
    }

    @Test func timePickerEventsToggleFlag() {
        let vm = NewTaskViewModel()
        vm.onEvent(.timePickerOpened)
        #expect(vm.props.isPickingTime)
        vm.onEvent(.timePickerClosed)
        #expect(!vm.props.isPickingTime)
    }

    @Test func saveTappedEmitsWhenCanSave() {
        var received: CoordinatorEffect?
        let vm = NewTaskViewModel(onEffect: { received = $0 })
        vm.onEvent(.saveTapped)
        #expect(received == .saveRequested)
    }

    @Test func saveTappedDoesNotEmitWhenInvalid() {
        var received: CoordinatorEffect?
        let vm = NewTaskViewModel(onEffect: { received = $0 })
        vm.onEvent(.titleChanged(""))
        vm.onEvent(.saveTapped)
        #expect(received == nil)
    }

    @Test func backTappedEmitsDismiss() {
        var received: CoordinatorEffect?
        let vm = NewTaskViewModel(onEffect: { received = $0 })
        vm.onEvent(.backTapped)
        #expect(received == .dismissForm)
    }
}
```

- [ ] **Step 2: Переконатися, що падає**

Run: `-only-testing:ToDo.UDF.MVVMTests/NewTaskViewModelTests`
Expected: FAIL — `cannot find 'NewTaskViewModel' in scope`.

- [ ] **Step 3: Створити `ToDo.UDF.MVVM/Screens/NewTaskProps.swift`**

```swift
//
//  NewTaskProps.swift
//  ToDo.UDF.MVVM
//
//  UDF-стан і події форми створення задачі.
//

import Foundation

extension NewTaskView {
    struct Props: Equatable {
        var title: String
        var notes: String
        var when: TaskWhen
        var time: Date
        var priority: TaskPriority
        var isPickingTime: Bool
        var canSave: Bool
    }

    enum SyncEvent: Equatable {
        case titleChanged(String)
        case notesChanged(String)
        case whenChanged(TaskWhen)
        case timeChanged(Date)
        case priorityChanged(TaskPriority)
        case timePickerOpened
        case timePickerClosed
        case saveTapped
        case backTapped
    }

    enum AsyncEvent: Equatable {}
}
```

- [ ] **Step 4: Створити `ToDo.UDF.MVVM/Screens/NewTaskViewModel.swift`**

```swift
//
//  NewTaskViewModel.swift
//  ToDo.UDF.MVVM
//
//  UDF-ViewModel форми створення задачі.
//

import SwiftUI

@MainActor
@Observable
final class NewTaskViewModel: UdfViewModel {
    typealias Props = NewTaskView.Props
    typealias SyncEvent = NewTaskView.SyncEvent
    typealias AsyncEvent = NewTaskView.AsyncEvent

    private(set) var props: Props

    @ObservationIgnored private let onEffect: (CoordinatorEffect) -> Void

    init(onEffect: @escaping (CoordinatorEffect) -> Void = { _ in }) {
        self.onEffect = onEffect
        let title = "Зустріч із інвестором"
        self.props = Props(
            title: title,
            notes: "Підготувати дек та ключові метрики",
            when: .today,
            time: Self.defaultTime,
            priority: .medium,
            isPickingTime: false,
            canSave: Self.canSave(title: title)
        )
    }

    func onEvent(_ event: SyncEvent) {
        switch event {
        case .titleChanged(let v):
            props.title = v
            props.canSave = Self.canSave(title: v)
        case .notesChanged(let v):    props.notes = v
        case .whenChanged(let v):     props.when = v
        case .timeChanged(let v):     props.time = v
        case .priorityChanged(let v): props.priority = v
        case .timePickerOpened:       props.isPickingTime = true
        case .timePickerClosed:       props.isPickingTime = false
        case .saveTapped:
            guard props.canSave else { return }
            onEffect(.saveRequested)
        case .backTapped:
            onEffect(.dismissForm)
        }
    }

    func onAsyncEvent(_ event: AsyncEvent) async {}

    private static func canSave(title: String) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static var defaultTime: Date {
        Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: Date()) ?? Date()
    }
}
```

- [ ] **Step 5: Переконатися, що проходить**

Run: `-only-testing:ToDo.UDF.MVVMTests/NewTaskViewModelTests`
Expected: PASS — усі 7 тестів.

- [ ] **Step 6: Коміт**

```bash
git add ToDo.UDF.MVVM/Screens/NewTaskProps.swift ToDo.UDF.MVVM/Screens/NewTaskViewModel.swift ToDo.UDF.MVVMTests/NewTaskViewModelTests.swift
git commit -m "feat: add NewTaskViewModel (UDF form state + canSave)"
```

---

## Task 3: UIFactory + TaskFlowCoordinator обв'язка

**Files:**
- Modify: `ToDo.UDF.MVVM/Screens/UIFactory.swift`
- Modify: `ToDo.UDF.MVVM/Screens/TaskFlowCoordinator.swift`
- Test: `ToDo.UDF.MVVMTests/UIFactoryTests.swift`, `ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift`

**Interfaces:**
- Consumes: `NewTaskViewModel(onEffect:)`, `NewTaskView.Props/SyncEvent/AsyncEvent` (Task 2); `CoordinatorEffect.dismissForm` (Task 1); `eraseToAnyViewModel()`.
- Produces:
  - `UIFactory.newTaskViewModel(onEffect: @escaping (CoordinatorEffect) -> Void) -> NewTaskViewModel`.
  - `TaskFlowCoordinator.makeNewTaskViewModel() -> AnyUdfViewModel<NewTaskView.Props, NewTaskView.SyncEvent, NewTaskView.AsyncEvent>`.

- [ ] **Step 1: Дописати падаючі тести.** У `ToDo.UDF.MVVMTests/UIFactoryTests.swift` (перед закриваючою `}`):

```swift
    @Test func buildsNewTaskViewModel() {
        let factory = DefaultUIFactory()
        let vm = factory.newTaskViewModel(onEffect: { _ in })
        #expect(vm.props.canSave)
    }

    @Test func builtNewTaskViewModelEmitsEffect() {
        var received: CoordinatorEffect?
        let factory = DefaultUIFactory()
        let vm = factory.newTaskViewModel(onEffect: { received = $0 })
        vm.onEvent(.backTapped)
        #expect(received == .dismissForm)
    }
```

У `ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift` (перед закриваючою `}`):

```swift
    @Test func makesNewTaskViewModel() {
        let coordinator = TaskFlowCoordinator()
        let vm = coordinator.makeNewTaskViewModel()
        #expect(vm.props.canSave)
    }
```

- [ ] **Step 2: Переконатися, що падає**

Run: `-only-testing:ToDo.UDF.MVVMTests/UIFactoryTests -only-testing:ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests`
Expected: FAIL — `value of type 'DefaultUIFactory' has no member 'newTaskViewModel'`.

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

    func newTaskViewModel(
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> NewTaskViewModel
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

    func newTaskViewModel(
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> NewTaskViewModel {
        NewTaskViewModel(onEffect: onEffect)
    }
}
```

- [ ] **Step 4: Додати `makeNewTaskViewModel`** у `ToDo.UDF.MVVM/Screens/TaskFlowCoordinator.swift` (після `makeTaskListViewModel`, перед закриваючою `}` класу):

```swift
    func makeNewTaskViewModel() -> AnyUdfViewModel<NewTaskView.Props, NewTaskView.SyncEvent, NewTaskView.AsyncEvent> {
        factory
            .newTaskViewModel(onEffect: { [weak self] effect in self?.handle(effect) })
            .eraseToAnyViewModel()
    }
```

- [ ] **Step 5: Переконатися, що проходить**

Run: `-only-testing:ToDo.UDF.MVVMTests/UIFactoryTests -only-testing:ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests`
Expected: PASS — нові 3 кейси + наявні.

- [ ] **Step 6: Коміт**

```bash
git add ToDo.UDF.MVVM/Screens/UIFactory.swift ToDo.UDF.MVVM/Screens/TaskFlowCoordinator.swift ToDo.UDF.MVVMTests/UIFactoryTests.swift ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift
git commit -m "feat: factory & coordinator build NewTaskViewModel"
```

---

## Task 4: Міграція NewTaskView на UDF + верифікація

**Files:**
- Modify: `ToDo.UDF.MVVM/Screens/NewTaskView.swift`
- Verify-only (revert!): `ToDo.UDF.MVVM/ContentView.swift`

**Interfaces:**
- Consumes: `NewTaskView.Props/SyncEvent/AsyncEvent`, `NewTaskViewModel`, `eraseToAnyViewModel()` (Task 2); `TaskFlowCoordinator.makeNewTaskViewModel()` (Task 3); `AnyUdfViewModel`; наявні компоненти `DotGridBackground`/`NavBar`/`PrimaryButtonStyle`/`SegmentedControl`/`TimeBadge`/`SectionLabel`/`AppColor`.
- Produces: UDF-driven `NewTaskView(viewModel:)`.

Без нового unit-тесту: логіка покрита Task 1–3; екран перевіряємо білдом + скріншотом + повним прогоном (як #1 Task 5 / #2 Task 4).

- [ ] **Step 1: Перевести `NewTaskView` на UDF** — повний новий вміст `ToDo.UDF.MVVM/Screens/NewTaskView.swift`:

```swift
//
//  NewTaskView.swift
//  ToDo.UDF.MVVM
//
//  Форма створення задачі. Керується UDF через AnyUdfViewModel:
//  поля біндяться інлайн (get з props, set через onEvent).
//

import SwiftUI

struct NewTaskView: View {
    @State private var viewModel: AnyUdfViewModel<Props, SyncEvent, AsyncEvent>

    init(viewModel: AnyUdfViewModel<Props, SyncEvent, AsyncEvent>) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            DotGridBackground()

            VStack(spacing: 0) {
                NavBar(title: "Нова задача", onBack: { viewModel.onEvent(.backTapped) })
                    .padding(.top, 4)

                ScrollView {
                    formCard
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                }

                Button("Зберегти") { viewModel.onEvent(.saveTapped) }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!viewModel.props.canSave)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.props.isPickingTime },
            set: { viewModel.onEvent($0 ? .timePickerOpened : .timePickerClosed) }
        )) {
            timePickerSheet
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            field(label: "Назва") {
                TextField("Назва задачі", text: Binding(
                    get: { viewModel.props.title },
                    set: { viewModel.onEvent(.titleChanged($0)) }
                ))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)
            }

            divider

            field(label: "Нотатки") {
                TextField("Деталі", text: Binding(
                    get: { viewModel.props.notes },
                    set: { viewModel.onEvent(.notesChanged($0)) }
                ), axis: .vertical)
                .font(.system(size: 18))
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1...6)
            }

            divider

            field(label: "Коли") {
                SegmentedControl(
                    options: TaskWhen.allCases,
                    selection: Binding(
                        get: { viewModel.props.when },
                        set: { viewModel.onEvent(.whenChanged($0)) }
                    ),
                    label: \.title
                )
                .accessibilityLabel("Коли")
            }

            field(label: "Час") {
                Button {
                    viewModel.onEvent(.timePickerOpened)
                } label: {
                    TimeBadge(
                        time: Self.timeString(viewModel.props.time),
                        fontSize: 16,
                        horizontalPadding: 14,
                        verticalPadding: 10
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Час")
                .accessibilityValue(Self.timeString(viewModel.props.time))
            }

            divider

            field(label: "Пріоритет") {
                SegmentedControl(
                    options: TaskPriority.allCases,
                    selection: Binding(
                        get: { viewModel.props.priority },
                        set: { viewModel.onEvent(.priorityChanged($0)) }
                    ),
                    label: \.title,
                    dotColor: { $0.indicatorColor }
                )
                .accessibilityLabel("Пріоритет")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppColor.card)
        )
        .shadow(color: AppColor.ink.opacity(0.05), radius: 18, x: 0, y: 8)
    }

    private func field<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: label)
            content()
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(AppColor.stroke.opacity(0.5))
            .frame(height: 1)
    }

    private var timePickerSheet: some View {
        VStack(spacing: 0) {
            DatePicker("Час", selection: Binding(
                get: { viewModel.props.time },
                set: { viewModel.onEvent(.timeChanged($0)) }
            ), displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()

            Button("Готово") { viewModel.onEvent(.timePickerClosed) }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .padding(.top, 24)
        .presentationDetents([.height(320)])
        .presentationBackground(AppColor.background)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static func timeString(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
}

#Preview {
    NewTaskView(viewModel: NewTaskViewModel().eraseToAnyViewModel())
}
```
(Прибрано: локальний `@State`, callbacks `onSave`/`onBack`/`onAdd`/`onToggleTheme`, `defaultTime` — час тепер сидиться у VM.)

- [ ] **Step 2: Зібрати**

Run:
```bash
SIM=93EC3745-46A5-4F90-A4CE-6411DB70C816
xcrun simctl boot "$SIM" 2>/dev/null; xcrun simctl bootstatus "$SIM" -b
xcodebuild build -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination "id=$SIM" 2>&1 | tail -5
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Скріншот-верифікація (тимчасова підміна `ContentView`)**

Тимчасово замінити тіло `ToDo.UDF.MVVM/ContentView.swift` (метод `body`) на:
```swift
    var body: some View {
        NewTaskView(viewModel: TaskFlowCoordinator().makeNewTaskViewModel())
    }
```
Зібрати, встановити, запустити, зняти серію скріншотів у scratchpad:
```bash
SIM=93EC3745-46A5-4F90-A4CE-6411DB70C816
SCR=/private/tmp/claude-501/-Users-MAC-Documents-ToDo-UDF-MVVM/df986620-64a1-4401-9089-24764918e262/scratchpad
xcodebuild build -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination "id=$SIM" 2>&1 | tail -3
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "ToDo.UDF.MVVM.app" -path "*Debug-iphonesimulator*" | head -1)
xcrun simctl install "$SIM" "$APP"
BID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")
xcrun simctl launch "$SIM" "$BID"
for i in 1 2 3 4 5; do xcrun simctl io "$SIM" screenshot "$SCR/form_$i.png"; sleep 0.4; done
```
Прочитати `form_5.png` (Read tool) і підтвердити: NavBar «Нова задача», поле «Назва» з дефолтом, «Нотатки», сегменти «Коли» (Сьогодні/Завтра/Пізніше), time badge «09:30», сегменти «Пріоритет», кнопка «Зберегти». Вигляд ідентичний поточному.

- [ ] **Step 4: Повний прогон тестів**

Run:
```bash
SIM=93EC3745-46A5-4F90-A4CE-6411DB70C816
xcodebuild test -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM \
  -destination "id=$SIM" -only-testing:ToDo.UDF.MVVMTests 2>&1 | tail -25
```
Expected: `TEST SUCCEEDED` — усі unit-тести (Router, Coordinator, UIFactory, TaskCreatedViewModel, TaskListViewModel, NewTaskViewModel, TaskFlowCoordinator).

- [ ] **Step 5: Повернути `ContentView` і закомітити**

```bash
git checkout -- ToDo.UDF.MVVM/ContentView.swift
git status --short ToDo.UDF.MVVM/ContentView.swift   # порожньо = реверт ок
git add ToDo.UDF.MVVM/Screens/NewTaskView.swift
git commit -m "feat: drive NewTaskView via UDF (inline bindings + canSave)"
```
**Перевірити:** `git show --stat HEAD` містить лише `NewTaskView.swift` (без `ContentView.swift`).

---

## Self-Review (виконано автором плану)

- **Покриття спеки:** Props (7 полів вкл. canSave) + Events (9) + порожній AsyncEvent (Task 2) ✓; VM-мутації + canSave-у-VM + save-guard + save/back-ефекти (Task 2) ✓; `CoordinatorEffect.saveRequested/.dismissForm` + no-op стаби (Task 1) ✓; UIFactory/Coordinator обв'язка (Task 3) ✓; інлайн-біндинги + кнопка `.disabled(!canSave)` + sheet через binding + прибрані мертві callbacks (Task 4) ✓; верифікація скріншотом + реверт ContentView (Task 4) ✓; App root/TaskFlowView не чіпаємо ✓; `timeString` у view ✓; демо-дефолти збережено ✓.
- **Плейсхолдери:** немає — кожен крок із коду містить повний код.
- **Узгодженість типів:** `SyncEvent` кейси ↔ інлайн-біндинги у view ↔ `onEvent` switch у VM збігаються (titleChanged/notesChanged/whenChanged/timeChanged/priorityChanged/timePickerOpened/timePickerClosed/saveTapped/backTapped); `Props` поля однакові у VM init / view-біндингах / тестах; `newTaskViewModel(onEffect:)` сигнатура однакова в протоколі/реалізації/тестах/координаторі; `makeNewTaskViewModel()` повертає `AnyUdfViewModel<NewTaskView.Props, …SyncEvent, …AsyncEvent>` — той самий тип, що у `@State` view.
- **Порядок/білд:** кейси enum (Task 1) додано до того, як VM їх емітує (Task 2); view мігрує останнім (Task 4) — білд зелений на межах усіх задач (Props-extension компілюється проти наявного presentational-view до Task 4).
