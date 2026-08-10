import SwiftUI

struct LoadErrorView: View {
    let onReload: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 50))

            Text("Nie udało się wczytać strony")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Sprawdź połączenie z Internetem i spróbuj ponownie.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Odśwież") {
                onReload()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}