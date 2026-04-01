import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            Tab("Scan", systemImage: "doc.text.viewfinder") {
                ScanView()
            }

            Tab("Tools", systemImage: "wrench.and.screwdriver") {
                ToolsView()
            }

            Tab("Clipboard", systemImage: "clipboard") {
                ClipboardHistoryView()
            }

            Tab("History", systemImage: "clock") {
                HistoryView()
            }
        }
        .tint(.blue)
        .onAppear {
            ClipboardManager.shared.modelContext = modelContext
            // Polished tab bar appearance
            let tabAppearance = UITabBarAppearance()
            tabAppearance.configureWithDefaultBackground()
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance
            UITabBar.appearance().standardAppearance = tabAppearance
        }
    }
}

#Preview {
    ContentView()
}
