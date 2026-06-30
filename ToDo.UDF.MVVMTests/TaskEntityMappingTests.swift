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
