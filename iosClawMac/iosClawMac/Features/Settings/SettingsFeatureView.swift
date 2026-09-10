import SwiftUI

struct SettingsFeatureView: View {
    @ObservedObject var session: MirrorSession
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.pageSectionSpacing) {
                AppPageHeader(
                    title: "Settings",
                    subtitle: "Manage device defaults, privacy access, and local workspace information."
                )

                AppPanel(emphasis: .quiet) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Device defaults")
                            .font(.title3.weight(.semibold))
                        LabeledContent("Preferred source") {
                            Picker("Preferred source", selection: $session.captureSource) {
                                ForEach(ScreenSource.allCases) { source in
                                    Text(source.title).tag(source)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 220)
                        }
                        .accessibilityHint("Selects the default device source for future inspections")
                        Text("Automatic prefers iPhone Mirroring and safely falls back to a running simulator.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                AppPanel(emphasis: .quiet) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text("Privacy access")
                                .font(.title3.weight(.semibold))
                            Spacer()
                            Button("Refresh", systemImage: AppIcon.refresh, action: session.refreshPermissions)
                        }
                        AppPermissionRow(
                            title: "Screen Recording",
                            detail: "Required only to observe the selected device window.",
                            granted: session.screenCaptureAllowed,
                            actionTitle: "Open settings",
                            action: session.openScreenRecordingSettings
                        )
                        Divider()
                        AppPermissionRow(
                            title: "Accessibility",
                            detail: "Required only for verified taps, typing, and gestures.",
                            granted: session.accessibilityAllowed,
                            actionTitle: "Open settings",
                            action: session.openAccessibilitySettings
                        )
                    }
                }

                AppPanel(emphasis: .truth) {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Your workspace stays on this Mac", systemImage: AppIcon.protectedStorage)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Saved flows, learned context, and audit events are encrypted locally. Temporary inputs are supplied for a run and are not written into compiled flows.")
                            .foregroundStyle(.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 26) {
                            metric("\(session.recordedFlows.count)", "recordings")
                            metric("\(session.learnedFacts.count)", "learned facts")
                            metric("\(session.auditEvents.count)", "audit events")
                        }
                    }
                }
            }
            .padding(AppTheme.pagePadding)
        }
        .background(AppTheme.canvas(for: colorScheme))
        .navigationTitle("Settings")
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
        }
    }
}
