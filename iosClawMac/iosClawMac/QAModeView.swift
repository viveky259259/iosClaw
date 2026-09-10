import SwiftUI

struct QAModeView: View {
    @ObservedObject var session: QASession
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAddingFlow = false
    @State private var isAddingMessageFlow = false
    @State private var editingFlow: QAFlow?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.pageSectionSpacing) {
                AppPageHeader(
                    title: "QA mode",
                    subtitle: "Deterministic, selector-driven testing for iOS Simulator and paired development devices."
                )

                ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AppTheme.spaceL) {
                    AppPanel(emphasis: .quiet) {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Execution plane", systemImage: AppIcon.localRunner)
                                .font(.title3.weight(.semibold))
                            Text("Direct, loopback-only WebDriverAgent control. This mode does not use iPhone Mirroring input.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                TextField("http://127.0.0.1:8100", text: $session.endpointText)
                                    .textFieldStyle(.roundedBorder)
                                Button("Test connection") { session.testConnection() }
                                    .buttonStyle(.borderedProminent)
                                    .tint(AppTheme.action)
                                    .disabled(session.isRunning)
                            }
                            Text(session.connectionStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    AppPanel(emphasis: .truth) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Runner guarantees")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                            qaGuarantee("Stable selectors", "Accessibility ID, predicate, or class chain.", AppIcon.semanticTarget)
                            qaGuarantee("One device lease", "Parallel runs cannot collide on one target.", AppIcon.deviceLease)
                            qaGuarantee("Encrypted evidence", "Run captures stay protected on this Mac.", AppIcon.protectedStorage)
                        }
                    }
                    .frame(width: 330)
                }
                VStack(alignment: .leading, spacing: AppTheme.spaceL) {
                    AppPanel(emphasis: .quiet) {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Execution plane", systemImage: AppIcon.localRunner).font(.title3.weight(.semibold))
                            TextField("http://127.0.0.1:8100", text: $session.endpointText).textFieldStyle(.roundedBorder)
                            Button("Test connection") { session.testConnection() }
                                .buttonStyle(.borderedProminent).disabled(session.isRunning)
                            Text(session.connectionStatus).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    AppPanel(emphasis: .truth) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Runner guarantees").font(.title3.weight(.semibold)).foregroundStyle(.white)
                            qaGuarantee("Stable selectors", "Accessibility ID, predicate, or class chain.", AppIcon.semanticTarget)
                            qaGuarantee("One device lease", "Parallel runs cannot collide on one target.", AppIcon.deviceLease)
                            qaGuarantee("Encrypted evidence", "Run captures stay protected on this Mac.", AppIcon.protectedStorage)
                        }
                    }
                }
                }

                AppPanel(emphasis: .quiet) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Versioned flows")
                                    .font(.title3.weight(.semibold))
                                Text("Selector-based routines that can move between local runners.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Message flow", systemImage: AppIcon.message) { isAddingMessageFlow = true }
                                .disabled(session.isRunning)
                            Button("New flow", systemImage: AppIcon.add) { isAddingFlow = true }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.action)
                                .disabled(session.isRunning)
                        }
                        if session.flows.isEmpty {
                            ContentUnavailableView(
                                "No QA flows yet",
                                systemImage: AppIcon.testPlan,
                                description: Text("Create a flow using stable accessibility selectors. Vision remains a recovery mechanism.")
                            )
                            .frame(maxWidth: .infinity, minHeight: 180)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(session.flows) { flow in
                                    HStack(alignment: .center, spacing: 12) {
                                        Image(systemName: AppIcon.testPlan)
                                            .font(.title3)
                                            .foregroundStyle(AppTheme.action)
                                            .frame(width: 38, height: 38)
                                            .background(AppTheme.action.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(flow.name).font(.headline)
                                            Text("\(flow.appBundleID) · \(flow.steps.count) step(s) · schema \(flow.schemaVersion)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button("Edit") { editingFlow = flow }
                                            .buttonStyle(.bordered)
                                        Button(session.activeFlowID == flow.id ? "Running…" : "Run") { session.run(flow) }
                                            .buttonStyle(.borderedProminent)
                                            .tint(AppTheme.action)
                                            .disabled(session.isRunning)
                                        Button("Delete", role: .destructive) { session.deleteFlow(flow) }
                                            .buttonStyle(.borderless)
                                            .disabled(session.isRunning)
                                    }
                                    .padding(.vertical, 9)
                                    if flow.id != session.flows.last?.id { Divider() }
                                }
                            }
                        }
                    }
                }

                AppPanel(emphasis: .quiet) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent runs")
                            .font(.title3.weight(.semibold))
                    if session.runs.isEmpty {
                        Text("No QA runs recorded on this Mac.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(session.runs.prefix(12)) { run in
                                QARunRow(run: run, session: session)
                                if run.id != session.runs.prefix(12).last?.id { Divider() }
                            }
                        }
                    }
                    }
                }
            }
            .padding(AppTheme.pagePadding)
        }
        .background(AppTheme.canvas(for: colorScheme))
        .navigationTitle("QA mode")
        .sheet(isPresented: $isAddingFlow) {
            QAFlowEditor(session: session, initialJSON: session.flowJSON(QAFlow.example))
        }
        .sheet(isPresented: $isAddingMessageFlow) {
            VerifiedMessageFlowEditor(session: session)
        }
        .sheet(item: $editingFlow) { flow in
            QAFlowEditor(session: session, initialJSON: session.flowJSON(flow))
        }
    }

    private func qaGuarantee(_ title: String, _ detail: String, _ symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color(red: 0.38, green: 0.88, blue: 0.62))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.56))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct VerifiedMessageFlowEditor: View {
    @ObservedObject var session: QASession
    @Environment(\.dismiss) private var dismiss
    @State private var appBundleID = "net.whatsapp.WhatsAppSMB"
    @State private var recipient = ""
    @State private var message = ""
    @State private var recipientSelector = ""
    @State private var conversationSelector = ""
    @State private var composerSelector = "type == 'XCUIElementTypeTextView' AND (name == 'Message' OR label == 'Message')"
    @State private var sendSelector = "name == 'Send' OR label == 'Send'"
    @State private var deliveredMessageSelector = ""
    @State private var acknowledgesSend = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Verified message flow")
                .font(.headline)
            Text("iosClaw will only replay the selectors entered here. It verifies the recipient, the opened conversation, the composer, and the sent-message state; it never falls back to OCR or coordinates.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Form {
                TextField("App bundle ID", text: $appBundleID)
                TextField("Recipient", text: $recipient)
                    .onChange(of: recipient) { _, value in
                        let selector = exactNameOrLabel(value)
                        recipientSelector = selector
                        conversationSelector = selector
                    }
                TextField("Exact message", text: $message, axis: .vertical)
                    .lineLimit(2...5)
                    .onChange(of: message) { _, value in
                        deliveredMessageSelector = exactNameOrLabel(value)
                    }

                Section("Recorded accessibility selectors") {
                    TextField("Recipient", text: $recipientSelector, axis: .vertical)
                    TextField("Conversation confirmation", text: $conversationSelector, axis: .vertical)
                    TextField("Composer", text: $composerSelector, axis: .vertical)
                    TextField("Send control", text: $sendSelector, axis: .vertical)
                    TextField("Sent message confirmation", text: $deliveredMessageSelector, axis: .vertical)
                }

                Toggle("I approve sending this exact message to this recipient.", isOn: $acknowledgesSend)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save message flow") {
                    do {
                        let flow = try QAFlow.verifiedMessage(
                            recipient: recipient,
                            message: message,
                            appBundleID: appBundleID,
                            recipientSelector: predicate(recipientSelector),
                            conversationSelector: predicate(conversationSelector),
                            composerSelector: predicate(composerSelector),
                            sendSelector: predicate(sendSelector),
                            deliveredMessageSelector: predicate(deliveredMessageSelector)
                        )
                        try session.save(flow: flow)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .disabled(!acknowledgesSend)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 720, height: 680)
    }

    private func predicate(_ value: String) -> QASelector {
        QASelector(strategy: .predicate, value: value)
    }

    private func exactNameOrLabel(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "\\\\'")
        return "name == '\(escaped)' OR label == '\(escaped)'"
    }
}

