import SwiftUI

struct ContentView: View {
    // Podmień na adres, który ma się wczytywać
    let url = URL(string: "https://tpsprebeta.integra.com.pl/ClientScheduler?pointOfServiceCode=TEST-AC")!

    var body: some View {
        WebView(url: url)
            .ignoresSafeArea() // pełny ekran, bez żadnych pasków systemowych
    }
}

#Preview {
    ContentView()
}