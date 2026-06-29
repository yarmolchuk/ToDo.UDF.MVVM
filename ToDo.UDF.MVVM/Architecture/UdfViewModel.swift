//
//  UdfViewModel.swift
//  ToDo.UDF.MVVM
//
//  Ядро UDF: протокол ViewModel зі знімком стану (Props) та подіями.
//

import SwiftUI

@MainActor
protocol UdfViewModel: AnyObject {
    associatedtype Props
    associatedtype SyncEvent
    associatedtype AsyncEvent

    var props: Props { get }
    func onEvent(_ event: SyncEvent)
    func onAsyncEvent(_ event: AsyncEvent) async
}

extension UdfViewModel {
    func eraseToAnyViewModel() -> AnyUdfViewModel<Props, SyncEvent, AsyncEvent> {
        AnyUdfViewModel(self)
    }
}

@MainActor
@Observable
final class MockUdfViewModel<P, S, A>: UdfViewModel {
    var props: P
    init(_ props: P) { self.props = props }
    func onEvent(_ event: S) {}
    func onAsyncEvent(_ event: A) async {}
}
