//
//  AnyUdfViewModel.swift
//  ToDo.UDF.MVVM
//
//  Type-eraser над UdfViewModel. Замикання захоплюють @Observable base,
//  тож Observation відстежує props крізь обгортку.
//

import SwiftUI

@MainActor
final class AnyUdfViewModel<Props, SyncEvent, AsyncEvent> {
    private let propsGetter: () -> Props
    private let eventHandler: (SyncEvent) -> Void
    private let asyncHandler: (AsyncEvent) async -> Void

    init<Base: UdfViewModel>(_ base: Base)
    where Base.Props == Props, Base.SyncEvent == SyncEvent, Base.AsyncEvent == AsyncEvent {
        propsGetter = { base.props }
        eventHandler = { base.onEvent($0) }
        asyncHandler = { await base.onAsyncEvent($0) }
    }

    var props: Props { propsGetter() }
    func onEvent(_ event: SyncEvent) { eventHandler(event) }
    func onAsync(_ event: AsyncEvent) async { await asyncHandler(event) }
}
