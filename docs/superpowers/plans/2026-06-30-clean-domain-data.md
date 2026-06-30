# Clean Domain/Data Foundation (#4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce Domain + Data (SwiftData) layers and rewire the existing `TaskList`/`NewTask` UDF ViewModels onto stateless use cases, so tasks persist and the list/toggle/save flow through a repository — with no navigation or App-root changes.

**Architecture:** Folder-based Clean layers (Domain ← Presentation, Domain ← Data; Domain independent). Stateless `callAsFunction` use cases wrap a `TasksRepository`; `@Observable` ViewModels manage `props` directly and call use cases. SwiftData backs the production repository; an in-memory repository serves previews/tests. Mirrors Ledger (`/Users/MAC/Documents/Ledger`, Transactions feature).

**Tech Stack:** SwiftUI, Observation (`@Observable`/`@State`), SwiftData, Swift Testing (`import Testing`), Swift concurrency (`async`/`@MainActor`).

## Global Constraints

- Platform: iOS 26.2 deployment; module `ToDo_UDF_MVVM`; Xcode scheme `ToDo.UDF.MVVM`.
- Test command: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.3'`; single suite: append `-only-testing:ToDo.UDF.MVVMTests/<SuiteType>`. Green = `** TEST SUCCEEDED **`; red = `** TEST FAILED **` or `** TEST BUILD FAILED **`.
- Swift Testing only (`@Test`, `#expect`, `@MainActor struct` suites). No XCTest.
- `@Observable` + `@MainActor` ViewModels/repositories; NO Combine. ViewModel dependencies and internal state are `@ObservationIgnored`; the single public `props` is rebuilt via a static `makeProps`/private `render` and reassigned.
- UDF triad unchanged: `Props: Equatable`, `SyncEvent`/`AsyncEvent` enums, `AnyUdfViewModel<Props, SyncEvent, AsyncEvent>`, `UdfViewModel` (`props`/`onEvent`/`onAsyncEvent`/`eraseToAnyViewModel()`).
- Ledger-faithful shapes: entity = `Sendable` struct; repository protocol `: Sendable` in Domain + impl in Data with `toDomain()`/`make(from:)`; use cases = `Default…` struct with `callAsFunction(...) async throws`; use-case bundle aggregates only domain protocols.
- Layers are folders (not SPM modules). New files under `ToDo.UDF.MVVM/` and `ToDo.UDF.MVVMTests/` are auto-included (both are `PBXFileSystemSynchronizedRootGroup`s) — NO `project.pbxproj` edits.
- Comments in Ukrainian (match the codebase).
- The persistent `TaskEntity` store uses a DISTINCT URL (`documentsDirectory/Tasks.store`) to avoid colliding with the template's default `Item` store during #4 coexistence.
- No behaviour regression to the three screens. Navigation (`TaskRoute`/`navigationDestination`), effect wiring, App-root switch, full coordinator lifecycle, and deletion of `Item.swift`/`ContentView.swift` are OUT of scope (sub-project #5).
- Task ordering keeps every commit compiling: the list-VM rewire is inseparable from its constructors, so Task 6 rewires the list path AND the DI scaffolding (factory init + coordinator init) together; Task 7 rewires the new-task path.

## File Structure

| Path | Responsibility |
|------|----------------|
| `Domain/Entities/TodoTask.swift` | Domain entity (moved from `Models/`) |
| `Domain/Entities/TaskPriority.swift` | Pure domain enum with `String` raw value |
| `Domain/Repositories/TasksRepository.swift` | Repository protocol (`Sendable`) |
| `Domain/UseCases/TaskUseCases.swift` | Fetch/Add/Toggle protocols + `Default…` impls + `TaskValidationError` |
| `Domain/UseCases/TasksUseCases.swift` | DI bundle struct (aggregates the three use-case protocols) |
| `Data/Models/TaskEntity.swift` | SwiftData `@Model` + `toDomain`/`make` mappers (replaces `Item`'s role in the feature) |
| `Data/Repositories/SwiftDataTasksRepository.swift` | Production `TasksRepository` over a `ModelContainer` |
| `Data/Repositories/InMemoryTasksRepository.swift` | In-memory `TasksRepository` for previews/tests |
| `Data/Composition/DataAssembly.swift` | Container/seed/use-case-bundle builders |
| `UI/Shared/TaskTimeFormatter.swift` | Shared `Date → "HH:mm"` formatter |
| `UI/Shared/TaskPriority+UI.swift` | Presentation extension (`title`, `indicatorColor`) |
| `Models/TaskSummary.swift` | (modify) keeps `TaskSummary`; `TaskPriority` removed |
| `UI/TaskList/*`, `UI/NewTask/*`, `UI/Flow/*` | (modify) rewired onto use cases |

---

## Task 1: Domain entities (move `TodoTask`, split `TaskPriority`)

**Files:**
- Create: `ToDo.UDF.MVVM/Domain/Entities/TaskPriority.swift`
- Create: `ToDo.UDF.MVVM/Domain/Entities/TodoTask.swift`
- Create: `ToDo.UDF.MVVM/UI/Shared/TaskPriority+UI.swift`
- Modify: `ToDo.UDF.MVVM/Models/TaskSummary.swift`
- Delete: `ToDo.UDF.MVVM/Models/TodoTask.swift`
- Test: `ToDo.UDF.MVVMTests/TaskPriorityTests.swift`

**Interfaces:**
- Produces: `TaskPriority: String, CaseIterable, Sendable` (cases `low`/`medium`/`high`); `TodoTask: Identifiable, Equatable, Hashable, Sendable` with `init(id: UUID = UUID(), title: String, notes: String? = nil, time: String, priority: TaskPriority, isDone: Bool = false)` and `static let sampleList: [TodoTask]`; presentation `TaskPriority.title: String` and `TaskPriority.indicatorColor: Color`.

- [ ] **Step 1: Write the failing test**

Create `ToDo.UDF.MVVMTests/TaskPriorityTests.swift`:
```swift
import Testing
import Foundation
@testable import ToDo_UDF_MVVM

@MainActor
struct TaskPriorityTests {
    @Test func priorityHasStringRawValue() {
        #expect(TaskPriority(rawValue: "high") == .high)
        #expect(TaskPriority.medium.rawValue == "medium")
    }

    @Test func todoTaskIsHashable() {
        let task = TodoTask(title: "X", time: "10:00", priority: .low)
        #expect(Set([task]).contains(task))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.3' -only-testing:ToDo.UDF.MVVMTests/TaskPriorityTests`
Expected: `** TEST BUILD FAILED **` — `TaskPriority` has no `init(rawValue:)` and `TodoTask` is not `Hashable`.

- [ ] **Step 3: Create the Domain enum**

Create `ToDo.UDF.MVVM/Domain/Entities/TaskPriority.swift`:
```swift
//
//  TaskPriority.swift
//  ToDo.UDF.MVVM
//
//  Доменний пріоритет задачі. Без залежностей від UI.
//

enum TaskPriority: String, CaseIterable, Sendable {
    case low
    case medium
    case high
}
```

- [ ] **Step 4: Create the presentation extension**

Create `ToDo.UDF.MVVM/UI/Shared/TaskPriority+UI.swift`:
```swift
//
//  TaskPriority+UI.swift
//  ToDo.UDF.MVVM
//
//  Презентаційне розширення доменного TaskPriority (заголовок, колір-індикатор).
//

import SwiftUI

extension TaskPriority {
    var title: String {
        switch self {
        case .low: "Низький"
        case .medium: "Середній"
        case .high: "Високий"
        }
    }

    var indicatorColor: Color {
        switch self {
        case .low: Color(hex: 0xC4C4C8)
        case .medium: Color(hex: 0x71717A)
        case .high: Color(hex: 0x16161A)
        }
    }
}
```

- [ ] **Step 5: Move `TodoTask` into Domain**

Create `ToDo.UDF.MVVM/Domain/Entities/TodoTask.swift`:
```swift
//
//  TodoTask.swift
//  ToDo.UDF.MVVM
//
//  Доменна сутність задачі.
//

import Foundation

struct TodoTask: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var title: String
    var notes: String?
    var time: String
    var priority: TaskPriority
    var isDone: Bool

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        time: String,
        priority: TaskPriority,
        isDone: Bool = false
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.time = time
        self.priority = priority
        self.isDone = isDone
    }
}

extension TodoTask {
    // Демо-дані: 4 активні + 2 виконані → прогрес 33%.
    static let sampleList: [TodoTask] = [
        TodoTask(title: "Підготувати презентацію", time: "09:30", priority: .high),
        TodoTask(
            title: "Дзвінок з командою дизайну",
            notes: "Обговорити нову сітку інтерфейсу",
            time: "11:00",
            priority: .medium
        ),
        TodoTask(title: "Рев'ю пул-реквестів", time: "14:00", priority: .low),
        TodoTask(title: "Запланувати спринт", time: "16:30", priority: .medium),
        TodoTask(title: "Оновити залежності", time: "08:00", priority: .low, isDone: true),
        TodoTask(title: "Розгорнути на стейджинг", time: "18:00", priority: .high, isDone: true),
    ]
}
```

Then delete the old file: `rm ToDo.UDF.MVVM/Models/TodoTask.swift`.

- [ ] **Step 6: Drop `TaskPriority` from `TaskSummary.swift`**

Replace the full contents of `ToDo.UDF.MVVM/Models/TaskSummary.swift` with:
```swift
//
//  TaskSummary.swift
//  ToDo.UDF.MVVM
//
//  Легка presentational-модель задачі для екранів-підтверджень.
//

import Foundation

struct TaskSummary: Equatable {
    let title: String
    let time: String
    let priority: TaskPriority
}

extension TaskSummary {
    static let sample = TaskSummary(
        title: "Зустріч із інвестором",
        time: "09:30",
        priority: .medium
    )
}
```

- [ ] **Step 7: Run the suite to verify green + no regression**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.3'`
Expected: `** TEST SUCCEEDED **` — `TaskPriorityTests` passes and all pre-existing tests still pass (pure move; `TaskPriority`/`TodoTask`/`TaskSummary` resolve unchanged).

- [ ] **Step 8: Commit**

```bash
git add ToDo.UDF.MVVM/Domain ToDo.UDF.MVVM/UI/Shared/TaskPriority+UI.swift ToDo.UDF.MVVM/Models ToDo.UDF.MVVMTests/TaskPriorityTests.swift
git commit -m "$(cat <<'EOF'
refactor: move TodoTask + TaskPriority into Domain/Entities

TaskPriority gains a String raw value (for persistence mapping); UI
title/indicatorColor move to a presentation extension. TodoTask becomes
Hashable/Sendable. Behaviour-preserving.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Domain repository protocol + use cases + bundle

**Files:**
- Create: `ToDo.UDF.MVVM/Domain/Repositories/TasksRepository.swift`
- Create: `ToDo.UDF.MVVM/Domain/UseCases/TaskUseCases.swift`
- Create: `ToDo.UDF.MVVM/Domain/UseCases/TasksUseCases.swift`
- Test: `ToDo.UDF.MVVMTests/TaskUseCasesTests.swift`

**Interfaces:**
- Consumes: `TodoTask`, `TaskPriority` (Task 1).
- Produces: `protocol TasksRepository: Sendable { func fetchAll() async throws -> [TodoTask]; func add(_ task: TodoTask) async throws; func toggleDone(id: UUID) async throws }`; `FetchTasksUseCase`/`AddTaskUseCase`/`ToggleTaskUseCase` protocols + `DefaultFetchTasksUseCase`/`DefaultAddTaskUseCase`/`DefaultToggleTaskUseCase` (each `init(repository: any TasksRepository)`, `callAsFunction` async throws); `enum TaskValidationError: Error, Equatable { case emptyTitle }`; `struct TasksUseCases { let fetchTasks: any FetchTasksUseCase; let addTask: any AddTaskUseCase; let toggleTask: any ToggleTaskUseCase }`.

- [ ] **Step 1: Write the failing test**

Create `ToDo.UDF.MVVMTests/TaskUseCasesTests.swift`:
```swift
import Testing
import Foundation
@testable import ToDo_UDF_MVVM

@MainActor
private final class StubTasksRepository: TasksRepository {
    var stored: [TodoTask]
    private(set) var addCalls: [TodoTask] = []
    private(set) var toggledIds: [UUID] = []

    init(stored: [TodoTask] = []) { self.stored = stored }

    func fetchAll() async throws -> [TodoTask] { stored }
    func add(_ task: TodoTask) async throws { addCalls.append(task); stored.append(task) }
    func toggleDone(id: UUID) async throws {
        toggledIds.append(id)
        if let i = stored.firstIndex(where: { $0.id == id }) { stored[i].isDone.toggle() }
    }
}

@MainActor
struct TaskUseCasesTests {
    @Test func fetchReturnsRepositoryContents() async throws {
        let repo = StubTasksRepository(stored: TodoTask.sampleList)
        let useCase = DefaultFetchTasksUseCase(repository: repo)
        let result = try await useCase()
        #expect(result.count == TodoTask.sampleList.count)
    }

    @Test func addInsertsTask() async throws {
        let repo = StubTasksRepository()
        let useCase = DefaultAddTaskUseCase(repository: repo)
        try await useCase(TodoTask(title: "Нова", time: "10:00", priority: .low))
        #expect(repo.addCalls.count == 1)
        #expect(repo.stored.count == 1)
    }

    @Test func addThrowsOnEmptyTitle() async {
        let repo = StubTasksRepository()
        let useCase = DefaultAddTaskUseCase(repository: repo)
        await #expect(throws: TaskValidationError.emptyTitle) {
            try await useCase(TodoTask(title: "   ", time: "10:00", priority: .low))
        }
        #expect(repo.addCalls.isEmpty)
    }

    @Test func toggleDelegatesToRepository() async throws {
        let task = TodoTask(title: "X", time: "10:00", priority: .low)
        let repo = StubTasksRepository(stored: [task])
        let useCase = DefaultToggleTaskUseCase(repository: repo)
        try await useCase(id: task.id)
        #expect(repo.toggledIds == [task.id])
        #expect(repo.stored[0].isDone)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.3' -only-testing:ToDo.UDF.MVVMTests/TaskUseCasesTests`
Expected: `** TEST BUILD FAILED **` — `cannot find 'TasksRepository' / 'DefaultFetchTasksUseCase' / 'TaskValidationError' in scope`.

- [ ] **Step 3: Create the repository protocol**

Create `ToDo.UDF.MVVM/Domain/Repositories/TasksRepository.swift`:
```swift
//
//  TasksRepository.swift
//  ToDo.UDF.MVVM
//
//  Контракт сховища задач. Реалізується у шарі Data.
//

import Foundation

protocol TasksRepository: Sendable {
    func fetchAll() async throws -> [TodoTask]
    func add(_ task: TodoTask) async throws
    func toggleDone(id: UUID) async throws
}
```

- [ ] **Step 4: Create the use cases**

Create `ToDo.UDF.MVVM/Domain/UseCases/TaskUseCases.swift`:
```swift
//
//  TaskUseCases.swift
//  ToDo.UDF.MVVM
//
//  Доменні use cases задач: stateless-обгортки над TasksRepository.
//

import Foundation

enum TaskValidationError: Error, Equatable {
    case emptyTitle
}

protocol FetchTasksUseCase: Sendable {
    func callAsFunction() async throws -> [TodoTask]
}

protocol AddTaskUseCase: Sendable {
    func callAsFunction(_ task: TodoTask) async throws
}

protocol ToggleTaskUseCase: Sendable {
    func callAsFunction(id: UUID) async throws
}

struct DefaultFetchTasksUseCase: FetchTasksUseCase {
    private let repository: any TasksRepository
    init(repository: any TasksRepository) { self.repository = repository }
    func callAsFunction() async throws -> [TodoTask] {
        try await repository.fetchAll()
    }
}

struct DefaultAddTaskUseCase: AddTaskUseCase {
    private let repository: any TasksRepository
    init(repository: any TasksRepository) { self.repository = repository }
    func callAsFunction(_ task: TodoTask) async throws {
        guard !task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TaskValidationError.emptyTitle
        }
        try await repository.add(task)
    }
}

struct DefaultToggleTaskUseCase: ToggleTaskUseCase {
    private let repository: any TasksRepository
    init(repository: any TasksRepository) { self.repository = repository }
    func callAsFunction(id: UUID) async throws {
        try await repository.toggleDone(id: id)
    }
}
```

- [ ] **Step 5: Create the use-case bundle**

Create `ToDo.UDF.MVVM/Domain/UseCases/TasksUseCases.swift`:
```swift
//
//  TasksUseCases.swift
//  ToDo.UDF.MVVM
//
//  DI-набір use cases фічі задач (агрегує лише доменні протоколи).
//

struct TasksUseCases {
    let fetchTasks: any FetchTasksUseCase
    let addTask: any AddTaskUseCase
    let toggleTask: any ToggleTaskUseCase
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.3' -only-testing:ToDo.UDF.MVVMTests/TaskUseCasesTests`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add ToDo.UDF.MVVM/Domain/Repositories ToDo.UDF.MVVM/Domain/UseCases ToDo.UDF.MVVMTests/TaskUseCasesTests.swift
git commit -m "$(cat <<'EOF'
feat: add TasksRepository protocol + Fetch/Add/Toggle use cases

Stateless callAsFunction use cases over the repository; AddTask validates
a non-empty title. Adds the TasksUseCases DI bundle.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Data — `TaskEntity` + mapping

**Files:**
- Create: `ToDo.UDF.MVVM/Data/Models/TaskEntity.swift`
- Test: `ToDo.UDF.MVVMTests/TaskEntityMappingTests.swift`

**Interfaces:**
- Consumes: `TodoTask`, `TaskPriority`.
- Produces: `@Model final class TaskEntity` with `init(id:title:notes:time:priorityRaw:isDone:)`, `func toDomain() -> TodoTask`, `static func make(from: TodoTask) -> TaskEntity`.

- [ ] **Step 1: Write the failing test**

Create `ToDo.UDF.MVVMTests/TaskEntityMappingTests.swift`:
```swift
import Testing
import Foundation
@testable import ToDo_UDF_MVVM

@MainActor
struct TaskEntityMappingTests {
    @Test func roundTripsThroughDomain() {
        let task = TodoTask(title: "Зустріч", notes: "деталі", time: "09:30", priority: .high, isDone: true)
        let back = TaskEntity.make(from: task).toDomain()
        #expect(back == task)
    }

    @Test func mapsNilNotes() {
        let task = TodoTask(title: "Без нотаток", notes: nil, time: "10:00", priority: .low)
        let back = TaskEntity.make(from: task).toDomain()
        #expect(back.notes == nil)
    }

    @Test func mapsPriorityRawValue() {
        let entity = TaskEntity.make(from: TodoTask(title: "X", time: "10:00", priority: .medium))
        #expect(entity.priorityRaw == "medium")
        #expect(entity.toDomain().priority == .medium)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.3' -only-testing:ToDo.UDF.MVVMTests/TaskEntityMappingTests`
Expected: `** TEST BUILD FAILED **` — `cannot find 'TaskEntity' in scope`.

- [ ] **Step 3: Create the SwiftData entity + mappers**

Create `ToDo.UDF.MVVM/Data/Models/TaskEntity.swift`:
```swift
//
//  TaskEntity.swift
//  ToDo.UDF.MVVM
//
//  SwiftData-модель задачі + мапінг у доменний TodoTask.
//

import Foundation
import SwiftData

@Model
final class TaskEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String?
    var time: String
    var priorityRaw: String
    var isDone: Bool

    init(id: UUID, title: String, notes: String?, time: String, priorityRaw: String, isDone: Bool) {
        self.id = id
        self.title = title
        self.notes = notes
        self.time = time
        self.priorityRaw = priorityRaw
        self.isDone = isDone
    }
}

extension TaskEntity {
    func toDomain() -> TodoTask {
        TodoTask(
            id: id,
            title: title,
            notes: notes,
            time: time,
            priority: TaskPriority(rawValue: priorityRaw) ?? .medium,
            isDone: isDone
        )
    }

    static func make(from task: TodoTask) -> TaskEntity {
        TaskEntity(
            id: task.id,
            title: task.title,
            notes: task.notes,
            time: task.time,
            priorityRaw: task.priority.rawValue,
            isDone: task.isDone
        )
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.3' -only-testing:ToDo.UDF.MVVMTests/TaskEntityMappingTests`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add ToDo.UDF.MVVM/Data/Models/TaskEntity.swift ToDo.UDF.MVVMTests/TaskEntityMappingTests.swift
git commit -m "$(cat <<'EOF'
feat: add SwiftData TaskEntity with domain mappers

@Model entity + toDomain()/make(from:) round-trip mapping (priorityRaw
<-> TaskPriority, optional notes).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Data — `SwiftDataTasksRepository`

**Files:**
- Create: `ToDo.UDF.MVVM/Data/Repositories/SwiftDataTasksRepository.swift`
- Test: `ToDo.UDF.MVVMTests/SwiftDataTasksRepositoryTests.swift`

**Interfaces:**
- Consumes: `TasksRepository` (Task 2), `TaskEntity` (Task 3).
- Produces: `@MainActor final class SwiftDataTasksRepository: TasksRepository { init(container: ModelContainer) }`. `fetchAll()` returns domain tasks sorted by `time` ascending.

- [ ] **Step 1: Write the failing test**

Create `ToDo.UDF.MVVMTests/SwiftDataTasksRepositoryTests.swift`:
```swift
import Testing
import Foundation
import SwiftData
@testable import ToDo_UDF_MVVM

@MainActor
struct SwiftDataTasksRepositoryTests {
    private func makeRepository() throws -> SwiftDataTasksRepository {
        let container = try ModelContainer(
            for: TaskEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return SwiftDataTasksRepository(container: container)
    }

    @Test func addThenFetchRoundTrips() async throws {
        let repo = try makeRepository()
        let task = TodoTask(title: "Зустріч", notes: "деталі", time: "09:30", priority: .high)
        try await repo.add(task)
        let all = try await repo.fetchAll()
        #expect(all.count == 1)
        #expect(all[0] == task)
    }

    @Test func fetchSortsByTimeAscending() async throws {
        let repo = try makeRepository()
        try await repo.add(TodoTask(title: "Пізніше", time: "18:00", priority: .low))
        try await repo.add(TodoTask(title: "Раніше", time: "08:00", priority: .low))
        let all = try await repo.fetchAll()
        #expect(all.map(\.time) == ["08:00", "18:00"])
    }

    @Test func toggleDoneFlipsAndPersists() async throws {
        let repo = try makeRepository()
        let task = TodoTask(title: "X", time: "10:00", priority: .low)
        try await repo.add(task)
        try await repo.toggleDone(id: task.id)
        let all = try await repo.fetchAll()
        #expect(all[0].isDone)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.3' -only-testing:ToDo.UDF.MVVMTests/SwiftDataTasksRepositoryTests`
Expected: `** TEST BUILD FAILED **` — `cannot find 'SwiftDataTasksRepository' in scope`.

- [ ] **Step 3: Create the repository**

Create `ToDo.UDF.MVVM/Data/Repositories/SwiftDataTasksRepository.swift`:
```swift
//
//  SwiftDataTasksRepository.swift
//  ToDo.UDF.MVVM
//
//  Реалізація TasksRepository на SwiftData. Володіє контейнером,
//  працює з його головним контекстом.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataTasksRepository: TasksRepository {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func fetchAll() async throws -> [TodoTask] {
        let descriptor = FetchDescriptor<TaskEntity>(
            sortBy: [SortDescriptor(\.time, order: .forward)]
        )
        return try container.mainContext.fetch(descriptor).map { $0.toDomain() }
    }

    func add(_ task: TodoTask) async throws {
        container.mainContext.insert(TaskEntity.make(from: task))
        try container.mainContext.save()
    }

    func toggleDone(id: UUID) async throws {
        let descriptor = FetchDescriptor<TaskEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try container.mainContext.fetch(descriptor).first else { return }
        entity.isDone.toggle()
        try container.mainContext.save()
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.3' -only-testing:ToDo.UDF.MVVMTests/SwiftDataTasksRepositoryTests`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add ToDo.UDF.MVVM/Data/Repositories/SwiftDataTasksRepository.swift ToDo.UDF.MVVMTests/SwiftDataTasksRepositoryTests.swift
git commit -m "$(cat <<'EOF'
feat: add SwiftDataTasksRepository

TasksRepository backed by a ModelContainer (single source of truth):
fetch sorted by time, add+save, toggleDone via #Predicate.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Data — `InMemoryTasksRepository` + `DataAssembly`

**Files:**
- Create: `ToDo.UDF.MVVM/Data/Repositories/InMemoryTasksRepository.swift`
- Create: `ToDo.UDF.MVVM/Data/Composition/DataAssembly.swift`
- Test: `ToDo.UDF.MVVMTests/InMemoryTasksRepositoryTests.swift`
- Test: `ToDo.UDF.MVVMTests/DataAssemblyTests.swift`

**Interfaces:**
- Consumes: `TasksRepository`, `TasksUseCases`, `Default…UseCase`, `TaskEntity`, `SwiftDataTasksRepository`, `TodoTask`.
- Produces: `@MainActor final class InMemoryTasksRepository: TasksRepository { init(seed: [TodoTask] = TodoTask.sampleList) }` (`fetchAll` sorted by time); `enum DataAssembly` with `static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer`, `static func seedIfNeeded(context: ModelContext)`, `static func makeUseCases(repository: any TasksRepository) -> TasksUseCases`, `static func makeLiveUseCases() -> TasksUseCases`.

- [ ] **Step 1: Write the failing tests**

Create `ToDo.UDF.MVVMTests/InMemoryTasksRepositoryTests.swift`:
```swift
import Testing
import Foundation
@testable import ToDo_UDF_MVVM

@MainActor
struct InMemoryTasksRepositoryTests {
    @Test func fetchAllReturnsSeedSortedByTime() async throws {
        let repo = InMemoryTasksRepository(seed: [
            TodoTask(title: "Пізніше", time: "18:00", priority: .low),
            TodoTask(title: "Раніше", time: "08:00", priority: .low),
        ])
        let all = try await repo.fetchAll()
        #expect(all.map(\.time) == ["08:00", "18:00"])
    }

    @Test func addAppends() async throws {
        let repo = InMemoryTasksRepository(seed: [])
        try await repo.add(TodoTask(title: "X", time: "10:00", priority: .low))
        #expect(try await repo.fetchAll().count == 1)
    }

    @Test func toggleDoneFlips() async throws {
        let task = TodoTask(title: "X", time: "10:00", priority: .low)
        let repo = InMemoryTasksRepository(seed: [task])
        try await repo.toggleDone(id: task.id)
        #expect(try await repo.fetchAll()[0].isDone)
    }
}
```

Create `ToDo.UDF.MVVMTests/DataAssemblyTests.swift`:
```swift
import Testing
import Foundation
import SwiftData
@testable import ToDo_UDF_MVVM

@MainActor
struct DataAssemblyTests {
    @Test func seedIfNeededSeedsOnceIntoEmptyStore() throws {
        let container = try DataAssembly.makeModelContainer(inMemory: true)
        DataAssembly.seedIfNeeded(context: container.mainContext)
        let afterFirst = try container.mainContext.fetchCount(FetchDescriptor<TaskEntity>())
        #expect(afterFirst == TodoTask.sampleList.count)
        DataAssembly.seedIfNeeded(context: container.mainContext)
        let afterSecond = try container.mainContext.fetchCount(FetchDescriptor<TaskEntity>())
        #expect(afterSecond == TodoTask.sampleList.count)
    }

    @Test func makeUseCasesBuildsWorkingBundle() async throws {
        let useCases = DataAssembly.makeUseCases(repository: InMemoryTasksRepository(seed: []))
        try await useCases.addTask(TodoTask(title: "X", time: "10:00", priority: .low))
        #expect(try await useCases.fetchTasks().count == 1)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.3' -only-testing:ToDo.UDF.MVVMTests/InMemoryTasksRepositoryTests -only-testing:ToDo.UDF.MVVMTests/DataAssemblyTests`
Expected: `** TEST BUILD FAILED **` — `cannot find 'InMemoryTasksRepository' / 'DataAssembly' in scope`.

- [ ] **Step 3: Create the in-memory repository**

Create `ToDo.UDF.MVVM/Data/Repositories/InMemoryTasksRepository.swift`:
```swift
//
//  InMemoryTasksRepository.swift
//  ToDo.UDF.MVVM
//
//  In-memory реалізація TasksRepository для прев'ю та тестів.
//

import Foundation

@MainActor
final class InMemoryTasksRepository: TasksRepository {
    private var tasks: [TodoTask]

    init(seed: [TodoTask] = TodoTask.sampleList) {
        self.tasks = seed
    }

    func fetchAll() async throws -> [TodoTask] {
        tasks.sorted { $0.time < $1.time }
    }

    func add(_ task: TodoTask) async throws {
        tasks.append(task)
    }

    func toggleDone(id: UUID) async throws {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].isDone.toggle()
    }
}
```

- [ ] **Step 4: Create the data assembly**

Create `ToDo.UDF.MVVM/Data/Composition/DataAssembly.swift`:
```swift
//
//  DataAssembly.swift
//  ToDo.UDF.MVVM
//
//  Збірка шару даних: контейнер SwiftData, сидування, набір use cases.
//

import Foundation
import SwiftData

@MainActor
enum DataAssembly {
    static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([TaskEntity.self])
        // Окреме сховище "Tasks.store", щоб не конфліктувати зі стандартним
        // сховищем шаблонного Item, поки воно співіснує (#4). #5 спростить.
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema, url: URL.documentsDirectory.appending(path: "Tasks.store"))
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func seedIfNeeded(context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<TaskEntity>())) ?? 0
        guard existing == 0 else { return }
        for task in TodoTask.sampleList {
            context.insert(TaskEntity.make(from: task))
        }
        try? context.save()
    }

    static func makeUseCases(repository: any TasksRepository) -> TasksUseCases {
        TasksUseCases(
            fetchTasks: DefaultFetchTasksUseCase(repository: repository),
            addTask: DefaultAddTaskUseCase(repository: repository),
            toggleTask: DefaultToggleTaskUseCase(repository: repository)
        )
    }

    static func makeLiveUseCases() -> TasksUseCases {
        do {
            let container = try makeModelContainer()
            seedIfNeeded(context: container.mainContext)
            return makeUseCases(repository: SwiftDataTasksRepository(container: container))
        } catch {
            fatalError("Не вдалося ініціалізувати сховище задач: \(error)")
        }
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.3' -only-testing:ToDo.UDF.MVVMTests/InMemoryTasksRepositoryTests -only-testing:ToDo.UDF.MVVMTests/DataAssemblyTests`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add ToDo.UDF.MVVM/Data/Repositories/InMemoryTasksRepository.swift ToDo.UDF.MVVM/Data/Composition/DataAssembly.swift ToDo.UDF.MVVMTests/InMemoryTasksRepositoryTests.swift ToDo.UDF.MVVMTests/DataAssemblyTests.swift
git commit -m "$(cat <<'EOF'
feat: add InMemoryTasksRepository + DataAssembly

In-memory repo for previews/tests; DataAssembly builds the container
(distinct Tasks.store), seeds sample data once, and assembles the
use-case bundle (makeUseCases / makeLiveUseCases).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Rewire the list path + DI scaffolding

Rewiring `TaskListViewModel.init` breaks its only constructors (`UIFactory`, `TaskFlowCoordinator`), so this task changes the list screen AND the factory/coordinator construction together — the smallest set that compiles. `NewTaskViewModel` keeps its current init here; the factory still builds it the old way until Task 7.

**Files:**
- Modify: `ToDo.UDF.MVVM/UI/TaskList/TaskListProps.swift`
- Modify: `ToDo.UDF.MVVM/UI/TaskList/TaskListViewModel.swift`
- Modify: `ToDo.UDF.MVVM/UI/TaskList/TaskListView.swift`
- Modify: `ToDo.UDF.MVVM/UI/Flow/UIFactory.swift`
- Modify: `ToDo.UDF.MVVM/UI/Flow/TaskFlowCoordinator.swift`
- Modify: `ToDo.UDF.MVVMTests/TaskListViewModelTests.swift`
- Modify: `ToDo.UDF.MVVMTests/UIFactoryTests.swift`
- Modify: `ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift`

**Interfaces:**
- Consumes: `FetchTasksUseCase`, `ToggleTaskUseCase`, `TasksUseCases`, `DataAssembly`, `InMemoryTasksRepository`, `DefaultFetchTasksUseCase`, `DefaultToggleTaskUseCase`.
- Produces: `TaskListViewModel.init(fetchTasks: any FetchTasksUseCase, toggleTask: any ToggleTaskUseCase, onEffect:)`; `TaskListView.AsyncEvent { case load; case toggle(id:reduceMotion:) }`, `SyncEvent { case addTapped }`; `DefaultUIFactory.init(useCases: TasksUseCases)`, `taskListViewModel(onEffect:)` (no `tasks:`); `TaskFlowCoordinator.init(factory:)` + `convenience init()`; `makeTaskListViewModel()` (no `tasks:`).

- [ ] **Step 1: Rewrite the three test files (the failing spec)**

Replace `ToDo.UDF.MVVMTests/TaskListViewModelTests.swift` with:
```swift
import Testing
import Foundation
@testable import ToDo_UDF_MVVM

@MainActor
struct TaskListViewModelTests {
    private func makeViewModel(
        seed: [TodoTask] = TodoTask.sampleList,
        onEffect: @escaping (CoordinatorEffect) -> Void = { _ in }
    ) -> TaskListViewModel {
        let repository = InMemoryTasksRepository(seed: seed)
        return TaskListViewModel(
            fetchTasks: DefaultFetchTasksUseCase(repository: repository),
            toggleTask: DefaultToggleTaskUseCase(repository: repository),
            onEffect: onEffect
        )
    }

    @Test func loadSplitsTasks() async {
        let vm = makeViewModel()
        await vm.onAsyncEvent(.load)
        #expect(vm.props.active.count == 4)
        #expect(vm.props.completed.count == 2)
        #expect(abs(vm.props.progress - 2.0 / 6.0) < 0.0001)
    }

    @Test func toggleActiveMovesToCompleted() async {
        let vm = makeViewModel()
        await vm.onAsyncEvent(.load)
        let target = vm.props.active[0]
        await vm.onAsyncEvent(.toggle(id: target.id, reduceMotion: true))
        #expect(!vm.props.active.contains { $0.id == target.id })
        #expect(vm.props.completed.contains { $0.id == target.id })
        #expect(vm.props.completed.count == 3)
    }

    @Test func toggleCompletedMovesToActive() async {
        let vm = makeViewModel()
        await vm.onAsyncEvent(.load)
        let target = vm.props.completed[0]
        await vm.onAsyncEvent(.toggle(id: target.id, reduceMotion: true))
        #expect(vm.props.active.contains { $0.id == target.id })
        #expect(vm.props.completed.count == 1)
    }

    @Test func toggleUnknownIdDoesNothing() async {
        let vm = makeViewModel()
        await vm.onAsyncEvent(.load)
        await vm.onAsyncEvent(.toggle(id: UUID(), reduceMotion: true))
        #expect(vm.props.active.count == 4)
        #expect(vm.props.completed.count == 2)
    }

    @Test func addTappedEmitsCreateTaskRequested() {
        var received: CoordinatorEffect?
        let vm = makeViewModel(onEffect: { received = $0 })
        vm.onEvent(.addTapped)
        #expect(received == .createTaskRequested)
    }
}
```

Replace `ToDo.UDF.MVVMTests/UIFactoryTests.swift` with:
```swift
import Testing
@testable import ToDo_UDF_MVVM

@MainActor
struct UIFactoryTests {
    private func makeFactory(seed: [TodoTask] = TodoTask.sampleList) -> DefaultUIFactory {
        DefaultUIFactory(useCases: DataAssembly.makeUseCases(repository: InMemoryTasksRepository(seed: seed)))
    }

    @Test func buildsTaskCreatedViewModelCarryingTask() {
        let vm = makeFactory().taskCreatedViewModel(task: .sample, onEffect: { _ in })
        #expect(vm.props.task == .sample)
    }

    @Test func builtTaskCreatedViewModelEmitsEffect() {
        var received: CoordinatorEffect?
        let vm = makeFactory().taskCreatedViewModel(task: .sample, onEffect: { received = $0 })
        vm.onEvent(.continueTapped)
        #expect(received == .finishCreated)
    }

    @Test func buildsTaskListViewModel() async {
        let vm = makeFactory().taskListViewModel(onEffect: { _ in })
        await vm.onAsyncEvent(.load)
        #expect(vm.props.active.count + vm.props.completed.count == TodoTask.sampleList.count)
    }

    @Test func builtTaskListViewModelEmitsEffect() {
        var received: CoordinatorEffect?
        let vm = makeFactory().taskListViewModel(onEffect: { received = $0 })
        vm.onEvent(.addTapped)
        #expect(received == .createTaskRequested)
    }

    @Test func buildsNewTaskViewModel() {
        let vm = makeFactory().newTaskViewModel(onEffect: { _ in })
        #expect(vm.props.canSave)
    }

    @Test func builtNewTaskViewModelEmitsEffect() {
        var received: CoordinatorEffect?
        let vm = makeFactory().newTaskViewModel(onEffect: { received = $0 })
        vm.onEvent(.backTapped)
        #expect(received == .dismissForm)
    }
}
```

Replace `ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift` with:
```swift
import Testing
import SwiftUI
@testable import ToDo_UDF_MVVM

@MainActor
struct TaskFlowCoordinatorTests {
    private func makeCoordinator() -> TaskFlowCoordinator {
        let useCases = DataAssembly.makeUseCases(repository: InMemoryTasksRepository())
        return TaskFlowCoordinator(factory: DefaultUIFactory(useCases: useCases))
    }

    @Test func finishCreatedPopsToRoot() {
        let coordinator = makeCoordinator()
        coordinator.router.push("x")
        #expect(coordinator.router.path.count == 1)
        coordinator.handle(.finishCreated)
        #expect(coordinator.router.path.isEmpty)
    }

    @Test func makesTaskCreatedViewModelCarryingTask() {
        let coordinator = makeCoordinator()
        let vm = coordinator.makeTaskCreatedViewModel(task: .sample)
        #expect(vm.props.task == .sample)
    }

    @Test func createTaskRequestedIsNoOp() {
        let coordinator = makeCoordinator()
        coordinator.handle(.createTaskRequested)
        #expect(coordinator.router.path.isEmpty)
    }

    @Test func makesTaskListViewModel() {
        let coordinator = makeCoordinator()
        let vm = coordinator.makeTaskListViewModel()
        #expect(vm.props.active.isEmpty)   // до .load список порожній
    }

    @Test func saveRequestedIsNoOp() {
        let coordinator = makeCoordinator()
        coordinator.handle(.saveRequested)
        #expect(coordinator.router.path.isEmpty)
    }

    @Test func dismissFormIsNoOp() {
        let coordinator = makeCoordinator()
        coordinator.handle(.dismissForm)
        #expect(coordinator.router.path.isEmpty)
    }

    @Test func makesNewTaskViewModel() {
        let coordinator = makeCoordinator()
        let vm = coordinator.makeNewTaskViewModel()
        #expect(vm.props.canSave)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.3'`
Expected: `** TEST BUILD FAILED **` — `.toggle`/`.load` not async, `TaskListViewModel.init(fetchTasks:toggleTask:onEffect:)` missing, `DefaultUIFactory(useCases:)` missing, `TaskFlowCoordinator(factory:)` missing.

- [ ] **Step 3: Update `TaskListProps.swift`**

Replace the full contents of `ToDo.UDF.MVVM/UI/TaskList/TaskListProps.swift` with:
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
        case addTapped
    }

    enum AsyncEvent: Equatable {
        case load
        case toggle(id: UUID, reduceMotion: Bool)
    }
}
```

- [ ] **Step 4: Update `TaskListViewModel.swift`**

Replace the full contents of `ToDo.UDF.MVVM/UI/TaskList/TaskListViewModel.swift` with:
```swift
//
//  TaskListViewModel.swift
//  ToDo.UDF.MVVM
//
//  UDF-ViewModel списку задач. Вантажить задачі через FetchTasksUseCase,
//  перемикає через ToggleTaskUseCase і деривує Props ([TaskRow] + progress).
//

import SwiftUI

@MainActor
@Observable
final class TaskListViewModel: UdfViewModel {
    typealias Props = TaskListView.Props
    typealias SyncEvent = TaskListView.SyncEvent
    typealias AsyncEvent = TaskListView.AsyncEvent

    private(set) var props: Props

    @ObservationIgnored private let fetchTasks: any FetchTasksUseCase
    @ObservationIgnored private let toggleTask: any ToggleTaskUseCase
    @ObservationIgnored private let onEffect: (CoordinatorEffect) -> Void

    init(
        fetchTasks: any FetchTasksUseCase,
        toggleTask: any ToggleTaskUseCase,
        onEffect: @escaping (CoordinatorEffect) -> Void = { _ in }
    ) {
        self.fetchTasks = fetchTasks
        self.toggleTask = toggleTask
        self.onEffect = onEffect
        self.props = Self.makeProps(from: [])
    }

    func onEvent(_ event: SyncEvent) {
        switch event {
        case .addTapped:
            onEffect(.createTaskRequested)
        }
    }

    func onAsyncEvent(_ event: AsyncEvent) async {
        switch event {
        case .load:
            await reload(animated: false)
        case let .toggle(id, reduceMotion):
            try? await toggleTask(id: id)
            await reload(animated: !reduceMotion)
        }
    }

    private func reload(animated: Bool) async {
        let tasks = (try? await fetchTasks()) ?? []
        let newProps = Self.makeProps(from: tasks)
        withAnimation(animated ? .spring(response: 0.4, dampingFraction: 0.85) : nil) {
            props = newProps
        }
    }

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

- [ ] **Step 5: Update `TaskListView.swift`**

Add an initial-load trigger: after the `.sensoryFeedback(...)` modifier on the `ZStack` in `body`, append:
```swift
        .task { await viewModel.onAsync(.load) }
```

Change the active-rows toggle closure from:
```swift
                    ForEach(viewModel.props.active) { row in
                        TaskListRow(row: row) {
                            viewModel.onEvent(.toggle(id: row.id, reduceMotion: reduceMotion))
                        }
                    }
```
to:
```swift
                    ForEach(viewModel.props.active) { row in
                        TaskListRow(row: row) {
                            Task { await viewModel.onAsync(.toggle(id: row.id, reduceMotion: reduceMotion)) }
                        }
                    }
```

Change the completed-rows toggle closure from:
```swift
                    ForEach(viewModel.props.completed) { row in
                        CompletedTaskRow(row: row) {
                            viewModel.onEvent(.toggle(id: row.id, reduceMotion: reduceMotion))
                        }
                    }
```
to:
```swift
                    ForEach(viewModel.props.completed) { row in
                        CompletedTaskRow(row: row) {
                            Task { await viewModel.onAsync(.toggle(id: row.id, reduceMotion: reduceMotion)) }
                        }
                    }
```

Replace the `#Preview` block with:
```swift
#Preview {
    let repository = InMemoryTasksRepository()
    TaskListView(viewModel: TaskListViewModel(
        fetchTasks: DefaultFetchTasksUseCase(repository: repository),
        toggleTask: DefaultToggleTaskUseCase(repository: repository)
    ).eraseToAnyViewModel())
}
```

- [ ] **Step 6: Update `UIFactory.swift`**

Replace the full contents of `ToDo.UDF.MVVM/UI/Flow/UIFactory.swift` with:
```swift
//
//  UIFactory.swift
//  ToDo.UDF.MVVM
//
//  Будує ViewModel-и фічі з набору use cases та інжектить onEffect-колбек.
//

import Foundation

@MainActor
protocol UIFactory {
    func taskCreatedViewModel(
        task: TaskSummary,
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> TaskCreatedViewModel

    func taskListViewModel(
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> TaskListViewModel

    func newTaskViewModel(
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> NewTaskViewModel
}

@MainActor
final class DefaultUIFactory: UIFactory {
    private let useCases: TasksUseCases

    init(useCases: TasksUseCases) {
        self.useCases = useCases
    }

    func taskCreatedViewModel(
        task: TaskSummary,
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> TaskCreatedViewModel {
        TaskCreatedViewModel(task: task, onEffect: onEffect)
    }

    func taskListViewModel(
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> TaskListViewModel {
        TaskListViewModel(
            fetchTasks: useCases.fetchTasks,
            toggleTask: useCases.toggleTask,
            onEffect: onEffect
        )
    }

    func newTaskViewModel(
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> NewTaskViewModel {
        NewTaskViewModel(onEffect: onEffect)
    }
}
```
Note: `newTaskViewModel` still builds the current `NewTaskViewModel(onEffect:)` — Task 7 switches it to the use-case init.

- [ ] **Step 7: Update `TaskFlowCoordinator.swift`**

Replace the full contents of `ToDo.UDF.MVVM/UI/Flow/TaskFlowCoordinator.swift` with:
```swift
//
//  TaskFlowCoordinator.swift
//  ToDo.UDF.MVVM
//

import SwiftUI

@MainActor
@Observable
final class TaskFlowCoordinator: Coordinator {
    let router = Router()

    @ObservationIgnored private let factory: UIFactory

    init(factory: UIFactory) {
        self.factory = factory
    }

    convenience init() {
        self.init(factory: DefaultUIFactory(useCases: DataAssembly.makeLiveUseCases()))
    }

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

    func makeTaskCreatedViewModel(
        task: TaskSummary
    ) -> AnyUdfViewModel<TaskCreatedView.Props, TaskCreatedView.SyncEvent, TaskCreatedView.AsyncEvent> {
        factory
            .taskCreatedViewModel(task: task, onEffect: { [weak self] effect in self?.handle(effect) })
            .eraseToAnyViewModel()
    }

    func makeTaskListViewModel() -> AnyUdfViewModel<TaskListView.Props, TaskListView.SyncEvent, TaskListView.AsyncEvent> {
        factory
            .taskListViewModel(onEffect: { [weak self] effect in self?.handle(effect) })
            .eraseToAnyViewModel()
    }

    func makeNewTaskViewModel() -> AnyUdfViewModel<NewTaskView.Props, NewTaskView.SyncEvent, NewTaskView.AsyncEvent> {
        factory
            .newTaskViewModel(onEffect: { [weak self] effect in self?.handle(effect) })
            .eraseToAnyViewModel()
    }
}
```

- [ ] **Step 8: Run the suite to verify green**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.3'`
Expected: `** TEST SUCCEEDED **` — all suites pass (NewTask suite still on its current API; `TaskFlowView` compiles via `convenience init()`).

- [ ] **Step 9: Commit**

```bash
git add ToDo.UDF.MVVM/UI/TaskList ToDo.UDF.MVVM/UI/Flow ToDo.UDF.MVVMTests/TaskListViewModelTests.swift ToDo.UDF.MVVMTests/UIFactoryTests.swift ToDo.UDF.MVVMTests/TaskFlowCoordinatorTests.swift
git commit -m "$(cat <<'EOF'
feat: rewire TaskList onto use cases + use-case-driven DI

List VM now loads via FetchTasksUseCase on .load and toggles via
ToggleTaskUseCase (both async); UIFactory is built from a TasksUseCases
bundle; TaskFlowCoordinator takes an injected factory with a live
convenience init. NewTask path unchanged (Task 7).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Rewire the new-task path

**Files:**
- Create: `ToDo.UDF.MVVM/UI/Shared/TaskTimeFormatter.swift`
- Modify: `ToDo.UDF.MVVM/UI/NewTask/NewTaskProps.swift`
- Modify: `ToDo.UDF.MVVM/UI/NewTask/NewTaskViewModel.swift`
- Modify: `ToDo.UDF.MVVM/UI/NewTask/NewTaskView.swift`
- Modify: `ToDo.UDF.MVVM/UI/Flow/UIFactory.swift`
- Modify: `ToDo.UDF.MVVMTests/NewTaskViewModelTests.swift`

**Interfaces:**
- Consumes: `AddTaskUseCase`, `DefaultAddTaskUseCase`, `InMemoryTasksRepository`, `TodoTask`, `TaskTimeFormatter`, `useCases.addTask` (Task 6 factory bundle).
- Produces: `enum TaskTimeFormatter { static func string(from: Date) -> String }`; `NewTaskView.AsyncEvent { case save }`, `SyncEvent` without `.saveTapped`; `NewTaskViewModel.init(addTask: any AddTaskUseCase, onEffect:)`.

- [ ] **Step 1: Rewrite `NewTaskViewModelTests.swift` (the failing spec)**

Replace `ToDo.UDF.MVVMTests/NewTaskViewModelTests.swift` with:
```swift
import Testing
import Foundation
@testable import ToDo_UDF_MVVM

@MainActor
struct NewTaskViewModelTests {
    private func makeViewModel(
        repository: InMemoryTasksRepository = InMemoryTasksRepository(seed: []),
        onEffect: @escaping (CoordinatorEffect) -> Void = { _ in }
    ) -> NewTaskViewModel {
        NewTaskViewModel(addTask: DefaultAddTaskUseCase(repository: repository), onEffect: onEffect)
    }

    @Test func fieldEventsUpdateProps() {
        let vm = makeViewModel()
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
        let vm = makeViewModel()
        let newTime = Date(timeIntervalSince1970: 1_000_000)
        vm.onEvent(.timeChanged(newTime))
        #expect(vm.props.time == newTime)
    }

    @Test func emptyTitleDisablesCanSave() {
        let vm = makeViewModel()
        #expect(vm.props.canSave)               // демо-title непорожній
        vm.onEvent(.titleChanged("   "))
        #expect(!vm.props.canSave)
        vm.onEvent(.titleChanged("Назва"))
        #expect(vm.props.canSave)
    }

    @Test func timePickerEventsToggleFlag() {
        let vm = makeViewModel()
        vm.onEvent(.timePickerOpened)
        #expect(vm.props.isPickingTime)
        vm.onEvent(.timePickerClosed)
        #expect(!vm.props.isPickingTime)
    }

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

    @Test func saveMapsDefaultTimeToHHmm() async throws {
        let repository = InMemoryTasksRepository(seed: [])
        let vm = makeViewModel(repository: repository)
        await vm.onAsyncEvent(.save)                // демо-title непорожній, час 09:30
        let stored = try await repository.fetchAll()
        #expect(stored[0].time == "09:30")
    }

    @Test func saveDoesNotPersistWhenInvalid() async throws {
        let repository = InMemoryTasksRepository(seed: [])
        var received: CoordinatorEffect?
        let vm = makeViewModel(repository: repository, onEffect: { received = $0 })
        vm.onEvent(.titleChanged(""))
        await vm.onAsyncEvent(.save)
        #expect(try await repository.fetchAll().isEmpty)
        #expect(received == nil)
    }

    @Test func backTappedEmitsDismiss() {
        var received: CoordinatorEffect?
        let vm = makeViewModel(onEffect: { received = $0 })
        vm.onEvent(.backTapped)
        #expect(received == .dismissForm)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.3' -only-testing:ToDo.UDF.MVVMTests/NewTaskViewModelTests`
Expected: `** TEST BUILD FAILED **` — `NewTaskViewModel(addTask:onEffect:)` and `.save` (async) do not exist; `.saveTapped` removed.

- [ ] **Step 3: Create `TaskTimeFormatter.swift`**

Create `ToDo.UDF.MVVM/UI/Shared/TaskTimeFormatter.swift`:
```swift
//
//  TaskTimeFormatter.swift
//  ToDo.UDF.MVVM
//
//  Спільне форматування часу задачі: Date → "HH:mm".
//

import Foundation

enum TaskTimeFormatter {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}
```

- [ ] **Step 4: Update `NewTaskProps.swift`**

Replace the full contents of `ToDo.UDF.MVVM/UI/NewTask/NewTaskProps.swift` with:
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
        case backTapped
    }

    enum AsyncEvent: Equatable {
        case save
    }
}
```

- [ ] **Step 5: Update `NewTaskViewModel.swift`**

Replace the full contents of `ToDo.UDF.MVVM/UI/NewTask/NewTaskViewModel.swift` with:
```swift
//
//  NewTaskViewModel.swift
//  ToDo.UDF.MVVM
//
//  UDF-ViewModel форми створення задачі. Зберігає через AddTaskUseCase.
//

import SwiftUI

@MainActor
@Observable
final class NewTaskViewModel: UdfViewModel {
    typealias Props = NewTaskView.Props
    typealias SyncEvent = NewTaskView.SyncEvent
    typealias AsyncEvent = NewTaskView.AsyncEvent

    private(set) var props: Props

    @ObservationIgnored private let addTask: any AddTaskUseCase
    @ObservationIgnored private let onEffect: (CoordinatorEffect) -> Void

    init(
        addTask: any AddTaskUseCase,
        onEffect: @escaping (CoordinatorEffect) -> Void = { _ in }
    ) {
        self.addTask = addTask
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
        case .backTapped:             onEffect(.dismissForm)
        }
    }

    func onAsyncEvent(_ event: AsyncEvent) async {
        switch event {
        case .save:
            guard props.canSave else { return }
            let task = TodoTask(
                title: props.title,
                notes: props.notes.isEmpty ? nil : props.notes,
                time: TaskTimeFormatter.string(from: props.time),
                priority: props.priority
            )
            do {
                try await addTask(task)
                onEffect(.saveRequested)
            } catch {
                // #4: title уже захищений canSave; показ помилки/навігація — у #5.
            }
        }
    }

    private static func canSave(title: String) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static var defaultTime: Date {
        Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: Date()) ?? Date()
    }
}
```
Note: `when` is captured in props but intentionally not mapped into `TodoTask`.

- [ ] **Step 6: Update `NewTaskView.swift`**

Change the save button from:
```swift
                Button("Зберегти") { viewModel.onEvent(.saveTapped) }
