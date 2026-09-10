import SwiftUI

@main
struct iosClawCompanionApp: App {
    @StateObject private var store: AuditStore
    @StateObject private var bridge: PeerBridge

    init() {
        let store = AuditStore()
        _store = StateObject(wrappedValue: store)
        _bridge = StateObject(wrappedValue: PeerBridge(store: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store, bridge: bridge)
        }
    }
}
