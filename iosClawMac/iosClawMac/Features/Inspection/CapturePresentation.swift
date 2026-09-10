import SwiftUI

struct TextTargetPreview: View {
    let image: NSImage
    let targets: [TextTarget]
    let zoom: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let imageSize = image.size
            let scale = min(geometry.size.width / imageSize.width, geometry.size.height / imageSize.height) * zoom
            let displaySize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let canvasSize = CGSize(width: max(geometry.size.width, displaySize.width), height: max(geometry.size.height, displaySize.height))
            let origin = CGPoint(x: (canvasSize.width - displaySize.width) / 2, y: (canvasSize.height - displaySize.height) / 2)

            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: displaySize.width, height: displaySize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .offset(x: origin.x, y: origin.y)
                    ForEach(Array(targets.enumerated()), id: \.element.id) { index, target in
                        TargetBox(index: index + 1, target: target, rect: target.displayRect(in: displaySize))
                            .offset(x: origin.x, y: origin.y)
                    }
                }
                .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("Captured screen at \(Int(zoom * 100)) percent scale with \(targets.count) detected text targets")
    }
}

struct CaptureViewControls: View {
    @Binding var zoom: CGFloat
    var showImageViewer: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Label("Scale", systemImage: AppIcon.zoomIn)
            Slider(value: $zoom, in: 0.5...3, step: 0.1)
                .frame(maxWidth: 220)
                .accessibilityLabel("Captured image scale")
            Text("\(Int(zoom * 100))%")
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
            if let showImageViewer {
                Button("View image", systemImage: AppIcon.expand, action: showImageViewer)
            }
            Button("Reset", systemImage: AppIcon.reset) { zoom = 1 }
                .disabled(zoom == 1)
        }
    }
}

struct CaptureImageViewer: View {
    let image: NSImage
    let targets: [TextTarget]
    @Binding var zoom: CGFloat
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Captured screen").font(.headline)
                Spacer()
                CaptureViewControls(zoom: $zoom)
                Button("Done", action: dismiss.callAsFunction)
                    .keyboardShortcut(.cancelAction)
            }
            TextTargetPreview(image: image, targets: targets, zoom: zoom)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .frame(minWidth: 900, minHeight: 700)
    }
}

private struct TargetBox: View {
    let index: Int
    let target: TextTarget
    let rect: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 5)
                .stroke(.mint, lineWidth: 2)
                .background(RoundedRectangle(cornerRadius: 5).fill(.mint.opacity(0.14)))
                .frame(width: rect.width, height: rect.height)
            Text("\(index) · \(target.text)")
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.mint.opacity(0.9), in: Capsule())
                .foregroundStyle(.black)
                .offset(y: -20)
        }
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
        .offset(x: rect.minX, y: rect.minY)
        .accessibilityLabel("Text target \(index): \(target.text)")
    }
}
