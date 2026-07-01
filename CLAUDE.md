# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

ToDo.UDF.MVVM is a SwiftUI iOS app (a to-do list) that serves as a reference implementation of **MVVM + Coordinator + Clean Architecture** with **UDF (Unidirectional Data Flow)** at the presentation layer. One app target (`ToDo.UDF.MVVM`) + 2 test targets (`ToDo.UDF.MVVMTests`, `ToDo.UDF.MVVMUITests`), one scheme, no SPM/CocoaPods/Tuist dependencies, Swift 6 in strict concurrency mode.

The rationale behind past decisions (why things are the way they are, which alternatives were rejected) lives in `docs/superpowers/specs/*-design.md` (approved designs) and `docs/superpowers/plans/*.md` (step-by-step implementation plans with verification commands). Before any non-trivial architectural change, check the most recent relevant spec in that folder.

## Commands

One scheme (`ToDo.UDF.MVVM`), Debug/Release configurations. The commands below assume you're running from the repository root.

### Build
```
xcodebuild build -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination 'generic/platform=iOS Simulator'
```

### Tests
Unit tests (Swift Testing) live in the `ToDo.UDF.MVVMTests` target. The `ToDo.UDF.MVVMUITests` target is an untouched XCTest template; don't run it alongside the unit tests (it hangs on the simulator) — always scope the run with `-only-testing:ToDo.UDF.MVVMTests`.

Full run (the plans under `docs/superpowers/` record a serial run on this simulator specifically — `-parallel-testing-enabled NO`):
```
xcodebuild test -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.3.1' \
  -only-testing:ToDo.UDF.MVVMTests -parallel-testing-enabled NO
```

Single suite — append `/<SuiteName>`:
```
-only-testing:ToDo.UDF.MVVMTests/TaskListViewModelTests
```

Single test — append `/<testFuncName>` too:
```
-only-testing:ToDo.UDF.MVVMTests/TaskListViewModelTests/loadSplitsTasks
```

If `xcodebuild` can't find a destination (simulator not yet created / `Unable to find a destination`): `xcrun simctl list devices available` to find a UDID, then `xcrun simctl boot <UDID> 2>/dev/null; xcrun simctl bootstatus <UDID> -b` before running — the simulator sometimes powers down between shell invocations.

**Module name gotcha:** test files use `@testable import ToDo_UDF_MVVM` — underscores, not dots, even though the scheme/target are named `ToDo.UDF.MVVM`.

### Manual run on simulator (UI check / screenshots)
```
xcrun simctl boot <UDID> 2>/dev/null; xcrun simctl bootstatus <UDID> -b
xcodebuild build -project ToDo.UDF.MVVM.xcodeproj -scheme ToDo.UDF.MVVM -destination "id=<UDID>"
xcrun simctl install <UDID> <path-to-.app-in-DerivedData>
xcrun simctl launch <UDID> com.yarmolchuk.ToDo-UDF-MVVM
xcrun simctl io <UDID> screenshot out.png
```

## Architecture

### Layers and dependency direction
Layers are folders, not separate SPM modules (one app target). Dependencies point inward, toward Domain:
```
UI/ (Presentation, @MainActor)   ─┐
                                   ├─→  Domain/ (Entities, Repository protocols, UseCases — nonisolated, Sendable)
Data/ (SwiftData + in-memory)    ─┘
```

The **Dependency Rule** applies: code in the inner circle (Domain) must not reference any type or name from the outer circles (Data, UI) — `Domain/` imports neither `SwiftUI` nor `SwiftData`. `Data/` and `UI/` instead depend on Domain through its protocols (`TasksRepository`, `Fetch/Add/ToggleTaskUseCase`) — Domain defines the contract, the outer layers implement it (Dependency Inversion). That's exactly why `SwiftDataTasksRepository`/`InMemoryTasksRepository` are interchangeable (prod / preview / tests) without any change to Domain or UI.

