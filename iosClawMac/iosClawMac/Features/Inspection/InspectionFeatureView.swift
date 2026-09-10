import SwiftUI

struct InspectionFeatureView: View {
    @ObservedObject var session: MirrorSession
    @Binding var zoom: CGFloat
    @Binding var isViewerPresented: Bool
    @Binding var isInspectorPresented: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.pageSectionSpacing) {
                AppPageHeader(
                    title: "Live session",
                    subtitle: "Verified context from " + (session.activeSource?.title ?? session.captureSource.title) + "."
                )
                deviceMirror
                if !session.textTargets.isEmpty || !session.reusableFacts.isEmpty { liveContext }
            }
            .padding(AppTheme.pagePadding)
        }
        .inspector(isPresented: $isInspectorPresented) {
            nextAction
                .inspectorColumnWidth(min: 280, ideal: AppTheme.inspectorWidth, max: 360)
        }
        .background(AppTheme.canvas(for: colorScheme))
        .navigationTitle("Command")
    }


    private var deviceMirror: some View {
        AppPanel(emphasis: .quiet) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("iPhone mirror")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(session.activeSource?.title ?? "Choose a source to begin")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: AppIcon.mirroredIPhone)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                if let preview = session.preview {
                    TextTargetPreview(image: preview, targets: session.textTargets, zoom: zoom)
                        .frame(minHeight: 390, maxHeight: 500)
                    CaptureViewControls(zoom: $zoom, showImageViewer: { isViewerPresented = true })
                } else {
                    Spacer(minLength: 28)
                    VStack(spacing: 10) {
                        Image(systemName: AppIcon.inspect)
                            .font(.system(size: 38, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("No live capture")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Choose a source, then inspect the current screen.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 360)
                    Spacer(minLength: 28)
                }

                Text(session.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 500)
    }

    private var nextAction: some View {
        VStack(alignment: .leading, spacing: AppTheme.spaceL) {
            AppSectionHeader(title: "Inspector", detail: "Live")
            Divider()
            VStack(alignment: .leading, spacing: AppTheme.spaceL) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Next action")
                        .font(.title3.weight(.semibold))
                    Text("Review the source before iosClaw observes it.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected device")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("Selected device", selection: $session.captureSource) {
                        ForEach(ScreenSource.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }

                Button("Inspect current screen", systemImage: AppIcon.inspect) {
                    session.inspect()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.action)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(session.isCompiledFlowRunning)

                VStack(alignment: .leading, spacing: 7) {
                    Label("Nothing is sent from this step.", systemImage: AppIcon.safeStop)
                        .font(.caption.weight(.semibold))
                    Text("iosClaw captures live context locally. Any later external action asks for approval.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(AppTheme.inspectorPadding)
        .background(.background)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var liveContext: some View {
        AppPanel(emphasis: .quiet) {
        VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Live context", systemImage: AppIcon.textRecognition)
                        .font(.headline)
                    Spacer()
                    Text("\(session.textTargets.count) visible target\(session.textTargets.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !session.textTargets.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], alignment: .leading, spacing: 8) {
                        ForEach(Array(session.textTargets.enumerated()), id: \.element.id) { index, target in
                            Label("\(index + 1). \(target.text)", systemImage: AppIcon.textRecognition)
                                .font(.caption)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
                                .textSelection(.enabled)
                        }
                    }
                }
                if !session.reusableFacts.isEmpty {
                    Label(
                        "\(session.reusableFacts.count) verified local hint(s) match this screen. iosClaw validates the live screen again before input.",
                        systemImage: AppIcon.verified
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

extension View {
    func appSurface() -> some View {
        padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            }
    }
}
