import SwiftUI

struct ContentView: View {
    // Podmień na adres, który ma się wczytywać
    let url = URL(string: "https://tpsprebeta.integra.com.pl/ClientScheduler?pointOfServiceCode=TEST-AC")!

    @State private var didFail = false
    @State private var reloadTrigger = 0

    var body: some View {
        ZStack {
            WebView(url: url, didFail: $didFail, reloadTrigger: reloadTrigger)

            // Natywny widok błędu — pokazuje się NA WIERZCHU strony,
            // więc nawet jeśli pod spodem jest pusta/zepsuta zawartość,
            // użytkownik widzi tylko ten ekran z przyciskiem Odśwież.
            if didFail {
                LoadErrorView {
                    reloadTrigger += 1 // to jedyny sposób na przeładowanie — zawsze z ręki użytkownika
                }
            }
        }
        .ignoresSafeArea() // pełny ekran, bez żadnych pasków systemowych
    }
}

#Preview {
    ContentView()
}