- **`Domain/`** — `TodoTask`/`TaskPriority` (pure `Sendable` models, no UIKit/SwiftUI), the `TasksRepository` protocol, three UseCase protocols with `callAsFunction(...)` (Fetch/Add/Toggle) + `Default...` implementations. UseCases here are **stateless** — no internal reactive state or publishers; the ViewModel's `Props` holds all of the screen's state and rebuilds it imperatively after each use-case call (the alternative — a UseCase with its own state that publishes through a publisher — is deliberately not used here). `AddTaskUseCase` validates a non-empty (trimmed) title and throws `TaskValidationError.emptyTitle` — a domain-side guard, separate from the UI-side `canSave` guard in `NewTaskViewModel`.
- **`Data/`** — `TaskEntity` (`@Model`, SwiftData) with `toDomain()` / `static func make(from:)` mapping; `SwiftDataTasksRepository` (production) and `InMemoryTasksRepository` (previews/tests, seeded from an array) — both implement `TasksRepository` and both are `@MainActor` (they hold a `ModelContainer`/mutable array that must live on the main actor). `DataAssembly` builds the `ModelContainer`, seeds data (`TodoTask.sampleList`) if the store is empty, and assembles the `TasksUseCases` bundle around whichever repository it's given.
- **`Composition/AppComposition.swift`** — the app's composition root: `bootstrap()` creates the `ModelContainer` once in `App.init` (`fatalError` on failure — deliberate, an unrecoverable startup error), `tasksUseCases(container:)` builds `TasksUseCases` for it.
- **`UI/`** — one folder per screen (`TaskList/`, `NewTask/`, `TaskCreated/`), each with `*Props.swift` + `*ViewModel.swift` + `*View.swift`; `UI/Flow/` is the feature's navigation layer; `UI/Shared/` holds formatters shared between a View and its ViewModel within one flow. `Architecture/` (the UDF/Coordinator/Router protocols) and `Components/`/`DesignSystem/` are cross-cutting, outside `UI/`.

### UDF ViewModel
`Architecture/UdfViewModel.swift` defines a protocol with `associatedtype Props/SyncEvent/AsyncEvent`, `var props: Props { get }`, `onEvent(_:)` (synchronous), and `onAsyncEvent(_:) async`. ViewModels are `@MainActor @Observable final class`, with `props` as `private(set)` and always `Equatable` — which lets tests compare a screen's entire state in one expression (`#expect(vm.props == expected)`) instead of field by field. A View holds not a concrete ViewModel type but the erased `AnyUdfViewModel<Props, SyncEvent, AsyncEvent>` (via `eraseToAnyViewModel()`); Coordinator/UIFactory likewise only ever hand out the erased type.

This is a deliberate choice of the UDF presentation style over "classic" MVVM (a ViewModel as a composition of Input/Output protocols, a separate `ViewState`, `ObservableObject`/`@Published`): UDF doesn't spawn a protocol per screen and doesn't force the View to be generic over its ViewModel type. The trade-off is that the ViewModel is tightly bound to its own View's `Props`, so it can't be reused across screens; **that's exactly why** the rule below exists.

**A non-obvious but deliberate rule — every View is the sole owner of its own `Props`/`SyncEvent`/`AsyncEvent`** (declared in `extension XxxView { struct Props; enum SyncEvent; enum AsyncEvent }`, in an `XxxProps.swift` file). Structurally identical types are deliberately **duplicated** across screens instead of being extracted into a shared type — for example `PriorityBadge` (low/medium/high + `title`) exists separately as `TaskRow.PriorityBadge`, `NewTaskView.Props.PriorityBadge`, and `TaskSummary.PriorityBadge`. Don't refactor this into one shared enum — that would break the screens' isolation from each other. Alongside this:
- Domain models (`TodoTask`, `TaskPriority`) stay Foundation-pure — no `Color`/SwiftUI.
- UI colors (`indicatorColor` etc.) are added via an `extension` in the View/Component file (e.g. `Components/TaskListRow.swift`), not in `*Props.swift`.
- The ViewModel is the only place that translates between the domain enum and the view-local one: `TaskRow.PriorityBadge($0.priority)` when reading from the repository, `props.priority.domain` when saving back into `TodoTask`.

