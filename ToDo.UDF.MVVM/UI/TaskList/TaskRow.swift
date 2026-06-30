import Foundation

struct TaskRow: Equatable, Identifiable {
    let id: UUID
    let title: String
    let notes: String?
    let time: String
    let priority: PriorityBadge
    let isDone: Bool

    enum PriorityBadge: Hashable, CaseIterable {
        case low
        case medium
        case high

        init(_ priority: TaskPriority) {
            switch priority {
            case .low: self = .low
            case .medium: self = .medium
            case .high: self = .high
            }
        }

        var title: String {
            switch self {
            case .low: "Низький"
            case .medium: "Середній"
            case .high: "Високий"
            }
        }
    }
}
