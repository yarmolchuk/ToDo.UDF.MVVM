import Foundation

@MainActor
enum TaskFlowFeature {
    struct Dependencies {
        let router: Router
        let factory: @MainActor (Dependencies) -> UIFactory

        static func live(router: Router, useCases: TasksUseCases) -> Self {
            Dependencies(router: router, factory: { _ in DefaultUIFactory(useCases: useCases) })
        }
    }
}
