import Foundation

extension TaskListView {
    struct Props: Equatable {
        var active: [TaskRow]
        var completed: [TaskRow]
        var progress: Double
        var headerDate: String
    }

    enum SyncEvent: Equatable {
        case addTapped
    }

    enum AsyncEvent: Equatable {
        case load
        case toggle(id: UUID, reduceMotion: Bool)
    }
}
