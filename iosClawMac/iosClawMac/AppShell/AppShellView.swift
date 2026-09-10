import SwiftUI

struct AppShellView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject private var session: MirrorSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        _session = ObservedObject(wrappedValue: coordinator.mirrorSession)
    }

    var body: some View {
        NavigationSplitView {
            AppSidebar(
                selection: $coordinator.destination,
                session: coordinator.mirrorSession
            )
            .navigationSplitViewColumnWidth(min: 76, ideal: 224, max: 260)
        } detail: {
            destinationView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.canvas(for: colorScheme))
        }
        .navigationSplitViewStyle(.balanced)
        .frame(
            minWidth: coordinator.destination == .inspect && coordinator.isInspectorPresented ? 1040 : 780,
            minHeight: 620
        )
        .background(AppTheme.canvas(for: colorScheme))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                CaptureSourceMenu(selection: Binding(
                    get: { session.captureSource },
                    set: { session.captureSource = $0 }
                ))
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    session.inspect()
                } label: {
                    Image(systemName: AppIcon.refresh)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 16, height: 16)
                }
                .accessibilityLabel("Refresh live context")
                .help("Refresh live context")
                .disabled(session.isCompiledFlowRunning)
            }
            ToolbarItem(placement: .principal) {
                AppStatusPill(
                    title: session.activeSource?.title ?? "No device",
                    isReady: session.sourceHealth == .ready
                )
                .help(session.status)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    coordinator.isInspectorPresented.toggle()
                } label: {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 16, height: 16)
                }
                .accessibilityLabel(coordinator.isInspectorPresented ? "Hide inspector" : "Show inspector")
                .help("Show or hide the inspector")
            }
        }
        .onAppear { coordinator.refreshAccess() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            coordinator.refreshAccess()
        }
        .sheet(isPresented: $coordinator.isCaptureViewerPresented) {
            if let preview = coordinator.mirrorSession.preview {
                CaptureImageViewer(
                    image: preview,
                    targets: coordinator.mirrorSession.textTargets,
                    zoom: $coordinator.captureZoom
                )
            }
        }
        .alert(
            "Approval required",
            isPresented: Binding(
                get: { coordinator.mirrorSession.pendingApproval != nil },
                set: { presented in
                    if !presented, coordinator.mirrorSession.pendingApproval != nil {
                        coordinator.mirrorSession.denyPendingAction()
                    }
                }
            ),
            presenting: coordinator.mirrorSession.pendingApproval
        ) { _ in
            Button("Cancel", role: .cancel) {
                coordinator.mirrorSession.denyPendingAction()
            }
            Button("Approve once") {
                coordinator.mirrorSession.approvePendingAction()
            }
        } message: { approval in
            Text("\(approval.effect.title): \(approval.actionDescription). This approval expires and can be used only once.")
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch coordinator.destination ?? .inspect {
        case .inspect:
            InspectionFeatureView(
                session: coordinator.mirrorSession,
                zoom: $coordinator.captureZoom,
                isViewerPresented: $coordinator.isCaptureViewerPresented,
                isInspectorPresented: $coordinator.isInspectorPresented
            )
        case .devices:
            DevicesFeatureView(session: coordinator.mirrorSession)
        case .compiledFlows:
            CompiledFlowsFeatureView(session: coordinator.mirrorSession)
        case .recordReplay:
            RecordReplayFeatureView(session: coordinator.mirrorSession)
        case .learnedContext:
            LearnedContextFeatureView(session: coordinator.mirrorSession)
        case .audit:
            AuditFeatureView(events: coordinator.mirrorSession.auditEvents)
        case .settings:
            SettingsFeatureView(session: coordinator.mirrorSession)
        case .qaMode:
            QAModeView(session: coordinator.qaSession)
        }
    }
}

private struct CaptureSourceMenu: View {
    @Binding var selection: ScreenSource

    var body: some View {
        Menu {
            ForEach(ScreenSource.allCases) { source in
                Button {
                    selection = source
                } label: {
                    if selection == source {
                        Label(source.title, systemImage: "checkmark")
                    } else {
                        Text(source.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectionSymbol)
                    .frame(width: 14, height: 14)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 8)
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .controlSize(.small)
        .frame(width: 42, height: 32)
        .fixedSize()
        .accessibilityLabel("Capture device")
        .accessibilityValue(selection.title)
        .help("Capture device: \(selection.title)")
    }

    private var selectionSymbol: String {
        switch selection {
        case .automatic:
            AppIcon.automaticSource
        case .iPhoneMirroring:
            AppIcon.mirroredIPhone
        case .simulator:
            AppIcon.devices
        }
    }

}
