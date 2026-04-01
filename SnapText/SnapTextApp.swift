//
//  SnapTextApp.swift
//  SnapText
//
//  Created by Kashish Agarwal on 01/04/26.
//

import SwiftUI
import SwiftData

@main
struct SnapTextApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [ScanHistoryItem.self, ClipboardItem.self])
    }
}
