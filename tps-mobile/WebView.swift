import SwiftUI
import WebKit

/// Cienki wrapper na WKWebView. W przeciwieństwie do SFSafariViewController
/// (który zawsze ma pasek nawigacji na górze), WKWebView nie ma żadnego
/// paska Safari — jest to "goły" widok strony, więc nic tu nie trzeba ukrywać.
struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var didFail: Bool
    let reloadTrigger: Int // zmiana tej wartości = użytkownik nacisnął "Odśwież"

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Pozwala odtwarzać wideo/audio bez dodatkowych barier
        config.allowsInlineMediaPlayback = true

        // Wstrzykujemy własny meta viewport (blokuje zoom nawet na stronach,
        // które same nie ustawiają "user-scalable=no") oraz CSS, który wyłącza
        // typowo "webowe" zachowania: zaznaczanie tekstu, lupę przy zaznaczaniu,
        // menu kontekstowe po długim przytrzymaniu i callout przy linkach/obrazkach.
        let disableWebBehaviorsScript = """
        var meta = document.querySelector('meta[name="viewport"]');
        if (!meta) {
            meta = document.createElement('meta');
            meta.name = 'viewport';
            document.head.appendChild(meta);
        }
        meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';

        var style = document.createElement('style');
        style.innerHTML = `
            * {
                -webkit-touch-callout: none !important;
                -webkit-user-select: none !important;
                user-select: none !important;
                -webkit-tap-highlight-color: transparent !important;
            }
        `;
        document.head.appendChild(style);
        """
        let userScript = WKUserScript(
            source: disableWebBehaviorsScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(userScript)

        // Wyłącza rozpoznawanie numerów telefonu / adresów / dat jako linki
        // (te "chipy" też są typowo webowe, nie pasują do natywnej appki)
        config.dataDetectorTypes = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // Wyłączamy szczypanie (pinch-to-zoom) na poziomie samego gestu —
        // to najpewniejszy sposób, bo działa niezależnie od zawartości strony
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        webView.scrollView.bouncesZoom = false
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.minimumZoomScale = 1.0

        // Wyłącza zoom przez podwójne stuknięcie
        for recognizer in webView.gestureRecognizers ?? [] {
            if let tap = recognizer as? UITapGestureRecognizer, tap.numberOfTapsRequired == 2 {
                tap.isEnabled = false
            }
        }

        // Wyłącza swipe od krawędzi (cofnij/dalej) — w natywnych appkach
        // nawigację robi się przyciskami, nie gestem znanym z Safari
        webView.allowsBackForwardNavigationGestures = false

        // Wyłącza "gumowe" odbicie przy przewinięciu poza granice strony
        // (rubber-banding kojarzy się mocno z przeglądarką/web-widokiem)
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false

        // Wyłącza podgląd linku po długim przytrzymaniu (peek/pop) i menu
        // "Otwórz / Skopiuj / Udostępnij", które pojawia się po long-pressie
        webView.allowsLinkPreview = false

        // Bez paska przewijania, żeby wyglądało bardziej jak natywna appka
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Przeładowujemy WYŁĄCZNIE gdy reloadTrigger się zmienił, czyli
        // gdy użytkownik sam nacisnął "Odśwież". Nigdy nie robimy tego
        // automatycznie — to zabezpieczenie przed pętlą (dead loop) przy
        // braku internetu: bez internetu przeładowanie i tak by się nie
        // udało, więc nie ma sensu próbować w kółko bez udziału użytkownika.
        if context.coordinator.lastReloadTrigger != reloadTrigger {
            context.coordinator.lastReloadTrigger = reloadTrigger
            didFail = false
            uiView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(didFail: $didFail)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var didFail: Binding<Bool>
        var lastReloadTrigger: Int = 0

        init(didFail: Binding<Bool>) {
            self.didFail = didFail
        }

        // Błąd zanim strona w ogóle zaczęła się ładować (typowy przypadek dla "brak internetu")
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard (error as NSError).code != NSURLErrorCancelled else { return } // normalne przy przekierowaniach, nie jest to prawdziwy błąd
            didFail.wrappedValue = true
        }

        // Błąd już w trakcie ładowania strony
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard (error as NSError).code != NSURLErrorCancelled else { return }
            didFail.wrappedValue = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            didFail.wrappedValue = false
        }

        // Miejsce na ewentualną obsługę popupów window.confirm/alert/prompt strony
        // Domyślnie zostawione zakomentowane, bo część stron ich potrzebuje do logowania/potwierdzeń.
        //
        // func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        //     completionHandler()
        // }
    }
}