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
}
