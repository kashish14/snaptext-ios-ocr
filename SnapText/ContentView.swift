import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            Tab("Capture", systemImage: "viewfinder") {
                CaptureView()
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
