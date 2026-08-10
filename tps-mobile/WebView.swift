import SwiftUI
import WebKit

/// Cienki wrapper na WKWebView. W przeciwieństwie do SFSafariViewController
/// (który zawsze ma pasek nawigacji na górze), WKWebView nie ma żadnego
/// paska Safari — jest to "goły" widok strony, więc nic tu nie trzeba ukrywać.
struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Pozwala odtwarzać wideo/audio bez dodatkowych barier
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        // Szczypanie (pinch-to-zoom) — włączone domyślnie w WKWebView,
        // ale ustawiamy jawnie na wszelki wypadek
        webView.scrollView.pinchGestureRecognizer?.isEnabled = true
        webView.scrollView.bouncesZoom = true
        webView.scrollView.maximumZoomScale = 5.0
        webView.scrollView.minimumZoomScale = 1.0

        // Gest "swipe od krawędzi" = cofnij / do przodu (jak w Safari)
        webView.allowsBackForwardNavigationGestures = true

        // Bez paska przewijania, żeby wyglądało bardziej jak natywna appka
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Nic do aktualizacji — URL ładujemy tylko raz przy starcie
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        // Miejsce na ewentualną obsługę błędów ładowania, np.:
        // func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { ... }
    }
}