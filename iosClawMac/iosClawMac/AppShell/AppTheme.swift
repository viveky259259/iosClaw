import SwiftUI

/// One semantic vocabulary for symbols used throughout the app. Each name
/// describes the product concept represented by the SF Symbol, so feature
/// views do not repurpose unrelated imagery for visual variety.
enum AppIcon {
    static let brand = "iphone.gen3.circle.fill"

    static let command = "viewfinder"
    static let devices = "iphone.gen3"
    static let flows = "arrow.triangle.branch"
    static let recordings = "record.circle"
    static let learnedContext = "brain"
    static let audit = "list.bullet.clipboard"
    static let settings = "gearshape"
    static let qaMode = "checkmark.rectangle.stack"

    static let mirroredIPhone = "iphone.gen3.radiowaves.left.and.right"
    static let automaticSource = "arrow.triangle.2.circlepath"
    static let simulator = "macwindow"
    static let information = "info.circle.fill"
    static let selected = "checkmark.circle.fill"
    static let inspect = "viewfinder"
    static let textRecognition = "text.viewfinder"

    static let ready = "checkmark.circle.fill"
    static let attention = "exclamationmark.triangle.fill"
    static let observed = "eye.fill"
    static let access = "key.fill"
    static let safeStop = "hand.raised.fill"
    static let protectedStorage = "lock.shield.fill"
    static let verified = "checkmark.shield.fill"
    static let stepPassed = "checkmark.circle"
    static let stepFailed = "xmark.circle"
    static let runFailed = "xmark.octagon.fill"

    static let application = "app.fill"
    static let message = "message.fill"
    static let compose = "square.and.pencil"
    static let flow = "arrow.triangle.branch"
    static let orderedSteps = "list.number"
    static let savedRoutines = "rectangle.stack.fill"
    static let record = "record.circle"
    static let recordActive = "record.circle.fill"
    static let replay = "play.fill"
    static let replayActive = "play.circle.fill"
    static let delete = "trash"

    static let semanticTarget = "scope"
    static let tap = "cursorarrow.click"
    static let textInput = "keyboard"
    static let home = "house"
    static let localRunner = "server.rack"
    static let testPlan = "checkmark.rectangle.stack"
    static let deviceLease = "lock.fill"
    static let performance = "speedometer"
    static let compiledLocally = "cpu"

    static let add = "plus"
    static let refresh = "arrow.clockwise"
    static let zoomIn = "plus.magnifyingglass"
    static let expand = "arrow.up.left.and.arrow.down.right"
    static let reset = "arrow.counterclockwise"

    static let allSymbols: [String] = [
        brand, command, devices, flows, recordings, learnedContext, audit, settings, qaMode,
        mirroredIPhone, automaticSource, simulator, information, selected, inspect, textRecognition,
        ready, attention, observed, access, safeStop, protectedStorage, verified,
        stepPassed, stepFailed, runFailed, application, message, compose, flow,
        orderedSteps, savedRoutines, record, recordActive, replay, replayActive, delete,
        semanticTarget, tap, textInput, home, localRunner, testPlan, deviceLease,
        performance, compiledLocally, add, refresh, zoomIn, expand, reset
    ]
}

/// Presentation tokens for the macOS workspace. Domain features use these
/// primitives but retain ownership of their behavior and state.
enum AppTheme {
    // Canonical industrial colors. Surface colors are applied adaptively below
    // so light mode continues to use familiar macOS materials and contrast.
    static let instrumentBlack = Color(red: 0x10 / 255, green: 0x12 / 255, blue: 0x16 / 255)
    static let graphite = Color(red: 0x1B / 255, green: 0x1F / 255, blue: 0x26 / 255)
    static let panelGray = Color(red: 0x25 / 255, green: 0x2A / 255, blue: 0x33 / 255)
    static let safetyAmber = Color(red: 0xFF / 255, green: 0xB0 / 255, blue: 0x20 / 255)
    static let successGreen = Color(red: 0x3F / 255, green: 0xB9 / 255, blue: 0x50 / 255)
    static let highContrastWhite = Color(red: 0xF5 / 255, green: 0xF7 / 255, blue: 0xFA / 255)

    static let spaceXS: CGFloat = 4
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 12
    static let spaceL: CGFloat = 16
    static let spaceXL: CGFloat = 20
    static let spaceXXL: CGFloat = 28

