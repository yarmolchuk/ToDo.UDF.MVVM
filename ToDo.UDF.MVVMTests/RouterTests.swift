import Testing
import SwiftUI
@testable import ToDo_UDF_MVVM

@MainActor
struct RouterTests {
    @Test func pushAppends() {
        let router = Router()
        #expect(router.path.isEmpty)
        router.push("a")
        #expect(router.path.count == 1)
    }

    @Test func popRemovesLast() {
        let router = Router()
        router.push("a")
        router.push("b")
        router.pop()
        #expect(router.path.count == 1)
    }

    @Test func popOnEmptyDoesNotCrash() {
        let router = Router()
        router.pop()
        #expect(router.path.isEmpty)
    }

    @Test func popToRootClears() {
        let router = Router()
        router.push("a")
        router.push("b")
        router.popToRoot()
        #expect(router.path.isEmpty)
    }
}
