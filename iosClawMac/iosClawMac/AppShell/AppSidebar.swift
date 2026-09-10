import SwiftUI

struct AppSidebar: View {
    @Binding var selection: WorkspaceDestination?
    @ObservedObject var session: MirrorSession
    @Environment(\.colorScheme) private var colorScheme

    private let operateDestinations: [WorkspaceDestination] = [.inspect, .devices]
    private let buildDestinations: [WorkspaceDestination] = [.compiledFlows, .recordReplay, .qaMode]
    private let workspaceDestinations: [WorkspaceDestination] = [.learnedContext, .audit]

    var body: some View {
        List(selection: $selection) {
            Section {
                sidebarIdentity
            }

            Section("Operate") {
                destinationLinks(operateDestinations)
            }

            if session.isRecording {
                Section("Active recording") {
                    recordingStatus
                }
            }

            Section("Build & verify") {
                destinationLinks(buildDestinations)
            }

            Section("Workspace") {
                destinationLinks(workspaceDestinations)
            }

            Section {
                destinationLink(.settings)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(AppTheme.sidebar(for: colorScheme))
        .safeAreaInset(edge: .bottom) {
            localControlFooter
        }
        .accessibilityLabel("iosClaw navigation")
    }

    private var sidebarIdentity: some View {
        VStack(alignment: .leading, spacing: AppTheme.spaceM) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("iosClaw")
                        .font(.headline)
                    Text("Local device workspace")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: AppIcon.brand)
                    .font(.title2)
                    .foregroundStyle(AppTheme.action)
            }

            HStack(spacing: AppTheme.spaceS) {
                Image(systemName: sourceStatusIcon)
                    .foregroundStyle(sourceStatusColor)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.activeSource?.title ?? "No device connected")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(sourceStatusTitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Device status")
            .accessibilityValue("\(session.activeSource?.title ?? "No device connected"), \(sourceStatusTitle)")
            .accessibilityHint(session.status)
        }
        .padding(.vertical, AppTheme.spaceXS)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func destinationLinks(_ destinations: [WorkspaceDestination]) -> some View {
        ForEach(destinations) { destination in
            destinationLink(destination)
        }
    }

    private func destinationLink(_ destination: WorkspaceDestination) -> some View {
        NavigationLink(value: destination) {
            Label(destination.title, systemImage: destination.symbol)
        }
        .accessibilityLabel(destination.title)
        .accessibilityHint(destinationHint(for: destination))
    }

    private var recordingStatus: some View {
        VStack(alignment: .leading, spacing: AppTheme.spaceM) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.recordingName ?? "Recording")
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text("\(session.recordingSteps.count) actions captured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: AppIcon.recordActive)
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Recording \(session.recordingName ?? "untitled flow")")
            .accessibilityValue("\(session.recordingSteps.count) actions captured")

            HStack(spacing: AppTheme.spaceS) {
                Button("Stop & save") { session.stopRecording() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(session.recordingSteps.isEmpty)
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                    .accessibilityHint(
                        session.recordingSteps.isEmpty
                            ? "Capture at least one action before saving"
                            : "Stops recording and saves this flow"
                    )

                Button("Cancel", role: .destructive) { session.cancelRecording() }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .keyboardShortcut(.escape, modifiers: [.command])
                    .accessibilityLabel("Cancel recording")
                    .accessibilityHint("Discards the current recording")
            }
        }
        .padding(.vertical, AppTheme.spaceXS)
        .accessibilityElement(children: .contain)
    }

    private var localControlFooter: some View {
        HStack(alignment: .top, spacing: AppTheme.spaceS) {
            Image(systemName: AppIcon.protectedStorage)
                .foregroundStyle(AppTheme.success)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text("Control stays local")
                    .font(.caption.weight(.semibold))
                Text("Actions require your approval")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.spaceM)
        .padding(.vertical, AppTheme.spaceS)
        .background(AppTheme.sidebar(for: colorScheme))
        .overlay(alignment: .top) {
            Divider()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Privacy and control")
        .accessibilityValue("Control stays local. Actions require your approval.")
    }

    private var sourceStatusTitle: String {
        switch session.sourceHealth {
        case .idle: "Ready to connect"
        case .missing: "Device unavailable"
        case .permissionRequired: "Permission required"
        case .capturing: "Refreshing context"
        case .ready: "Ready"
        case .interrupted: "Connection interrupted"
        case .failed: "Needs attention"
        }
    }

    private var sourceStatusIcon: String {
        switch session.sourceHealth {
        case .ready: AppIcon.ready
        case .capturing: AppIcon.refresh
        case .idle, .missing, .permissionRequired, .interrupted, .failed: AppIcon.attention
        }
    }

    private var sourceStatusColor: Color {
        switch session.sourceHealth {
        case .ready: AppTheme.success
        case .capturing: AppTheme.action
        case .idle, .missing, .permissionRequired, .interrupted, .failed: AppTheme.warning
        }
    }

    private func destinationHint(for destination: WorkspaceDestination) -> String {
        switch destination {
        case .inspect: "Inspect and control the selected device"
        case .devices: "Manage available device sources"
        case .compiledFlows: "Create and run reusable flows"
        case .recordReplay: "Record, review, and replay actions"
        case .qaMode: "Run deterministic device checks"
        case .learnedContext: "Review context learned on this Mac"
        case .audit: "Review local activity and safe stops"
        case .settings: "Manage permissions and workspace preferences"
        }
    }
}
