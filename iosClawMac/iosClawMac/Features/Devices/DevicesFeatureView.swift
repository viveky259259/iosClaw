import SwiftUI

struct DevicesFeatureView: View {
    @ObservedObject var session: MirrorSession
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.pageSectionSpacing) {
                AppPageHeader(
                    title: "Devices",
                    subtitle: "Choose where iosClaw observes and acts. Every action remains bound to the current live source."
                )

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: AppTheme.spaceL) {
                        deviceInventory.frame(maxWidth: .infinity)
                        accessPanel.frame(width: 340)
                    }
                    VStack(alignment: .leading, spacing: AppTheme.spaceL) {
                        deviceInventory
                        accessPanel
                    }
                }

                AppPanel(emphasis: .quiet) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: AppIcon.information)
                            .font(.title2)
                            .foregroundStyle(statusColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current device state")
                                .font(.headline)
                            Text(session.status)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(AppTheme.pagePadding)
        }
        .background(AppTheme.canvas(for: colorScheme))
        .navigationTitle("Devices")
    }

    private var deviceInventory: some View {
        AppPanel(emphasis: .quiet) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available devices")
                        .font(.title3.weight(.semibold))
                    Text("Use a mirrored iPhone or a local simulator.")
                        .foregroundStyle(.secondary)
                }

                deviceRow(
                    name: "iPhone Mirroring",
                    detail: "Nearby paired iPhone",
                    symbol: AppIcon.mirroredIPhone,
                    source: .iPhoneMirroring,
                    open: session.openIPhoneMirroring
                )
                deviceRow(
                    name: "iOS Simulator",
                    detail: "Local developer device",
                    symbol: AppIcon.simulator,
                    source: .simulator,
                    open: session.openSimulator
                )
            }
        }
    }

    private func deviceRow(
        name: String,
        detail: String,
        symbol: String,
        source: ScreenSource,
        open: @escaping () -> Void
    ) -> some View {
        let selected = session.captureSource == source || session.activeSource == source
        return HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(AppTheme.action)
                .frame(width: 42, height: 42)
                .background(AppTheme.action.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if selected {
                Label("Selected", systemImage: AppIcon.selected)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.success)
            } else {
                Button("Use") { session.captureSource = source }
            }
            Button("Open", action: open)
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(selected ? AppTheme.action.opacity(0.075) : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var accessPanel: some View {
        AppPanel(emphasis: .quiet) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Access & capabilities")
                    .font(.title3.weight(.semibold))

                AppPermissionRow(
                    title: "Screen Recording",
                    detail: "Reads the selected device window locally.",
                    granted: session.screenCaptureAllowed,
                    actionTitle: session.screenCaptureAllowed ? "Settings" : "Allow",
                    action: session.screenCaptureAllowed ? session.openScreenRecordingSettings : session.requestScreenRecording
                )

                Divider()

                AppPermissionRow(
                    title: "Accessibility",
                    detail: "Sends verified input only after live validation.",
                    granted: session.accessibilityAllowed,
                    actionTitle: "Settings",
                    action: session.openAccessibilitySettings
                )

                Divider()

                Picker("Preferred source", selection: $session.captureSource) {
                    ForEach(ScreenSource.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }

                HStack {
                    Button("Boot simulator", action: session.bootDefaultSimulator)
                    Spacer()
                    Button("Inspect", systemImage: AppIcon.inspect, action: session.inspect)
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.action)
                        .disabled(session.isCompiledFlowRunning)
                }
            }
        }
    }

    private var statusColor: Color {
        switch session.sourceHealth {
        case .ready: AppTheme.success
        case .failed, .interrupted, .permissionRequired: AppTheme.warning
        default: AppTheme.action
        }
    }
}
