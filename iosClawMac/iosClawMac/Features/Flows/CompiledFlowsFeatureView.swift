import SwiftUI

struct CompiledFlowsFeatureView: View {
    @ObservedObject var session: MirrorSession
    @Environment(\.colorScheme) private var colorScheme
    @State private var recipient = ""
    @State private var message = ""
    @State private var unreadLimit = 100

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.pageSectionSpacing) {
                AppPageHeader(
                    title: "Flow library",
                    subtitle: "Verified routines that run quickly without planning every step again."
                )

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: AppTheme.spaceL) {
                        library.frame(maxWidth: .infinity)
                        operationalSignal.frame(width: 300)
                    }
                    VStack(alignment: .leading, spacing: AppTheme.spaceL) {
                        library
                        operationalSignal
                    }
                }

                latestRun
            }
            .padding(AppTheme.pagePadding)
        }
        .background(AppTheme.canvas(for: colorScheme))
        .navigationTitle("Flows")
    }

    private var library: some View {
        AppPanel(emphasis: .quiet) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Ready to run")
                            .font(.title3.weight(.semibold))
                        Text("\(activeFlowCount) active flow\(activeFlowCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    AppStatusPill(title: "Local runtime", isReady: activeFlowCount > 0)
                }

                quickDraft
                Divider()
                unreadChatTriage
                Divider()

                ViewThatFits(in: .horizontal) {
                    VStack(spacing: 0) {
                        flowTableHeader
                        Divider()
                        ForEach(session.compiledFlowCatalog) { flow in
                            wideFlowRow(flow)
                            if flow.id != session.compiledFlowCatalog.last?.id { Divider() }
                        }
                    }
                    VStack(spacing: 0) {
                        ForEach(session.compiledFlowCatalog) { flow in
                            flowRow(flow)
                            if flow.id != session.compiledFlowCatalog.last?.id { Divider() }
                        }
                    }
                }
            }
        }
    }

    private var flowTableHeader: some View {
        HStack(spacing: 12) {
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("Status").frame(width: 90, alignment: .leading)
            Text("Stages").frame(width: 72, alignment: .leading)
            Text("Source").frame(width: 130, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)
    }

    private func wideFlowRow(_ flow: CompiledFlowPackage) -> some View {
        HStack(spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(flow.displayName).font(.headline)
                    Text("Version \(flow.version)").font(.caption2).foregroundStyle(.tertiary)
                }
            } icon: {
                Image(systemName: flow.intentID == "app.open" ? AppIcon.application : AppIcon.flow)
                    .foregroundStyle(AppTheme.action)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.action.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            AppStatusPill(title: flow.status.rawValue.capitalized, isReady: flow.status == .active)
                .frame(width: 90, alignment: .leading)
            Text("\(flow.steps.count)")
                .font(.callout.monospacedDigit())
                .frame(width: 72, alignment: .leading)
            Text(flow.supportedSources.map(\.title).joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 130, alignment: .leading)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private var quickDraft: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: AppIcon.message)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.action, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("WhatsApp draft")
                        .font(.headline)
                    Text("Find a live recipient and prepare a reviewed message.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Stops before Send")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.warning)
            }

            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("Recipient") {
                    TextField("Recipient", text: $recipient, prompt: Text("e.g. Honey"))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("Message") {
                    TextField("Message", text: $message, prompt: Text("Message to draft"), axis: .vertical)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                }
            }

            HStack {
                Text("Inputs are used only for this run.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if session.isCompiledFlowRunning {
                    ProgressView().controlSize(.small)
                    Text("Running locally…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Prepare draft", systemImage: AppIcon.compose) {
                    session.runCompiledFlowFromUI(
                        intentID: "messaging.draft",
                        inputs: [
                            "app": "WhatsApp Business",
                            "recipient": recipient.trimmingCharacters(in: .whitespacesAndNewlines),
                            "message": message.trimmingCharacters(in: .whitespacesAndNewlines)
                        ]
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.action)
                .disabled(!canRun)
            }
        }
        .padding(16)
        .background(.background.opacity(0.76), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var unreadChatTriage: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "text.badge.checkmark")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.success, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Unread chat triage")
                        .font(.headline)
                    Text("Scan up to 100 unread chats using WhatsApp's Unread filter or visible unread-count badges, then surface urgent, deadline, payment, work, or family signals.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Local only")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.success)
            }

            HStack {
                Stepper("Scan up to \(unreadLimit) unread chats", value: $unreadLimit, in: 1...100)
                    .font(.callout)
                Spacer()
                if session.isUnreadTriageRunning {
                    ProgressView().controlSize(.small)
                    Text("Scanning…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Scan unread chats", systemImage: "text.magnifyingglass") {
                    session.triageUnreadWhatsAppChats(limit: unreadLimit)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.success)
                .disabled(!canRunUnreadTriage)
            }

            Text("Start on WhatsApp's Chats tab. iosClaw uses the visible Unread filter when available, otherwise scans unread-count badges. It never opens a conversation, and results remain only while this app is open.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let result = session.unreadTriageResult {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(result.importantChats.count) important chat\(result.importantChats.count == 1 ? "" : "s") from \(result.scannedChatCount) scanned")
                        .font(.subheadline.weight(.semibold))
                    if result.importantChats.isEmpty {
                        Text("No visible unread previews matched the current priority signals.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(result.importantChats) { chat in
                            HStack(alignment: .top, spacing: 10) {
                                Text(chat.priority.rawValue.capitalized)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(chat.priority == .urgent ? AppTheme.warning : AppTheme.success)
                                    .frame(width: 48, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(chat.contact).font(.callout.weight(.semibold))
                                    Text(chat.preview)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                    Text(chat.matchedSignals.joined(separator: ", "))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .background(.background.opacity(0.62), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(16)
        .background(.background.opacity(0.76), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func flowRow(_ flow: CompiledFlowPackage) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: flow.intentID == "app.open" ? AppIcon.application : AppIcon.flow)
                .font(.title3)
                .foregroundStyle(AppTheme.action)
                .frame(width: 38, height: 38)
                .background(AppTheme.action.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(flow.displayName)
                    .font(.headline)
                Text("Version \(flow.version) · \(flow.steps.count) verified stages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(flow.supportedSources.map(\.title).joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            AppStatusPill(title: flow.status.rawValue.capitalized, isReady: flow.status == .active)
        }
        .padding(.vertical, 4)
    }

    private var operationalSignal: some View {
        AppPanel(emphasis: .truth) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Operational signal")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("What happens during a run")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.56))
                }

                signalMetric(
                    session.latestCompiledRun?.outcome == .succeeded ? "Reliable completion" : "Ready for verification",
                    session.latestCompiledRun == nil ? "No completed run yet" : "Latest run checked every stage",
                    symbol: AppIcon.verified
                )

                signalMetric(
                    latestDuration,
                    "Latest local run",
                    symbol: AppIcon.performance
                )

                signalMetric(
                    "No model call needed",
                    "Uses the compiled routine",
                    symbol: AppIcon.compiledLocally
                )

                Divider().overlay(.white.opacity(0.16))

                Text(session.status)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func signalMetric(_ value: String, _ label: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color(red: 0.38, green: 0.88, blue: 0.62))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.56))
            }
        }
    }

    @ViewBuilder private var latestRun: some View {
        if let run = session.latestCompiledRun {
            AppPanel(emphasis: .quiet) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(
                            run.outcome == .succeeded ? "Last run completed" : "Last run stopped safely",
                            systemImage: run.outcome == .succeeded ? AppIcon.ready : AppIcon.attention
                        )
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(run.outcome == .succeeded ? AppTheme.success : AppTheme.warning)
                        Spacer()
                        Text("\(run.durationMilliseconds) ms")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    ForEach(run.steps, id: \.stepID) { step in
                        HStack {
                            Image(systemName: step.succeeded ? AppIcon.stepPassed : AppIcon.stepFailed)
                                .foregroundStyle(step.succeeded ? AppTheme.success : AppTheme.warning)
                            Text(readableName(step.stepID))
                            Spacer()
                            Text("\(step.durationMilliseconds) ms")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let reason = run.failureReason {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var activeFlowCount: Int {
        session.compiledFlowCatalog.filter { $0.status == .active }.count
    }

    private var latestDuration: String {
        guard let run = session.latestCompiledRun else { return "Awaiting first run" }
        return "\(run.durationMilliseconds) ms"
    }

    private var canRun: Bool {
        !recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && session.screenCaptureAllowed
            && session.accessibilityAllowed
            && !session.isCompiledFlowRunning
            && session.replayingFlowID == nil
            && !session.isRecording
    }

    private var canRunUnreadTriage: Bool {
        session.screenCaptureAllowed
            && session.accessibilityAllowed
            && !session.isCompiledFlowRunning
            && !session.isUnreadTriageRunning
            && session.replayingFlowID == nil
            && !session.isRecording
    }

    private func readableName(_ value: String) -> String {
        value.replacingOccurrences(of: "-", with: " ").capitalized
    }
}
