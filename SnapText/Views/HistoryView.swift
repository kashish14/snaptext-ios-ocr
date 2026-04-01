import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No Scans Yet",
                systemImage: "clock",
                description: Text("Your scan history will appear here.\nPersistent history coming in a future update.")
            )
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    HistoryView()
}
