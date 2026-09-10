import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var destination: WorkspaceDestination? = .inspect
    @Published var captureZoom: CGFloat = 1
    @Published var isCaptureViewerPresented = false
    @Published var isInspectorPresented = true

    let mirrorSession = MirrorSession()
    let qaSession = QASession()

    func refreshAccess() {
        mirrorSession.refreshPermissions()
    }
}

enum WorkspaceDestination: String, CaseIterable, Hashable, Identifiable {
    case inspect
    case devices
    case compiledFlows
    case recordReplay
    case learnedContext
    case audit
    case settings
    case qaMode

    var id: Self { self }

    var title: String {
        switch self {
        case .inspect: "Command"
        case .devices: "Devices"
        case .compiledFlows: "Flows"
        case .recordReplay: "Recordings"
        case .learnedContext: "Learned context"
        case .audit: "Activity"
        case .settings: "Settings"
        case .qaMode: "QA mode"
        }
    }

    var symbol: String {
        switch self {
        case .inspect: AppIcon.command
        case .devices: AppIcon.devices
        case .compiledFlows: AppIcon.flows
        case .recordReplay: AppIcon.recordings
        case .learnedContext: AppIcon.learnedContext
        case .audit: AppIcon.audit
        case .settings: AppIcon.settings
        case .qaMode: AppIcon.qaMode
        }
    }
}
