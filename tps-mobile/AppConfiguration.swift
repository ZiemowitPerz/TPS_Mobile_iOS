import SwiftUI

enum AppConfiguration {

    static var webURL: URL {
        guard
            let value = Bundle.main.object(
                forInfoDictionaryKey: "APP_WEB_URL"
            ) as? String,
            let url = URL(string: value)
        else {
            fatalError("APP_WEB_URL is missing or invalid")
        }

        return url
    }

    /// Domeny, na które WebView może nawigować — czyli sam host startowy
    /// (`APP_WEB_URL`) plus ewentualne dodatkowe hosty, np. domena, na którą
    /// serwer przekierowuje (domena1/ems → domena2/ems).
    ///
    /// Dodatkowe hosty ustaw w Info.plist pod kluczem `APP_ADDITIONAL_ALLOWED_HOSTS`
    /// jako string z hostami rozdzielonymi przecinkiem, np.:
    /// "domena2.pl, api.domena2.pl"
    /// Klucz jest opcjonalny — jeśli go nie ma, dozwolony jest tylko host z APP_WEB_URL.
    static var allowedHosts: [String] {
        var hosts: [String] = []

        if let startHost = webURL.host {
            hosts.append(startHost)
        } else {
            #if DEBUG
            print("AppConfiguration: webURL.host is nil for \(webURL) — sprawdź, czy APP_WEB_URL zawiera pełny schemat, np. \"https://domena1.pl/ems/\" (nie samo \"domena1.pl/ems/\")")
            #endif
        }

        // Preferowany format: prawdziwa tablica w Info.plist (typ Array, elementy String).
        // Jest odporna na przecinki/spacje — nie ma nic do parsowania, więc nie może
        // "zjeść" wpisów przez podmianę zmiennej Build Settings czy literówkę w separatorze.
        if let array = Bundle.main.object(forInfoDictionaryKey: "APP_ADDITIONAL_ALLOWED_HOSTS") as? [String] {
            let cleaned = array
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            hosts.append(contentsOf: cleaned)
        }
        // Fallback: string rozdzielany przecinkami (starszy format / wygodny do szybkich testów)
        else if let raw = Bundle.main.object(forInfoDictionaryKey: "APP_ADDITIONAL_ALLOWED_HOSTS") as? String {
            let additional = raw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            hosts.append(contentsOf: additional)
        }

        #if DEBUG
        print("AppConfiguration.allowedHosts = \(hosts)")
        #endif

        return hosts
    }
}