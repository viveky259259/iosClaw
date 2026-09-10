import SwiftUI

struct RecordReplayFeatureView: View {
    @ObservedObject var session: MirrorSession
    @Environment(\.colorScheme) private var colorScheme
    @State private var isNamingRecording = false
    @State private var flowToReplay: RecordedActionFlow?
    @State private var flowToDelete: RecordedActionFlow?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.pageSectionSpacing) {
                AppPageHeader(
                    title: "Recordings",
                    subtitle: "Teach iosClaw a routine once, then replay its semantic steps against fresh live context."
                )

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: AppTheme.spaceL) {
                        recordingStage.frame(maxWidth: .infinity)
                        reusePanel.frame(width: 320)
                    }
                    VStack(alignment: .leading, spacing: AppTheme.spaceL) {
                        recordingStage
                        reusePanel
                    }
                }

                replayStatus
                savedRecordings
            }
            .padding(AppTheme.pagePadding)
        }
        .background(AppTheme.canvas(for: colorScheme))
        .navigationTitle("Recordings")
        .sheet(isPresented: $isNamingRecording) {
            StartRecordingSheet(session: session)
        }
        .confirmationDialog(
            "Replay this flow?",
            isPresented: Binding(
                get: { flowToReplay != nil },
                set: { if !$0 { flowToReplay = nil } }
            ),
            titleVisibility: .visible,
            presenting: flowToReplay
        ) { flow in
            Button("Replay \(flow.steps.count) actions") {
                session.replay(flow)
                flowToReplay = nil
            }
            Button("Cancel", role: .cancel) { flowToReplay = nil }
        } message: { _ in
            Text("iosClaw validates a fresh screen before every action and stops on any mismatch.")
        }
        .confirmationDialog(
            "Delete this recorded flow?",
            isPresented: Binding(
                get: { flowToDelete != nil },
                set: { if !$0 { flowToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: flowToDelete
        ) { flow in
            Button("Delete ‘\(flow.name)’", role: .destructive) {
                session.deleteRecordedFlow(flow)
                flowToDelete = nil
            }
            Button("Cancel", role: .cancel) { flowToDelete = nil }
        }
    }

    private var recordingStage: some View {
        AppPanel(emphasis: .truth) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.isRecording ? "Recording now" : "Record a flow")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(session.isRecording ? (session.recordingName ?? "Untitled flow") : "Capture only actions performed through iosClaw.")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer()
                    Image(systemName: session.isRecording ? AppIcon.recordActive : AppIcon.record)
                        .font(.system(size: 34))
                        .foregroundStyle(session.isRecording ? .red : .white.opacity(0.76))
                }

                if session.isRecording {
                    if session.recordingSteps.isEmpty {
                        Text("Use a verified Tap, Input, or Home action to add the first semantic step.")
                            .foregroundStyle(.white.opacity(0.72))
                            .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
                            .multilineTextAlignment(.center)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(session.recordingSteps.enumerated()), id: \.element.id) { index, step in
                                HStack(spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.caption.weight(.bold).monospacedDigit())
                                        .foregroundStyle(.black)
                                        .frame(width: 24, height: 24)
                                        .background(.white, in: Circle())
                                    Label(step.summary, systemImage: stepSymbol(step.kind))
                                        .font(.callout)
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                    }

                    HStack {
                        Button("Cancel recording", role: .destructive, action: session.cancelRecording)
                            .tint(.white)
                        Spacer()
                        Text("\(session.recordingSteps.count) actions")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.66))
                        Button("Stop & save", action: session.stopRecording)
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .disabled(session.recordingSteps.isEmpty)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        recordingPromise("Targets are stored by meaning, not fixed position.", symbol: AppIcon.semanticTarget)
                        recordingPromise("Typed values stay inside the encrypted recording.", symbol: AppIcon.protectedStorage)
                        recordingPromise("Replay validates the screen before every step.", symbol: AppIcon.verified)
                    }
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)

                    Button("Start recording", systemImage: AppIcon.record) {
                        isNamingRecording = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                    .disabled(
                        session.activeSource == nil
                            || session.replayingFlowID != nil
                            || session.isCompiledFlowRunning
                    )
                }
            }
        }
    }

    private func recordingPromise(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.callout)
            .foregroundStyle(.white.opacity(0.80))
    }

    private var reusePanel: some View {
        AppPanel(emphasis: .quiet) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Reusable structure")
                    .font(.title3.weight(.semibold))
                reuseMetric("\(session.recordedFlows.count)", "saved routines", symbol: AppIcon.savedRoutines)
                reuseMetric("\(session.recordingSteps.count)", "steps in current capture", symbol: AppIcon.orderedSteps)
                reuseMetric(
                    session.activeSource?.title ?? "No live source",
                    "current device context",
                    symbol: AppIcon.devices
                )
                Divider()
                Text("Recordings are reusable because each step describes what to find and verify. Screen coordinates are never the source of truth.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func reuseMetric(_ value: String, _ label: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .foregroundStyle(AppTheme.action)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.headline)
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var replayStatus: some View {
        if let replayingFlowID = session.replayingFlowID,
           let flow = session.recordedFlows.first(where: { $0.id == replayingFlowID }) {
            AppPanel(emphasis: .quiet) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Replaying \(flow.name)", systemImage: AppIcon.replayActive)
                            .font(.headline)
                            .foregroundStyle(AppTheme.action)
                        Spacer()
                        Button("Stop", role: .destructive, action: session.cancelReplay)
                    }
                    ProgressView(value: Double(session.replayStepIndex), total: Double(max(flow.steps.count, 1)))
                    Text(session.status).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var savedRecordings: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Saved recordings",
                detail: "\(session.recordedFlows.count) routine\(session.recordedFlows.count == 1 ? "" : "s")"
            )

            if session.recordedFlows.isEmpty {
                AppPanel(emphasis: .quiet) {
                    VStack(spacing: 10) {
                        Image(systemName: AppIcon.record)
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("No recordings yet")
                            .font(.headline)
                        Text("Connect a device and record your first verified routine.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                }
            } else {
                AppPanel(emphasis: .quiet) {
                    VStack(spacing: 0) {
                        ForEach(session.recordedFlows) { flow in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: AppIcon.orderedSteps)
                                .font(.title2)
                                .foregroundStyle(AppTheme.action)
                                .frame(width: 40)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(flow.name).font(.headline)
                                Text("\(flow.source.title) · \(flow.steps.count) actions")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(flow.updatedAt, format: .dateTime.month().day().hour().minute())
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Button("Replay", systemImage: AppIcon.replay) { flowToReplay = flow }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.action)
                                .disabled(
                                    session.isRecording
                                        || session.replayingFlowID != nil
                                        || session.isCompiledFlowRunning
                                )
                            Button("Delete", systemImage: AppIcon.delete, role: .destructive) { flowToDelete = flow }
                                .labelStyle(.iconOnly)
                                .help("Delete \(flow.name)")
                        }
                        .padding(.vertical, 10)
                        if flow.id != session.recordedFlows.last?.id { Divider() }
                        }
                    }
                }
            }
        }
    }

    private func stepSymbol(_ kind: RecordedActionStep.Kind) -> String {
        switch kind {
        case .tap: AppIcon.tap
        case .input: AppIcon.textInput
        case .home: AppIcon.home
        }
    }
}

private struct StartRecordingSheet: View {
    @ObservedObject var session: MirrorSession
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Start recording").font(.title2.weight(.semibold))
            Text("Give this routine a name you will recognize later. Its semantic steps stay encrypted on this Mac.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField("Flow name", text: $name, prompt: Text("e.g. Fill Zency phone number"))
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel", action: dismiss.callAsFunction)
                Button("Start recording") {
                    session.startRecording(name: name)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}
