import Testing
@testable import ToDo_UDF_MVVM

@MainActor
struct AnyUdfViewModelTests {
    @Test func forwardsLiveProps() {
        let mock = MockUdfViewModel<Int, String, String>(0)
        let erased = mock.eraseToAnyViewModel()
        #expect(erased.props == 0)
        mock.props = 42
        #expect(erased.props == 42)
    }

    @Test func onAsyncDoesNotCrash() async {
        let mock = MockUdfViewModel<Int, String, String>(1)
        let erased = mock.eraseToAnyViewModel()
        erased.onEvent("noop")
        await erased.onAsync("noop")
        #expect(erased.props == 1)
    }
}
