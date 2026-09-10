import SwiftUI
import MultipeerConnectivity

struct ContentView: View {
    @ObservedObject var store: AuditStore
    @ObservedObject var bridge: PeerBridge
    @State private var selectedPeer: MCPeerID?
    @State private var pairingCode = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Mac connection") {
                    Text(bridge.status.label)
                        .foregroundStyle(statusColor)

                    if bridge.peers.isEmpty {
                        Text("Open iosClaw Mac Bridge on your MacBook, then keep both devices nearby.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("MacBook", selection: $selectedPeer) {
                            Text("Choose a Mac").tag(Optional<MCPeerID>.none)
                            ForEach(bridge.peers, id: \.self) { peer in
                                Text(peer.displayName).tag(Optional(peer))
                            }
                        }

                        TextField("Six-digit pairing code", text: $pairingCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)

                        Button("Pair securely") {
                            guard let selectedPeer else { return }
                            bridge.pair(with: selectedPeer, code: pairingCode)
                        }
                        .disabled(selectedPeer == nil || pairingCode.filter(\.isNumber).count != 6)
                    }
                }

                Section("Local audit timeline") {
                    if store.steps.isEmpty {
                        ContentUnavailableView(
                            "No steps yet",
                            systemImage: "checklist",
                            description: Text("Paired Macs send redacted automation events here.")
                        )
                    } else {
                        ForEach(store.steps) { step in
                            StepRow(step: step)
                        }
                    }
                }

                Section {
                    Text("This app stores only redacted audit events. It never receives Face ID data, passcodes, one-time codes, screenshots, or raw message text.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Clear local history", role: .destructive) {
                        store.clear()
                    }
                }
            }
            .navigationTitle("iosClaw Companion")
        }
    }

    private var statusColor: Color {
        if case .paired = bridge.status { return .green }
        if case .rejected = bridge.status { return .red }
        return .secondary
    }
}

private struct StepRow: View {
    let step: AuditStep

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(step.action)
                    .font(.headline)
                Spacer()
                Text(step.effect.displayName)
                    .font(.caption)
                    .foregroundStyle(effectColor)
            }
            Text(step.appName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(step.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(step.occurredAt, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
    }

    private var effectColor: Color {
        switch step.effect {
        case .approvalRequired, .blocked: .orange
        case .draft: .blue
        case .navigate, .observe: .secondary
        }
    }
}
