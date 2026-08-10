import SwiftUI
 
@main
struct MinimalWebViewApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .statusBar(hidden: true) // pełny ekran, bez paska statusu
        }
    }
}