    static let pagePadding: CGFloat = spaceXXL
    static let pageSectionSpacing: CGFloat = spaceXL
    static let panelPadding: CGFloat = spaceL
    static let inspectorPadding: CGFloat = spaceXL
    static let compactPadding: CGFloat = panelPadding
    static let panelRadius: CGFloat = 11
    static let controlRadius: CGFloat = 8
    static let toolbarHeight: CGFloat = 52
    static let inspectorWidth: CGFloat = 318

    // Explicit system fonts keep typography predictable while preserving
    // Dynamic Type scaling, localization, and macOS accessibility settings.
    static let pageTitleFont = Font.system(size: 28, weight: .bold, design: .default)
    static let sectionTitleFont = Font.system(.title3, design: .default, weight: .semibold)
    static let bodyFont = Font.system(.body, design: .default)
    static let detailFont = Font.system(.caption, design: .default)

    static func canvas(for scheme: ColorScheme) -> Color {
        scheme == .dark ? instrumentBlack : Color(nsColor: .windowBackgroundColor)
    }

    static func sidebar(for scheme: ColorScheme) -> Color {
        scheme == .dark ? graphite : Color(nsColor: .underPageBackgroundColor)
    }

    static func quietSurface(for scheme: ColorScheme) -> Color {
        scheme == .dark ? panelGray : Color(nsColor: .controlBackgroundColor)
    }

    static func truthSurface(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.055, green: 0.060, blue: 0.070)
            : Color(red: 0.105, green: 0.105, blue: 0.115)
    }

    static let action = Color.accentColor
    static let success = successGreen
    static let warning = safetyAmber
}

struct AppPanel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let emphasis: Emphasis
    var isSelected: Bool = false
    var isFocused: Bool = false
    private let content: Content

    enum Emphasis {
        case quiet
        case truth
    }

    init(
        emphasis: Emphasis = .quiet,
        isSelected: Bool = false,
        isFocused: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.emphasis = emphasis
        self.isSelected = isSelected
        self.isFocused = isFocused
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppTheme.compactPadding)
            .background(background, in: RoundedRectangle(cornerRadius: AppTheme.panelRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.panelRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isFocused ? 2 : 1)
            }
    }

    private var background: Color {
        switch emphasis {
        case .quiet: AppTheme.quietSurface(for: colorScheme)
        case .truth: AppTheme.truthSurface(for: colorScheme)
        }
    }

    private var borderColor: Color {
        if isFocused { return AppTheme.action }
        if isSelected { return AppTheme.action.opacity(0.65) }
        return Color(nsColor: .separatorColor).opacity(0.55)
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .default, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, AppTheme.spaceL)
            .padding(.vertical, AppTheme.spaceS)
            .background(
                AppTheme.action.opacity(configuration.isPressed ? 0.78 : 1),
                in: RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .default, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, AppTheme.spaceL)
            .padding(.vertical, AppTheme.spaceS)
            .background(
                Color(nsColor: .controlBackgroundColor).opacity(configuration.isPressed ? 0.72 : 1),
                in: RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.7))
            }
            .opacity(isEnabled ? 1 : 0.45)
    }
}

private struct AppFocusRing: ViewModifier {
    let isFocused: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.action, lineWidth: 2)
                    .padding(-3)
                    .accessibilityHidden(true)
            }
        }
    }
}

extension View {
    func appFocusRing(_ isFocused: Bool, cornerRadius: CGFloat = AppTheme.controlRadius) -> some View {
        modifier(AppFocusRing(isFocused: isFocused, cornerRadius: cornerRadius))
    }
}

struct AppStatusPill: View {
    let title: String
    let isReady: Bool

    var body: some View {
        Label(title, systemImage: isReady ? AppIcon.ready : AppIcon.attention)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isReady ? AppTheme.success : AppTheme.warning)
            .padding(.horizontal, AppTheme.spaceS)
            .padding(.vertical, AppTheme.spaceXS)
            .background((isReady ? AppTheme.success : AppTheme.warning).opacity(0.12), in: Capsule())
            .accessibilityLabel("\(title): \(isReady ? "ready" : "attention required")")
    }
}

struct AppPageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(AppTheme.pageTitleFont)
            Text(subtitle)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppSectionHeader: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(AppTheme.sectionTitleFont)
            Spacer()
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct AppPermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.spaceM) {
            Image(systemName: granted ? AppIcon.ready : AppIcon.attention)
                .font(.title3)
                .foregroundStyle(granted ? AppTheme.success : AppTheme.warning)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button(actionTitle, action: action)
        }
        .accessibilityElement(children: .contain)
    }
}
