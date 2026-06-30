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
