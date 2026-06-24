//
//  Item.swift
//  ToDo.UDF.MVVM
//
//  Created by Yarmolchuk on 24.06.2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
