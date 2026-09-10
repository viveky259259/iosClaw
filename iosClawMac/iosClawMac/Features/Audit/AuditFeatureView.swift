import SwiftUI

struct AuditFeatureView: View {
    let events: [AuditEvent]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.pageSectionSpacing) {
                AppPageHeader(
                    title: "Activity",
                    subtitle: "A private history of observations, permission changes, and actions that stopped safely."
                )

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: AppTheme.spaceL) {
                        timeline.frame(maxWidth: .infinity)
                        privacyPosture.frame(width: 310)
                    }
                    VStack(alignment: .leading, spacing: AppTheme.spaceL) {
                        timeline
                        privacyPosture
                    }
                }
            }
            .padding(AppTheme.pagePadding)
        }
        .background(AppTheme.canvas(for: colorScheme))
        .navigationTitle("Activity")
    }

    private var timeline: some View {
        AppPanel(emphasis: .quiet) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Activity timeline")
                            .font(.title3.weight(.semibold))
                        Text(timelineCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    AppStatusPill(title: "Encrypted locally", isReady: true)
                }

                if events.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: AppIcon.audit)
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("No activity yet").font(.headline)
                        Text("Inspection and safety events will appear here.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(recentEvents) { event in
                            eventRow(event)
                            if event.id != recentEvents.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func eventRow(_ event: AuditEvent) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Text(event.occurredAt, format: .dateTime.hour().minute())
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)
            Image(systemName: icon(for: event.kind))
                .foregroundStyle(color(for: event.kind))
                .frame(width: 24, height: 24)
                .background(color(for: event.kind).opacity(0.11), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(event.summary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(event.occurredAt, format: .dateTime.month().day().year())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 4)
            Text(title(for: event.kind))
                .font(.caption.weight(.semibold))
                .foregroundStyle(color(for: event.kind))
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(title(for: event.kind)): \(event.summary), \(event.occurredAt.formatted(date: .abbreviated, time: .shortened))"
        )
    }

    private var privacyPosture: some View {
        AppPanel(emphasis: .truth) {
            VStack(alignment: .leading, spacing: 21) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Privacy posture")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("What this history contains")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.56))
                }

                auditMetric("\(events.count)", "total local events", symbol: AppIcon.audit)
                auditMetric("\(count(.observation))", "screen observations", symbol: AppIcon.observed)
                auditMetric("\(count(.safety))", "safe stops", symbol: AppIcon.safeStop)

                Divider().overlay(.white.opacity(0.16))

                Label("Message bodies and typed values are not written to audit records.", systemImage: AppIcon.protectedStorage)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func auditMetric(_ value: String, _ label: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color(red: 0.38, green: 0.88, blue: 0.62))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.56))
            }
        }
    }

    private var recentEvents: [AuditEvent] {
        Array(events.prefix(200))
    }

    private var timelineCaption: String {
        events.count > recentEvents.count
            ? "Showing the latest \(recentEvents.count) of \(events.count) events"
            : "\(events.count) event\(events.count == 1 ? "" : "s") on this Mac"
    }

    private func count(_ kind: AuditEvent.Kind) -> Int {
        events.filter { $0.kind == kind }.count
    }

    private func icon(for kind: AuditEvent.Kind) -> String {
        switch kind {
        case .observation: AppIcon.observed
        case .permission: AppIcon.access
        case .safety: AppIcon.safeStop
        }
    }

    private func color(for kind: AuditEvent.Kind) -> Color {
        switch kind {
        case .observation: AppTheme.action
        case .permission: AppTheme.success
        case .safety: AppTheme.warning
        }
    }

    private func title(for kind: AuditEvent.Kind) -> String {
        switch kind {
        case .observation: "Observed"
        case .permission: "Access"
        case .safety: "Safe stop"
        }
    }
}
