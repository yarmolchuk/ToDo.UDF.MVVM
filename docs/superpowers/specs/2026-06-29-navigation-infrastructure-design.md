# Navigation Infrastructure + Success Pilot — Design (Sub-project 1/4)

- **Дата:** 2026-06-29
- **Статус:** Draft (очікує рев'ю)
- **Проєкт:** ToDo.UDF.MVVM
- **Тема:** Закласти навігаційний шар (Router + Coordinator + UIFactory + FlowView, порт Ledger) і підключити вже-UDF `TaskCreatedView` як end-to-end пілот.

## 1. Контекст і мета

Три екрани (`TaskListView`, `NewTaskView`, `TaskCreatedView`) ізольовані — не підключені до навігації; застосунок показує template `ContentView`. `TaskCreatedView` уже на UDF (`TaskCreatedViewModel`/`AnyUdfViewModel`); решта ще presentational.

Мета цього під-проекту — закласти **навігаційну інфраструктуру** за еталоном Ledger (Router + Coordinator + UIFactory + FlowView) і довести її end-to-end на одному вже-UDF екрані (`TaskCreatedView`). Це фундамент, на який під-проекти 2–4 (міграція списку/форми, повний флоу) спиратимуться.

## 2. Декомпозиція (це #1 з 4)

1. **Навігаційна інфраструктура + success-пілот** ← цей spec.
2. `TaskListView` → UDF (+ onEffect).
3. `NewTaskView` → UDF (+ onEffect).
4. Повний флоу: список (FAB) → форма → (Зберегти) → success → (До списку) → список.

## 3. Зафіксовані рішення (з brainstorming)
- **Повний Ledger-патерн:** VM шле `onEffect: (CoordinatorEffect) -> Void` → Coordinator → Router (не голі callbacks).
- **App root не чіпаємо** в #1: інфраструктуру перевіряємо через `#Preview`/тимчасову підміну `ContentView`. Root перемкнемо в #4.
- `CoordinatorEffect` мінімальний (`.finishCreated`) — розшириться в #2–4.

## 4. Компоненти

### `Architecture/Router.swift`
```swift
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

### `Architecture/Coordinator.swift`
```swift
import Foundation

@MainActor
protocol Coordinator: AnyObject {
    func handle(_ effect: CoordinatorEffect)
}

enum CoordinatorEffect: Equatable {
    case finishCreated
}
```

### `Screens/UIFactory.swift`
```swift
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

### `Screens/TaskFlowCoordinator.swift`
```swift
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
            .taskCreatedViewModel(task: task, onEffect: { [weak self] in self?.handle($0) })
            .eraseToAnyViewModel()
    }
}
```

### `Screens/TaskFlowView.swift`
```swift
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

### Зміна `Screens/TaskCreatedViewModel.swift`
`onContinue: () -> Void` → `onEffect: (CoordinatorEffect) -> Void`:
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
Оновити `TaskCreatedViewModelTests` (`continueTapped` → `onEffect(.finishCreated)`) і `TaskCreatedView.swift` `#Preview` (`TaskCreatedViewModel(task: .sample)` — default `onEffect` лишається `{ _ in }`, тож виклик не змінюється).

## 5. Дані-флоу
```
Кнопка «До списку» → viewModel.onEvent(.continueTapped)
        → VM: onEffect(.finishCreated)
        → TaskFlowCoordinator.handle(.finishCreated)
        → router.popToRoot()  (у #1 — no-op, бо success є root; у #4 поверне до списку)
```

## 6. Файлова структура
**Нові:** `Architecture/Router.swift`, `Architecture/Coordinator.swift`, `Screens/UIFactory.swift`, `Screens/TaskFlowCoordinator.swift`, `Screens/TaskFlowView.swift`.
**Змінені:** `Screens/TaskCreatedViewModel.swift` (onContinue→onEffect), `ToDo.UDF.MVVMTests/TaskCreatedViewModelTests.swift` (оновити тест continueTapped).

## 7. Тестування (Swift Testing)
- `RouterTests`: `push` додає; `pop` прибирає (і не падає на порожньому); `popToRoot` очищає.
- `TaskFlowCoordinatorTests`: після `handle(.finishCreated)` — `router.path.isEmpty`.
- `UIFactoryTests`: `DefaultUIFactory.taskCreatedViewModel` повертає VM; його `continueTapped` викликає переданий `onEffect` з `.finishCreated` (через прапорець у замиканні).
- `TaskCreatedViewModelTests` (оновити): `continueTapped` → отриманий ефект `.finishCreated`.

## 8. Ключові рішення / trade-offs
- **App root не чіпаємо:** інфраструктура verified ізольовано через Preview/підміну. Уникаємо показувати success як справжній root застосунку. У #4 root стане список.
- **`makeTaskCreatedViewModel` passthrough на Coordinator:** дзеркалить Ledger (`coordinator.makeXxxViewModel` ерейзить VM з `onEffect: handle`). View не будує VM сам.
- **`[weak self]` у замиканні onEffect:** Coordinator тримає Router/factory; замикання, передане у VM, не має ретейнити Coordinator сильно (VM живе у View).
- **`CoordinatorEffect` глобальний (не per-feature):** у Ledger ефекти локальні до фічі; тут один todo-флоу, тож один enum, що росте в #2–4.
- **`popToRoot` як stub у #1:** success — root, тож no-op; семантика «повернутись до списку» оживе в #4.

## 9. Acceptance / verification
1. `xcodebuild test` — нові тести (Router, Coordinator, UIFactory) + оновлений VM-тест проходять.
2. `xcodebuild build` — `BUILD SUCCEEDED`.
3. Скріншот: тимчасово підмінити `ContentView` на `TaskFlowView()`, зібрати на симуляторі, підтвердити що success-екран рендериться через Coordinator/UIFactory ідентично, потім повернути `ContentView`.
4. App root (`App`/`ContentView`) лишається незмінним після завершення.
