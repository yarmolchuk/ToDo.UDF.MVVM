# TaskListView → UDF — Design (Sub-project 2/4)

- **Дата:** 2026-06-29
- **Статус:** Draft (очікує рев'ю)
- **Проєкт:** ToDo.UDF.MVVM
- **Тема:** Мігрувати presentational `TaskListView` на UDF (Props/Events + ViewModel + `AnyUdfViewModel`) за еталоном `TaskCreated` (#1) і підключити `onEffect` для FAB через наявні Coordinator/UIFactory.

## 1. Контекст і мета

`TaskListView` зараз presentational: задачі живуть у локальному `@State [TodoTask]`, FAB має `onAdd` callback, а `activeTasks`/`completedTasks`/`progress` — обчислювані у view, `toggle` мутує `@State` з `withAnimation`.

Мета — перевести екран на той самий UDF-патерн, що й `TaskCreated`: незмінні `Props`, події (`SyncEvent`/`AsyncEvent`), `@Observable` ViewModel, ерейзинг через `AnyUdfViewModel`, побудова через `UIFactory`/`Coordinator` з `onEffect`. App root і `TaskFlowView` не чіпаємо — реальні маршрути/перемикання root лишаються на #4.

## 2. Декомпозиція (це #2 з 4)

1. Навігаційна інфраструктура + success-пілот — **DONE**.
2. `TaskListView` → UDF (+ onEffect) ← **цей spec**.
3. `NewTaskView` → UDF (+ onEffect).
4. Повний флоу: список (FAB) → форма → (Зберегти) → success → (До списку) → список.

## 3. Зафіксовані рішення (з brainstorming)

- **FAB → ефект-стаб:** VM емітує `CoordinatorEffect.createTaskRequested`; `TaskFlowCoordinator.handle` обробляє його як no-op у #2. Реальний перехід до `NewTaskView` — у #4. Повна Ledger-обв'язка (factory + coordinator) лишається.
- **Анімація toggle — у VM:** `SyncEvent.toggle(id:reduceMotion:)`; VM обгортає перебудову `Props` у `withAnimation`. Дзеркалить `TaskCreated` (animation appear живе у VM й несе `reduceMotion`).
- **Props — нуль логіки, незалежний від моделі:** тримає `[TaskRow]` (нова view-проекція) + `progress: Double`. Уся деривація (мапінг, спліт, прогрес) — у VM.
- **`TaskRow` — нова незмінна view-проекція рядка** (`Equatable`, `Identifiable`). `TodoTask` лишається мутабельною моделлю / джерелом істини всередині VM; **VM — транслятор** `TodoTask → TaskRow`. Свідомо приймаємо легке дублювання полів сьогодні (YAGNI) заради чистої межі: Props/компоненти рядків не залежать від моделі.
- **App root + `TaskFlowView` не чіпаємо.**

## 4. Компоненти

### `Models/TaskRow.swift` (новий)
Незмінна view-проекція рядка задачі. Її споживають `Props` і компоненти рядків — не `TodoTask`.
```swift
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

### `Screens/TaskListProps.swift` (новий)
```swift
import Foundation

extension TaskListView {
    struct Props: Equatable {
        var active: [TaskRow]
        var completed: [TaskRow]
        var progress: Double

        static let empty = Props(active: [], completed: [], progress: 0)
    }

    enum SyncEvent: Equatable {
        case toggle(id: UUID, reduceMotion: Bool)
        case addTapped
    }

    enum AsyncEvent: Equatable {}   // список не має appear/async-подій
}
```

### `Screens/TaskListViewModel.swift` (новий)
```swift
import SwiftUI

@MainActor
@Observable
final class TaskListViewModel: UdfViewModel {
    typealias Props = TaskListView.Props
    typealias SyncEvent = TaskListView.SyncEvent
    typealias AsyncEvent = TaskListView.AsyncEvent

    private(set) var props: Props

    @ObservationIgnored private var tasks: [TodoTask]      // джерело істини, поза Props
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

### `Screens/TaskListView.swift` (змінений)
Тримає `AnyUdfViewModel`; локальний `@State`/`onAdd`/обчислювані/`toggle` прибрано. `reduceMotion` лишається в environment і передається в подію.
```swift
struct TaskListView: View {
    @State private var viewModel: AnyUdfViewModel<Props, SyncEvent, AsyncEvent>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: AnyUdfViewModel<Props, SyncEvent, AsyncEvent>) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            DotGridBackground()
            VStack(spacing: 0) { content }
            FloatingActionButton(action: { viewModel.onEvent(.addTapped) })
                .padding(24)
        }
        .sensoryFeedback(.selection, trigger: viewModel.props.completed.count)
    }
    // content/header читають viewModel.props.active / .completed / .progress (+ .count)
    // активний рядок:  TaskListRow(row: row)      { viewModel.onEvent(.toggle(id: row.id, reduceMotion: reduceMotion)) }
    // виконаний рядок: CompletedTaskRow(row: row) { viewModel.onEvent(.toggle(id: row.id, reduceMotion: reduceMotion)) }
}

#Preview {
    TaskListView(viewModel: TaskListViewModel().eraseToAnyViewModel())
}
```
Хедерна дата («Сьогодні · 24 черв») лишається статичним написом у view (не стан; динамічна дата — поза скоупом #2). Єдиний інший виклик `TaskListView()` — у його ж `#Preview` (інших споживачів немає), тож зміна init безпечна.

### `Components/TaskListRow.swift`, `Components/CompletedTaskRow.swift` (змінені)
Вхід `let task: TodoTask` → `let row: TaskRow`; тіла без змін (ті самі поля: `title`/`notes`/`time`/`priority`/`isDone`). `#Preview` оновити на літерали `TaskRow`. Рядки тепер залежать від view-стану, а не від моделі.

### `Architecture/Coordinator.swift` (змінений)
```swift
enum CoordinatorEffect: Equatable {
    case finishCreated
    case createTaskRequested
}
```

### `Screens/UIFactory.swift` (змінений)
Додати в протокол і `DefaultUIFactory`:
```swift
func taskListViewModel(
    tasks: [TodoTask],
    onEffect: @escaping (CoordinatorEffect) -> Void
) -> TaskListViewModel
```
`DefaultUIFactory` будує `TaskListViewModel(tasks: tasks, onEffect: onEffect)`.

### `Screens/TaskFlowCoordinator.swift` (змінений)
```swift
func makeTaskListViewModel(
    tasks: [TodoTask] = TodoTask.sampleList
) -> AnyUdfViewModel<TaskListView.Props, TaskListView.SyncEvent, TaskListView.AsyncEvent> {
    factory
        .taskListViewModel(tasks: tasks, onEffect: { [weak self] in self?.handle($0) })
        .eraseToAnyViewModel()
}

// handle(_:):
case .createTaskRequested:
    break   // стаб: реальний перехід до NewTaskView — у #4
```

## 5. Дані-флоу

```
toggle:  тап по рядку → onEvent(.toggle(id, reduceMotion))
         → VM: tasks[i].isDone.toggle(); props = makeProps(...) у withAnimation
         → view ре-рендериться (active/completed пере-спліт, ProgressRing анімується)

add:     FAB → onEvent(.addTapped)
         → VM: onEffect(.createTaskRequested)
         → TaskFlowCoordinator.handle(.createTaskRequested) → no-op (стаб; #4 → push форми)
```

## 6. Файлова структура

**Нові:** `Models/TaskRow.swift`, `Screens/TaskListProps.swift`, `Screens/TaskListViewModel.swift`.
**Змінені:** `Screens/TaskListView.swift`, `Components/TaskListRow.swift`, `Components/CompletedTaskRow.swift`, `Architecture/Coordinator.swift`, `Screens/UIFactory.swift`, `Screens/TaskFlowCoordinator.swift`.
**Тести:** `ToDo.UDF.MVVMTests/TaskListViewModelTests.swift` (новий); доповнити `UIFactoryTests.swift`, `TaskFlowCoordinatorTests.swift`.
**`TodoTask`** лишається без змін — `Equatable` не потрібен (Props більше не містить `TodoTask`; модель живе лише всередині VM і в сигнатурах factory/coordinator).

## 7. Тестування (Swift Testing)

- **`TaskListViewModelTests`:**
  - initial: з `sampleList` `props.active.count`/`completed.count` відповідають спліту; `progress == completed/total`.
  - `toggle` активної задачі → переходить у `completed`, `progress` зростає.
  - `toggle` виконаної задачі → повертається в `active`.
  - `toggle` невідомого `id` → стан незмінний.
  - `addTapped` → отриманий ефект `.createTaskRequested`.
- **`UIFactoryTests` (доповнити):** `DefaultUIFactory.taskListViewModel` повертає VM, що несе задачі (`active.count + completed.count == tasks.count`); `addTapped` побудованого VM емітує `.createTaskRequested`.
- **`TaskFlowCoordinatorTests` (доповнити):** `makeTaskListViewModel` несе задачі; `handle(.createTaskRequested)` — no-op (`router.path` не змінюється).

## 8. Ключові рішення / trade-offs

- **`TaskRow` окремо від `TodoTask`:** Props і компоненти рядків незалежні від моделі; VM — транслятор. Сьогодні майже дублікат полів (YAGNI прийнято свідомо) — окупиться, коли `TodoTask` набуде доменних/персистентних рис (#3/#4) або форма почне його продукувати. `TaskRow` не має `init(TodoTask)` — мапінг лише у VM, щоб не вводити зворотну залежність.
- **Деривація у VM, не в Props:** Props — чисті дані (`[TaskRow]` + `Double`), без фільтрів/обчислень.
- **`toggle` несе `reduceMotion`, анімація у VM:** дзеркалить `TaskCreated`; view лишається декларативним. `ProgressRing` і ре-спліт анімуються «безкоштовно» через єдину перебудову `props` у `withAnimation`.
- **`createTaskRequested` no-op стаб:** маршрут/перемикання root — у #4 (узгоджено з фінальним рев'ю #1: `TaskRoute` enum + `navigationDestination` разом із першим реальним push).
- **`AsyncEvent` порожній:** список не має appear/async-подій (YAGNI). Тип лишається для відповідності протоколу `UdfViewModel`.
- **App root / `TaskFlowView` не чіпаємо:** верифікація — ізольовано (preview + тимчасова підміна `ContentView`).

## 9. Acceptance / verification

1. `xcodebuild test` — нові (`TaskListViewModelTests`) та оновлені (`UIFactoryTests`, `TaskFlowCoordinatorTests`) тести проходять.
2. `xcodebuild build` — `BUILD SUCCEEDED`.
3. **Скріншот:** тимчасово підмінити `ContentView` на `TaskListView(viewModel: TaskFlowCoordinator().makeTaskListViewModel())`, зібрати на симуляторі, підтвердити рендер ідентично поточному (картки активних, прогрес-кільце, секція «Виконано», порожній стан, анімація toggle, tap по FAB → no-op без краху), потім **повернути** `ContentView`.
4. App root (`App`/`ContentView`) і `TaskFlowView` лишаються незмінними після завершення.
