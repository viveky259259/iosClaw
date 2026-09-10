import SwiftUI

/// Compatibility entry point. App composition lives in AppShell so feature
/// views do not own cross-feature navigation or device session lifetimes.
struct ContentView: View {
    @StateObject private var coordinator = AppCoordinator()

    var body: some View {
        AppShellView(coordinator: coordinator)
    }
}
