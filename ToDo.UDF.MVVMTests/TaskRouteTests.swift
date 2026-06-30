import Testing
@testable import ToDo_UDF_MVVM

@MainActor
struct TaskRouteTests {
    @Test func routesAreHashableAndDistinct() {
        let set: Set<TaskRoute> = [.newTask, .created(.sample)]
        #expect(set.contains(.newTask))
        #expect(set.contains(.created(.sample)))
        #expect(set.count == 2)
    }

    @Test func createdRouteEqualsBySummary() {
        #expect(TaskRoute.created(.sample) == TaskRoute.created(.sample))
        #expect(TaskRoute.created(.sample) != TaskRoute.newTask)
    }
}
