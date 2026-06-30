import Foundation

enum CoordinatorEffect: Equatable {
    case finishCreated
    case createTaskRequested
    case saveRequested(TaskSummary)
    case dismissForm
}
