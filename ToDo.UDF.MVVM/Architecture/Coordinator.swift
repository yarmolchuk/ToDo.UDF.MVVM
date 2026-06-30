import Foundation

@MainActor
protocol Coordinator: AnyObject {
    var onComplete: (any Coordinator) -> Void { get }
    func start()
}