### Data flow (using list loading as an example)
1. `TaskListView.body` has `.task { await viewModel.onAsync(.load) }` — fires when the root appears.
2. `TaskListViewModel.onAsyncEvent(.load)` calls `fetchTasks()` (`FetchTasksUseCase.callAsFunction()`).
3. The UseCase delegates to `TasksRepository.fetchAll()` (SwiftData or in-memory — the ViewModel doesn't know or care which).
4. The ViewModel maps the returned `[TodoTask]` into `Props` (`makeProps(from:)`) and updates `props` (animated or not) — the View re-renders via `@Observable`.

The same cycle — a View event → the ViewModel calls a UseCase → the UseCase calls the Repository → the ViewModel rebuilds `Props` — repeats for `.toggle` (`ToggleTaskUseCase`, then a reload) and `.save` (`AddTaskUseCase`, then `onEffect(.saveRequested(summary))`; the Coordinator drives navigation from that effect — see below).

### Navigation (Coordinator pattern)
`Router` (`@Observable`, wraps `NavigationPath`: `push`/`pop`/`popToRoot`) → the `Coordinator` protocol (`onComplete`, `start()`) → `TaskFlowCoordinator` (`@Observable`, holds `router`, a lazy `factory: UIFactory`, and **retains the root** `listViewModel` as a `lazy` property) → `UIFactory`/`DefaultUIFactory` builds concrete ViewModels from `TasksUseCases`.

The point of this layer is to take the "what happens next" decision out of the Views themselves (SRP): a View only renders UI and sends events/effects, and only the Coordinator decides on navigation. `UIFactory` is a separate indirection between the Coordinator and concrete ViewModels: it lets the Coordinator stay agnostic of how a ViewModel gets built, and it's what lets the tests (`UIFactoryTests`, `TaskFlowCoordinatorTests`, `TaskFlowIntegrationTests`) swap the production dependencies (`DataAssembly` + SwiftData) for `InMemoryTasksRepository` without touching the coordinator's own code.

Each ViewModel sends `onEffect: (CoordinatorEffect) -> Void` upward instead of a direct callback closure for a specific action; only the coordinator turns an effect into navigation (`TaskFlowCoordinator.handle(_:)`):
- `.createTaskRequested` → `router.push(.newTask)`
- `.saveRequested(TaskSummary)` → `Task { await listViewModel.onAsync(.load) }` (an imperative refresh — the root's `.task` doesn't fire again when returning to it in the stack, so reloading the list has to be explicit) + `router.push(.created(summary))`
- `.dismissForm` → `router.pop()`
- `.finishCreated` → `router.popToRoot()`

`TaskFlowFeature.Dependencies` is the feature's DI container (router + a `UIFactory` factory closure), assembled via `.live(router:useCases:)`. The coordinator is deliberately **not wrapped in an `AppCoordinator`** — it lives in `@State` inside `TaskFlowView` (YAGNI: a single flow doesn't need a coordinator registry).

### Concurrency (Swift 6, strict mode)
`SWIFT_VERSION = 6.0` for the whole target. The Domain layer (`TodoTask`, `TaskPriority`, `TasksRepository`, the use-case protocols) is `nonisolated`/`Sendable`, with no actor affinity. Everything presentation-side (ViewModels, `Router`, the `Coordinator` hierarchy, `AnyUdfViewModel`) and both repositories in `Data/` are `@MainActor` (the repositories because they hold a `ModelContainer`/mutable array that must live on the main actor).

### Tests
Swift Testing (`import Testing`, `@Test func`, `#expect(...)`), not XCTest; test types are `@MainActor struct ...Tests`. No mocking frameworks or protocol stubs — real collaborators everywhere, just `InMemoryTasksRepository(seed:)` instead of SwiftData:
- **Unit** — pure types and mapping with no external dependencies: e.g. `TaskEntityMappingTests` (`toDomain`/`make(from:)` round-trip), `RouterTests`, `AnyUdfViewModelTests`, `TaskUseCasesTests` (a UseCase against `InMemoryTasksRepository`).
- **Integration** — a ViewModel test is integration-level by definition, since the ViewModel depends on UseCase abstractions: `TaskListViewModelTests`/`NewTaskViewModelTests`/`UIFactoryTests` assemble the real chain ViewModel → UseCase → `InMemoryTasksRepository(seed:)`, without mocking any layer in between.
- **End-to-end** — `TaskFlowIntegrationTests` drives the full flow (list → newTask → save → created → finish) through a real `TaskFlowCoordinator` and `TaskFlowFeature.Dependencies.live(...)` on one shared repository, checking both `router.path` and `listViewModel.props` together.

### Design system
`DesignSystem/AppTheme.swift` — `AppColor` (an enum of static tokens over `Color(hex:)`) and `DotGridBackground` (a background pattern). `Components/` — reusable presentational Views with their own `#Preview` (buttons, list rows, badges); they don't know about ViewModels or a specific screen's Props, aside from lightweight local types like `TaskRow`. There's no localization infrastructure — UI strings are hardcoded directly in Ukrainian in the SwiftUI code.
