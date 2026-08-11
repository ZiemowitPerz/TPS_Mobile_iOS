import SwiftUI

struct ContentView: View {
    @State private var didFail = false
    @State private var reloadTrigger = 0

    var body: some View {
        ZStack {
            WebView(
                url: AppConfiguration.webURL,
                allowedHosts: AppConfiguration.allowedHosts,
                didFail: $didFail,
                reloadTrigger: reloadTrigger
            )

            if didFail {
                LoadErrorView {
                    reloadTrigger += 1
                }
            }
        }
        .ignoresSafeArea()
    }
}