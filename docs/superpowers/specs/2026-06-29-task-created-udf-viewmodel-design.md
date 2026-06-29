# TaskCreated UDF ViewModel + UDF-інфраструктура — Design

- **Дата:** 2026-06-29
- **Статус:** Draft (очікує рев'ю)
- **Проєкт:** ToDo.UDF.MVVM
- **Тема:** Закласти спільну UDF-інфраструктуру (порт Ledger `Architecture`) і мігрувати `TaskCreatedView` із presentational на UDF-ViewModel як пілот.

## 1. Контекст і мета

`TaskCreatedView` — success-екран («Задачу створено»), реалізований як presentational `View`: приймає `task: TaskSummary` та `onContinue: () -> Void`, тримає локальний `@State appeared` для анімації появи. Жодного шару ViewModel немає.

Мета — ввести **UDF-шар** за еталоном проєкту Ledger (вивчений у цій же сесії) і застосувати його до `TaskCreatedView` першим. Це закладає переюзовну інфраструктуру, на яку потім можна мігрувати `TaskListView` і `NewTaskView`.

## 2. Зафіксовані рішення (з brainstorming)

1. **UDF-стиль:** повний Ledger-патерн — протокол `UdfViewModel` (`Props`/`SyncEvent`/`AsyncEvent`) + type-eraser `AnyUdfViewModel`.
2. **Обсяг:** спільна UDF-інфраструктура + міграція `TaskCreatedView` (пілот). Список і форма — пізніше.
3. **Без Coordinator/UIFactory:** ToDo — простий presentational-проєкт без навігаційного шару; VM створюється на call-site. Композиційний шар — окреме майбутнє рішення.

## 3. Архітектура — UDF-інфраструктура

Нова тека `ToDo.UDF.MVVM/Architecture/` (порт мінімального ядра Ledger `Infrastructure/Architecture`):

### `UdfViewModel.swift`
```swift
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
- `Props` — незмінний (з погляду View) знімок стану.
- `SyncEvent` — синхронні дії користувача (обробляються на MainActor).
- `AsyncEvent` — асинхронна робота.
- `MockUdfViewModel` — для прев'ю/тестів.

### `AnyUdfViewModel.swift`
```swift
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
**Чому Observation працює крізь обгортку:** `propsGetter` захоплює `@Observable` `base`. Коли View читає `viewModel.props`, доступ доходить до `base.props`, який Observation реєструє; мутація `base.props` інвалідує View. `AnyUdfViewModel` — прозорий forwarder (точно як у Ledger).

## 4. TaskCreated — UDF-зріз

### `TaskCreatedProps.swift`
```swift
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

### `TaskCreatedViewModel.swift`
```swift
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

### `TaskCreatedView.swift` (зміни)
- Замінити `let task` / `var onContinue` на `@State private var viewModel: AnyUdfViewModel<Props, SyncEvent, AsyncEvent>` + `init(viewModel:)`.
- Читати `viewModel.props.task` і `viewModel.props.appeared` (прибрати локальний `@State appeared` та `|| reduceMotion` з модифікаторів — станом керує VM).
- Кнопка «До списку»: `viewModel.onEvent(.continueTapped)`.
- Тригер появи: `.task { await viewModel.onAsync(.appear(reduceMotion: reduceMotion)) }` (замість `.onAppear { withAnimation … }`).
- `@Environment(\.accessibilityReduceMotion) private var reduceMotion` лишається у View й передається у VM через `AsyncEvent` — VM не залежить від SwiftUI environment.
- `#Preview { TaskCreatedView(viewModel: TaskCreatedViewModel(task: .sample).eraseToAnyViewModel()) }`.

### Дрібна правка моделі
`TaskSummary` → додати `: Equatable` (потрібно для `Props: Equatable`; `TaskPriority` уже Equatable автоматично як enum без associated values).

## 5. Дані-флоу (UDF-цикл)
```
View.task → viewModel.onAsync(.appear(reduceMotion:))
        → VM: withAnimation { props.appeared = true }
        → @Observable інвалідує View → анімована поява

Кнопка → viewModel.onEvent(.continueTapped)
        → VM: onContinue()  (навігаційний колбек, інжектований на call-site)
```

## 6. Файлова структура
**Нові:**
- `Architecture/UdfViewModel.swift`
- `Architecture/AnyUdfViewModel.swift`
- `Screens/TaskCreatedProps.swift`
- `Screens/TaskCreatedViewModel.swift`

**Змінені:**
- `Screens/TaskCreatedView.swift` (приймає `AnyUdfViewModel`)
- `Models/TaskSummary.swift` (`+ Equatable`)

`SuccessBadge` (private у `TaskCreatedView.swift`) лишається без змін.

## 7. Тестування
VM тепер ізольовано тестабельний (чого не було в presentational View):
- `continueTapped` викликає інжектований `onContinue` (перевірити через прапорець у замиканні).
- `appear(reduceMotion:)` встановлює `props.appeared == true`.
Unit-тести VM — опційно в цьому кроці (запропонувати у плані).

## 8. Ключові рішення / trade-offs
- **`appeared` у `Props`, а не `@State` у View:** чистий UDF — увесь стан у VM. Ціна — анімація появи стає частиною стану.
- **`reduceMotion` через `AsyncEvent.appear(reduceMotion:)`:** environment живе у View; VM лишається незалежним від SwiftUI environment (його можна тестувати без UI).
- **Без Coordinator/UIFactory:** YAGNI для presentational-проєкту; VM створюється на call-site. Якщо проєкт зростатиме до Ledger-композиції — це наступний крок.
- **Інфраструктура мінімальна:** лише `UdfViewModel` + `AnyUdfViewModel` (+ `Mock`). Router/Coordinator з Ledger не портуються.

## 9. Верифікація / acceptance
1. `xcodebuild … build` — `BUILD SUCCEEDED`.
2. Скріншот на симуляторі: success-екран виглядає ідентично попередньому (анімація появи працює, кнопка «До списку» спрацьовує).
3. SourceKit/компіляція без помилок; `TaskCreatedView` не тримає бізнес-стану поза `viewModel`.