private struct QARunRow: View {
    let run: QARunRecord
    @ObservedObject var session: QASession
    @State private var isArtifactPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: run.outcome == .passed ? AppIcon.ready : AppIcon.runFailed)
                    .foregroundStyle(run.outcome == .passed ? .green : .orange)
                Text(run.flowName)
                Spacer()
                Text(run.startedAt, format: .dateTime.month().day().hour().minute().second())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let failure = run.failureSummary {
                Text(failure)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Text("\(run.events.count) verified step(s) · \(run.artifacts.count) encrypted screenshot(s)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let artifact = run.artifacts.last, session.screenshot(for: artifact) != nil {
                Button("View latest encrypted screenshot") { isArtifactPresented = true }
                    .font(.caption)
                    .sheet(isPresented: $isArtifactPresented) {
                        if let image = session.screenshot(for: artifact) {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .padding()
                                .frame(minWidth: 600, minHeight: 500)
                        }
                    }
            }
        }
    }
}

private struct QAFlowEditor: View {
    @ObservedObject var session: QASession
    @Environment(\.dismiss) private var dismiss
    @State private var json: String
    @State private var errorMessage: String?

    init(session: QASession, initialJSON: String) {
        self.session = session
        _json = State(initialValue: initialJSON)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QA flow definition")
                .font(.headline)
            Text("Use accessibility ID, predicate, or class-chain selectors first. The parameters map directly to WebDriverAgent gesture endpoints.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $json)
                .font(.system(.body, design: .monospaced))
                .border(.quaternary)
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save flow") {
                    do {
                        try session.saveFlow(fromJSON: json)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 760, height: 620)
    }
}
