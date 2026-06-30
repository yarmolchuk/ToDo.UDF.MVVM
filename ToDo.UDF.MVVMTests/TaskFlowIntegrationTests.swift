import Testing
import SwiftUI
@testable import ToDo_UDF_MVVM

@MainActor
struct TaskFlowIntegrationTests {
    private func makeCoordinator(seed: [TodoTask]) -> TaskFlowCoordinator {
        let router = Router()
        let useCases = DataAssembly.makeUseCases(repository: InMemoryTasksRepository(seed: seed))
        let dependencies = TaskFlowFeature.Dependencies.live(router: router, useCases: useCases)
        return TaskFlowCoordinator(dependencies: dependencies, onComplete: { _ in })
    }

    @Test func createSaveFinishFlow() async {
        let c = makeCoordinator(seed: [])
        await c.listViewModel.onAsync(.load)
        #expect(c.listViewModel.props.active.isEmpty)

        c.handle(.createTaskRequested)
        #expect(c.router.path.count == 1)

        let form = c.makeNewTaskViewModel()
        form.onEvent(.titleChanged("Купити молоко"))
        await form.onAsync(.save)
        #expect(c.router.path.count == 2)

        await c.listViewModel.onAsync(.load)
        #expect(c.listViewModel.props.active.contains { $0.title == "Купити молоко" })

        c.handle(.finishCreated)
        #expect(c.router.path.isEmpty)
    }
}
