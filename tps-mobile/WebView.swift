import SwiftUI
import WebKit

/// Cienki wrapper na WKWebView. W przeciwieństwie do SFSafariViewController
/// (który zawsze ma pasek nawigacji na górze), WKWebView nie ma żadnego
/// paska Safari — jest to "goły" widok strony, więc nic tu nie trzeba ukrywać.
struct WebView: UIViewRepresentable {
    let url: URL
    let allowedHosts: [String]
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
        Coordinator(didFail: $didFail, allowedHosts: allowedHosts)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var didFail: Binding<Bool>
        var lastReloadTrigger: Int = 0
        let allowedHosts: [String]

        init(didFail: Binding<Bool>, allowedHosts: [String]) {
            self.didFail = didFail
            self.allowedHosts = allowedHosts
        }

        /// Sprawdza, czy dany host jest na whiteliście — dopasowuje też
        /// subdomeny (np. "app.domena2.pl" przejdzie dla wpisu "domena2.pl"),
        /// ale nie dopasowuje przypadkowo "notdomena2.pl".
        private func isHostAllowed(_ host: String?) -> Bool {
            guard let host = host?.lowercased() else { return false }
            return allowedHosts.contains { allowed in
                let allowed = allowed.lowercased()
                return host == allowed || host.hasSuffix("." + allowed)
            }
        }

        // Kluczowe miejsce blokady: KAŻDA nawigacja (kliknięcie linku,
        // przekierowanie serwera, formularz, JS location change) przechodzi
        // przez tę metodę. Jeśli host nie jest na whiteliście — .cancel.
        // Dzięki temu przekierowanie domena1/ems → domena2/ems zadziała
        // (bo domena2 jest dopisana do allowedHosts), a próba wyjścia na
        // jakąkolwiek inną domenę zostanie zablokowana.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let requestURL = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            // Dopuszczamy tylko http/https — blokuje np. tel:, mailto:,
            // custom schematy próbujące otworzyć inne aplikacje
            guard requestURL.scheme == "https" || requestURL.scheme == "http" else {
                decisionHandler(.cancel)
                return
            }

            if isHostAllowed(requestURL.host) {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        }

        // Blokuje otwieranie linków w nowym oknie/karcie (target="_blank",
        // window.open z JS). Zamiast otwierać nowe okno (którego appka i tak
        // nie ma jak pokazać sensownie), ładujemy adres w TYM SAMYM WebView —
        // ale tylko jeśli host jest dozwolony; w przeciwnym razie link jest
        // po prostu ignorowany.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let requestURL = navigationAction.request.url, isHostAllowed(requestURL.host) {
                webView.load(navigationAction.request)
            }
            return nil // nigdy nie tworzymy nowego okna
        }

        // Błąd zanim strona w ogóle zaczęła się ładować (typowy przypadek
        // dla "brak internetu")
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

        // Miejsce na ewentualną obsługę popupów window.confirm/alert/prompt strony, jeśli
        // wolisz, żeby appka nigdy nie pokazywała "webowych" popupów —
        // domyślnie zostawione zakomentowane, bo część stron ich potrzebuje
        // do logowania/potwierdzeń. Odkomentuj w razie potrzeby:
        //
        // func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        //     completionHandler()
        // }
    }
}