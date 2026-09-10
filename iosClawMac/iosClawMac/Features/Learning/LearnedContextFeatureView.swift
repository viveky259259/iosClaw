import SwiftUI

struct LearnedContextFeatureView: View {
    @ObservedObject var session: MirrorSession
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAddingFact = false
    @State private var inputControl: LearnedFact?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.pageSectionSpacing) {
                AppPageHeader(
                    title: "Learned context",
                    subtitle: "Reusable visual knowledge, resolved against the live screen instead of saved coordinates."
                )

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: AppTheme.spaceL) {
                        factLibrary.frame(maxWidth: .infinity)
                        learningPosture.frame(width: 310)
                    }
                    VStack(alignment: .leading, spacing: AppTheme.spaceL) {
                        factLibrary
                        learningPosture
                    }
                }
            }
            .padding(AppTheme.pagePadding)
        }
        .background(AppTheme.canvas(for: colorScheme))
        .navigationTitle("Learned context")
        .sheet(isPresented: $isAddingFact) {
            AddLearnedFactSheet(session: session)
        }
        .sheet(item: $inputControl) { control in
            ControlInputSheet(session: session, control: control)
        }
    }

    private func isLive(_ fact: LearnedFact) -> Bool {
        session.isFactLive(fact)
    }

    private var factLibrary: some View {
        AppPanel(emphasis: .quiet) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Context library")
                            .font(.title3.weight(.semibold))
                        Text("\(session.learnedFacts.count) verified fact\(session.learnedFacts.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Add fact", systemImage: AppIcon.add) { isAddingFact = true }
                        .disabled(session.currentScreenSignature == nil || session.isCompiledFlowRunning)
                }

                if session.learnedFacts.isEmpty {
                    ContentUnavailableView(
                        "No learned context yet",
                        systemImage: AppIcon.learnedContext,
                        description: Text("Inspect a screen, then save a verified visual fact for local reuse.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    VStack(spacing: 0) {
                        ForEach(session.learnedFacts.sorted { $0.lastConfirmedAt > $1.lastConfirmedAt }) { fact in
                            LearnedFactRow(
                                fact: fact,
                                isLive: isLive(fact),
                                actionsEnabled: !session.isCompiledFlowRunning,
                                onTap: { session.tapLearnedFact(fact) },
                                onInput: { inputControl = fact }
                            )
                            if fact.id != session.learnedFacts.sorted(by: { $0.lastConfirmedAt > $1.lastConfirmedAt }).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var learningPosture: some View {
        AppPanel(emphasis: .truth) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Learning posture")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("What iosClaw remembers")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.56))
                }

                learningPoint("Identity, not position", "Tap areas are resolved from each fresh capture.", AppIcon.semanticTarget)
                learningPoint("Verified screen state", "A fact is reused only when its required context matches.", AppIcon.verified)
                learningPoint("Stored on this Mac", "New intelligence becomes local context for later runs.", AppIcon.protectedStorage)

                Divider().overlay(.white.opacity(0.16))

                Text("Stale facts stop safely instead of tapping an old location.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func learningPoint(_ title: String, _ detail: String, _ symbol: String) -> some View {
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

private struct LearnedFactRow: View {
    let fact: LearnedFact
    let isLive: Bool
    let actionsEnabled: Bool
    let onTap: () -> Void
    let onInput: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(isLive ? AppTheme.success : .secondary)
                .frame(width: 36, height: 36)
                .background(
                    (isLive ? AppTheme.success : Color.secondary).opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(fact.name).font(.headline)
                Text("\(fact.kind.title) · \(fact.evidence.title) · \(Int(fact.confidence * 100))% confidence")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Confirmed \(fact.confirmationCount)x · \(fact.lastConfirmedAt, format: .dateTime.month().day().hour().minute())")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            if isLive {
                AppStatusPill(title: "Live", isReady: true)
            } else {
                Text("Stored")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.10), in: Capsule())
            }
            action
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(fact.name), \(fact.kind.title), \(isLive ? "live on the current screen" : "stored for future matching"), \(Int(fact.confidence * 100)) percent confidence"
        )
    }

    @ViewBuilder private var action: some View {
        if isLive, fact.kind != .screenLandmark {
            Button("Tap", action: onTap).buttonStyle(.bordered).disabled(!actionsEnabled)
        }
        if isLive, fact.kind == .control {
            Button("Input", action: onInput).buttonStyle(.borderedProminent).disabled(!actionsEnabled)
        }
    }

    private var symbol: String {
        switch fact.kind {
        case .appIcon: AppIcon.application
        case .control: AppIcon.tap
        case .screenLandmark: AppIcon.inspect
        }
    }
}

private struct ControlInputSheet: View {
    @ObservedObject var session: MirrorSession
    let control: LearnedFact
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Set control value").font(.headline)
            Text("iosClaw will clear and replace the value in the live verified control ‘\(control.name)’. The audit stores the control name, not the entered text.")
                .font(.caption).foregroundStyle(.secondary)
            TextField("Text to enter", text: $text)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel", action: dismiss.callAsFunction)
                Button("Set value") {
                    session.input(text, into: control)
                    dismiss()
                }
                .disabled(
                    text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || session.isCompiledFlowRunning
                )
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}

private struct AddLearnedFactSheet: View {
    @ObservedObject var session: MirrorSession
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind: LearnedFact.Kind = .appIcon
    @State private var evidence: LearnedFact.Evidence = .visualInference
    @State private var confidence = 0.9

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add visual fact").font(.headline)
            Text("iosClaw stores identity and required screen state. It resolves the tap area from the next live capture; no coordinates are saved.")
                .font(.caption).foregroundStyle(.secondary)
            Form {
                TextField("Name", text: $name, prompt: Text("e.g. WhatsApp"))
                Picker("Type", selection: $kind) {
                    ForEach(LearnedFact.Kind.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker("Evidence", selection: $evidence) {
                    ForEach([LearnedFact.Evidence.visualInference, .userConfirmed], id: \.self) { Text($0.title).tag($0) }
                }
                Slider(value: $confidence, in: 0.5...1, step: 0.05) { Text("Confidence") }
                Text("Confidence: \(Int(confidence * 100))%")
            }
            HStack {
                Spacer()
                Button("Cancel", action: dismiss.callAsFunction)
                Button("Save fact") {
                    session.remember(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        kind: kind,
                        evidence: evidence,
                        normalizedBounds: nil,
                        confidence: confidence
                    )
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}
