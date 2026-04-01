import SwiftUI
import Translation

struct TranslateButton: View {
    let text: String
    @State private var showTranslation = false

    var body: some View {
        Button {
            showTranslation = true
        } label: {
            Label("Translate", systemImage: "translate")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .translationPresentation(isPresented: $showTranslation, text: text)
    }
}
