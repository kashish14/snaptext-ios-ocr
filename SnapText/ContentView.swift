import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Scan", systemImage: "doc.text.viewfinder") {
                ScanView()
            }

            Tab("History", systemImage: "clock") {
                HistoryView()
            }
        }
    }
}

#Preview {
    ContentView()
}
