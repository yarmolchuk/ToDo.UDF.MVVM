# NewTaskView → UDF — Design (Sub-project 3/4)

- **Дата:** 2026-06-29
- **Статус:** Draft (очікує рев'ю)
- **Проєкт:** ToDo.UDF.MVVM
- **Тема:** Мігрувати presentational форму `NewTaskView` на UDF (Props/Events + ViewModel + `AnyUdfViewModel`), за еталоном `TaskCreated`/`TaskList` і домашнім патерном форм Ledger (`EditNameView`).

## 1. Контекст і мета

`NewTaskView` зараз presentational: поля живуть у локальному `@State` (`title`, `notes`, `when`, `time: Date`, `priority`, `isPickingTime`), «Зберегти»/«назад» — callbacks, time picker — `.sheet`. Є й мертві `onAdd`/`onToggleTheme` (оголошені, не вживані).

Мета — перевести форму на той самий UDF-патерн, що й попередні екрани, з підключенням `onEffect` через Coordinator/UIFactory.

**Звірка з домашнім патерном (Support/Ledger).** Наш UDF-кор збігається з домашнім практично 1:1: протокол `UdfViewModel`, тріада `Props/SyncEvent/AsyncEvent`, `AnyUdfViewModel`, `UIFactory`, `Coordinator.handle` з `onEffect: { [weak self] in self?.handle($0) }`. Біндинг форм у Ledger (`EditNameView`, `AddTransactionView`) — **інлайн `Binding(get:set:)` + `onEvent`**, рівно те, що тут обрано. Свідома відмінність: у нас немає шару **Domain/UseCase/DTO/Data**, тож save — sync-стаб-ефект, а не `AsyncEvent`+UseCase (персистенція поза скоупом проекту). Валідацію `canSave` переймаємо з `EditNameViewModel`.

## 2. Декомпозиція (це #3 з 4)

1. Навігаційна інфраструктура + success-пілот — **DONE**.
2. `TaskListView` → UDF — **DONE**.
3. `NewTaskView` → UDF (+ onEffect) ← **цей spec**.
4. Повний флоу: список (FAB) → форма → (Зберегти) → success → (До списку) → список.

## 3. Зафіксовані рішення (brainstorming + звірка з Support/Ledger)

- **Інлайн `Binding(get:set:)`** на кожне поле — без `@Bindable`/локального @State; еразер не чіпаємо. (= домашній патерн Ledger.)
- **`isPickingTime` у Props** — sheet біндиться через `Binding`, події `timePickerOpened`/`timePickerClosed`.
- **`canSave` у Props** — рахується у VM (в `onEvent` при `titleChanged`: `title` після трим не порожній), як `EditNameViewModel`. Кнопка «Зберегти» дизейблиться при `!canSave`; `saveTapped` додатково гардиться `canSave`. Обчислення живе у VM (не в Props) — консистентно з рішенням #2 «логіка у VM, Props — дані».
- **save/back — sync-стаб-ефекти:** `saveTapped → onEffect(.saveRequested)`, `backTapped → onEffect(.dismissForm)`; `handle` — no-op у #3. Побудова `TodoTask` + реальний флоу/персистенція — у #4. (Домашній патерн робить save як `AsyncEvent`+UseCase; коли з'явиться шар даних, save еволюціонує в `AsyncEvent`.)
- **Демо-дефолти полів зберігаємо** (як зараз). Мертві `onAdd`/`onToggleTheme` **прибираємо** (YAGNI). `timeString`/`timeFormatter` лишаються у view (display-форматування).
- **App root + `TaskFlowView` не чіпаємо.**

## 4. Компоненти

### `Screens/NewTaskProps.swift` (новий)
```swift
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
`TaskWhen` і `TaskPriority` — enum без асоц. значень, тож `Equatable` неявно (змін не треба).

### `Screens/NewTaskViewModel.swift` (новий)
```swift
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

### `Screens/NewTaskView.swift` (змінений)
Тримає `AnyUdfViewModel`; локальний `@State`/callbacks прибрано; контроли біндяться інлайн.
```swift
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
                ScrollView { formCard.padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 24) }
                Button("Зберегти") { viewModel.onEvent(.saveTapped) }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!viewModel.props.canSave)
                    .padding(.horizontal, 20).padding(.bottom, 12)
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.props.isPickingTime },
            set: { viewModel.onEvent($0 ? .timePickerOpened : .timePickerClosed) }
        )) { timePickerSheet }
    }
    // formCard поля (приклади):
    //   TextField("Назва задачі", text: Binding(get: { viewModel.props.title },
    //                                            set: { viewModel.onEvent(.titleChanged($0)) }))
    //   TextField("Деталі", text: Binding(get: { viewModel.props.notes },
    //                                      set: { viewModel.onEvent(.notesChanged($0)) }), axis: .vertical)
    //   SegmentedControl(options: TaskWhen.allCases,
    //       selection: Binding(get: { viewModel.props.when }, set: { viewModel.onEvent(.whenChanged($0)) }), label: \.title)
    //   Button { viewModel.onEvent(.timePickerOpened) } label: { TimeBadge(time: Self.timeString(viewModel.props.time), ...) }
    //   SegmentedControl(options: TaskPriority.allCases,
    //       selection: Binding(get: { viewModel.props.priority }, set: { viewModel.onEvent(.priorityChanged($0)) }),
    //       label: \.title, dotColor: { $0.indicatorColor })
    // timePickerSheet: DatePicker("Час", selection: Binding(get: { viewModel.props.time },
    //                                                       set: { viewModel.onEvent(.timeChanged($0)) }), ...)
    //                  Button("Готово") { viewModel.onEvent(.timePickerClosed) }
    // timeFormatter/timeString лишаються статичними хелперами view (display-форматування).
}

#Preview {
    NewTaskView(viewModel: NewTaskViewModel().eraseToAnyViewModel())
}
```
Решта розмітки (`formCard`, `field`, `divider`, `timePickerSheet`) переноситься без змін, лише джерело даних → `viewModel.props`, а мутації → `viewModel.onEvent(...)`. Єдиний інший виклик `NewTaskView()` — у його ж `#Preview`.

### `Architecture/Coordinator.swift` (змінений)
```swift
enum CoordinatorEffect: Equatable {
    case finishCreated
    case createTaskRequested
    case saveRequested
    case dismissForm
}
```

### `Screens/UIFactory.swift` (змінений)
Додати в протокол і `DefaultUIFactory`:
```swift
func newTaskViewModel(
    onEffect: @escaping (CoordinatorEffect) -> Void
) -> NewTaskViewModel
```
`DefaultUIFactory` будує `NewTaskViewModel(onEffect: onEffect)`.

### `Screens/TaskFlowCoordinator.swift` (змінений)
```swift
func makeNewTaskViewModel() -> AnyUdfViewModel<NewTaskView.Props, NewTaskView.SyncEvent, NewTaskView.AsyncEvent> {
    factory
        .newTaskViewModel(onEffect: { [weak self] effect in self?.handle(effect) })
        .eraseToAnyViewModel()
}

// handle(_:):
case .saveRequested: break   // стаб: побудова задачі + перехід — у #4
case .dismissForm:   break   // стаб: pop форми — у #4
```

## 5. Дані-флоу
```
поле змінюється → Binding.set → onEvent(.xChanged(v)) → props.x = v (titleChanged ще оновлює canSave) → view ре-рендериться
time picker:  тап badge → .timePickerOpened → props.isPickingTime = true → sheet; «Готово» → .timePickerClosed
Зберегти (active лише при canSave) → .saveTapped → guard canSave → onEffect(.saveRequested) → handle → no-op (стаб; #4 → build task + navigate)
назад → .backTapped → onEffect(.dismissForm) → handle → no-op (стаб; #4 → pop)
```

## 6. Файлова структура
**Нові:** `Screens/NewTaskProps.swift`, `Screens/NewTaskViewModel.swift`, `ToDo.UDF.MVVMTests/NewTaskViewModelTests.swift`.
**Змінені:** `Screens/NewTaskView.swift`, `Architecture/Coordinator.swift`, `Screens/UIFactory.swift`, `Screens/TaskFlowCoordinator.swift`, `UIFactoryTests.swift`, `TaskFlowCoordinatorTests.swift`.
**Без змін:** `Models/TaskWhen.swift`, `Models/TaskSummary.swift` (`TaskPriority`).

## 7. Тестування (Swift Testing)
- **`NewTaskViewModelTests`:**
  - `titleChanged`/`notesChanged`/`whenChanged`/`timeChanged`/`priorityChanged` — кожна оновлює відповідне поле Props.
  - `canSave`: непорожній title → `true`; `titleChanged("")` (або пробіли) → `canSave == false`; назад до непорожнього → `true`.
  - `timePickerOpened`/`timePickerClosed` → `isPickingTime` true/false.
  - `saveTapped` при `canSave == true` → отриманий ефект `.saveRequested`; при `canSave == false` → **жодного** ефекту.
  - `backTapped` → отриманий ефект `.dismissForm`.
- **`UIFactoryTests` (доповнити):** `DefaultUIFactory.newTaskViewModel` повертає VM; його `backTapped` емітує `.dismissForm`.
- **`TaskFlowCoordinatorTests` (доповнити):** `makeNewTaskViewModel` повертає VM з очікуваним початковим станом (напр. `props.canSave == true`); `handle(.saveRequested)` і `handle(.dismissForm)` — no-op (`router.path` не змінюється).

## 8. Ключові рішення / trade-offs
- **Інлайн Binding + canSave у Props — домашній патерн форм** (Ledger `EditNameView`/`EditNameViewModel`). Наш UDF-кор уже збігається з Support/Ledger 1:1; це вирівнювання робить і форму faithful.
- **`canSave` стороване в Props, рахується у VM** — не computed на Props (узгоджено з #2 «Props без логіки»).
- **save/back — sync-ефекти, no-op стаби:** немає шару персистенції/UseCase, тож save поки лише сигналить координатору (як навігаційний `tapBack` у домашньому патерні). Реальна побудова `TodoTask` + флоу — #4; якщо з'явиться персистенція, save стане `AsyncEvent`+UseCase.
- **Свідома відсутність Domain/UseCase/DTO/Data-шару** — проект UI-only зі sample-даними; ми використовуємо коректну підмножину домашнього стека, а не порушуємо UDF.
- **`isPickingTime` у Props** — VM єдине джерело істини (узгоджено з обраним напрямом).
- **`AsyncEvent` порожній** — форма не має async-роботи (поки немає UseCase). Тип лишається для відповідності протоколу.
- **App root / `TaskFlowView` не чіпаємо** — верифікація ізольовано (preview + тимчасова підміна `ContentView`).

## 9. Acceptance / verification
1. `xcodebuild test` — `NewTaskViewModelTests` + доповнені `UIFactoryTests`/`TaskFlowCoordinatorTests` проходять.
2. `xcodebuild build` — `BUILD SUCCEEDED`.
3. **Скріншот:** тимчасово підмінити `ContentView` на `NewTaskView(viewModel: TaskFlowCoordinator().makeNewTaskViewModel())`, зібрати на симуляторі, підтвердити рендер ідентично поточному (NavBar «Нова задача», поля з дефолтами, сегменти «Коли»/«Пріоритет», time badge, кнопка «Зберегти»), за бажанням — відкрити time-picker sheet; потім **повернути** `ContentView`.
4. App root (`App`/`ContentView`) і `TaskFlowView` лишаються незмінними після завершення.