```
to:
```swift
                Button("Зберегти") { Task { await viewModel.onAsync(.save) } }
```

Replace both `Self.timeString(viewModel.props.time)` call sites (inside the `TimeBadge(time:)` argument and the `.accessibilityValue(...)`) with:
```swift
TaskTimeFormatter.string(from: viewModel.props.time)
```

Delete the two private static members at the bottom of the struct (no longer used):
```swift
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static func timeString(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
```

Replace the `#Preview` block with:
```swift
#Preview {
    NewTaskView(viewModel: NewTaskViewModel(
        addTask: DefaultAddTaskUseCase(repository: InMemoryTasksRepository())
    ).eraseToAnyViewModel())
}
```

- [ ] **Step 7: Update `UIFactory.swift` — build the new-task VM via the use case**

In `ToDo.UDF.MVVM/UI/Flow/UIFactory.swift`, change the `newTaskViewModel` body from:
```swift
    func newTaskViewModel(
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> NewTaskViewModel {
        NewTaskViewModel(onEffect: onEffect)
    }
```
to:
```swift
    func newTaskViewModel(
        onEffect: @escaping (CoordinatorEffect) -> Void
    ) -> NewTaskViewModel {
        NewTaskViewModel(addTask: useCases.addTask, onEffect: onEffect)
    }
```

- [ ] **Step 8: Run the full suite to verify green**

Run: `xcodebuild test -scheme 'ToDo.UDF.MVVM' -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.3'`
Expected: `** TEST SUCCEEDED **` — every suite passes, including the unchanged `UIFactoryTests`/`TaskFlowCoordinatorTests` (the new-task VM still exposes `canSave`/`backTapped`).

- [ ] **Step 9: Commit**

```bash
git add ToDo.UDF.MVVM/UI/Shared/TaskTimeFormatter.swift ToDo.UDF.MVVM/UI/NewTask ToDo.UDF.MVVM/UI/Flow/UIFactory.swift ToDo.UDF.MVVMTests/NewTaskViewModelTests.swift
git commit -m "$(cat <<'EOF'
feat: rewire NewTask onto AddTaskUseCase

Save is now an async event that maps form props to a TodoTask
(Date->"HH:mm" via shared TaskTimeFormatter, empty notes->nil, when
dropped) and persists via AddTaskUseCase before emitting .saveRequested.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Done

All seven tasks complete the Domain/Data foundation. The three screens behave as before, now backed by a SwiftData repository through use cases; tasks persist. Navigation, save→list refresh, success, the full coordinator lifecycle, the App-root switch, and deletion of `Item.swift`/`ContentView.swift` are sub-project #5.

**Final whole-branch review focus:** layer dependency direction (Domain imports nothing from Data/Presentation); no Combine; `@ObservationIgnored` on all VM deps; the `TaskFlowCoordinator.convenience init()` → `DataAssembly` transitional seam (intended, removed in #5); `Tasks.store` distinct-URL coexistence with the template `Item` store; all suites green.
