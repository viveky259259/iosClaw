import AppKit
import ApplicationServices
import CoreGraphics

/// Small, bundled input driver for local iPhone Mirroring and Simulator windows.
/// It uses only public macOS APIs and requires the user's Accessibility permission.
final class MirrorInputBackend {
    enum Shortcut {
        case homeScreen
        case appSwitcher
        case spotlight
        case moveSelectionDown
        case activateSelection
        case find

        func gesture(for source: ScreenSource) -> (keyCode: CGKeyCode, flags: CGEventFlags) {
            switch self {
            case .homeScreen where source == .simulator:
                return (4, [.maskCommand, .maskShift]) // Command-Shift-H
            case .homeScreen:
                return (18, .maskCommand) // Command-1 in iPhone Mirroring
            case .appSwitcher:
                return (19, .maskCommand)
            case .spotlight:
                return (20, .maskCommand)
            case .moveSelectionDown:
                return (125, []) // Down Arrow
            case .activateSelection:
                return (36, []) // Return
            case .find:
                return (3, .maskCommand) // Command-F
            }
        }
    }

    enum InputError: LocalizedError {
        case accessibilityNotGranted
        case eventCreationFailed
        case cursorPositioningFailed

        var errorDescription: String? {
            switch self {
            case .accessibilityNotGranted: "Grant Accessibility before sending input to the selected screen source."
            case .eventCreationFailed: "macOS could not create the requested input event."
            case .cursorPositioningFailed: "macOS did not place the pointer on the verified iPhone target. No click was sent."
            }
        }
    }

    /// Sends input only to geometry resolved from the active capture. Learned
    /// facts identify a target but may never supply the tap coordinates.
    func tap(target: ResolvedSemanticTarget, in window: MirrorWindow) throws {
        try tap(
            at: screenPoint(for: NormalizedBounds(target.textTarget.normalizedBounds), in: window),
            window: window
        )
    }

    /// Enters Unicode text into the already-focused local source window. The
    /// caller must establish focus through a verified learned control first.
    func type(_ text: String, in window: MirrorWindow) throws {
        try preflight(window: window)
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw InputError.eventCreationFailed
        }

        for character in text {
            if let keystroke = Self.hardwareKeystroke(for: character) {
                try postKey(
                    keystroke.keyCode,
                    flags: keystroke.flags,
                    source: source,
                    targetPID: window.ownerPID
                )
                Thread.sleep(forTimeInterval: 0.015)
                continue
            }

            // Keep Unicode injection for characters that do not have a stable
            // physical key mapping. Simulator reliably accepts the hardware
            // codes above for deterministic numeric QA input.
            for codeUnit in String(character).utf16 {
                try postUnicode(codeUnit, source: source, targetPID: window.ownerPID)
                Thread.sleep(forTimeInterval: 0.015)
            }
        }
    }

    /// Clears a verified, focused field so a QA `set value` action is
    /// repeatable rather than appending on retries. Synthetic Command-A is
    /// not reliably forwarded by every Simulator runtime, whereas Delete is.
    func clearText(in window: MirrorWindow, maximumCharacters: Int = 32) throws {
        try preflight(window: window)
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw InputError.eventCreationFailed
        }
        for _ in 0..<maximumCharacters {
            try postKey(51, source: source, targetPID: window.ownerPID) // Delete / backspace on ANSI keyboards
            Thread.sleep(forTimeInterval: 0.015)
        }
    }

    private func postKey(
        _ keyCode: CGKeyCode,
        flags: CGEventFlags = [],
        source: CGEventSource,
        targetPID: pid_t? = nil
    ) throws {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { throw InputError.eventCreationFailed }
        down.flags = flags
        up.flags = flags
        if let targetPID {
            down.postToPid(targetPID)
            up.postToPid(targetPID)
        } else {
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    private func postUnicode(
        _ codeUnit: UniChar,
        source: CGEventSource,
        targetPID: pid_t? = nil
    ) throws {
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else { throw InputError.eventCreationFailed }
        var unicode = [codeUnit]
            down.keyboardSetUnicodeString(stringLength: unicode.count, unicodeString: &unicode)
            up.keyboardSetUnicodeString(stringLength: unicode.count, unicodeString: &unicode)
            if let targetPID {
                down.postToPid(targetPID)
                up.postToPid(targetPID)
            } else {
                down.post(tap: .cghidEventTap)
                up.post(tap: .cghidEventTap)
            }
    }

    func press(_ shortcut: Shortcut, in window: MirrorWindow) throws {
        try preflight(window: window)
        let gesture = shortcut.gesture(for: window.source)
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: gesture.keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: gesture.keyCode, keyDown: false)
        else { throw InputError.eventCreationFailed }

        down.flags = gesture.flags
        up.flags = gesture.flags
        // Navigation shortcuts must be delivered to the source process itself.
        // A global event can race with activation and land in iosClaw (or another
        // foreground app), while the verified mirror window already gives us the
        // exact owning process.
        down.postToPid(window.ownerPID)
        up.postToPid(window.ownerPID)
    }

    private func tap(at point: CGPoint, window: MirrorWindow) throws {
        try preflight(window: window)
        guard let source = CGEventSource(stateID: .hidSystemState),
              let move = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left),
              let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        else { throw InputError.eventCreationFailed }

        // Mirroring occasionally drops a zero-duration teleport-and-click.
        // Move first and preserve a human-scale press interval so its input
        // bridge receives a complete pointer gesture.
        CGAssociateMouseAndMouseCursorPosition(boolean_t(0))
        defer { CGAssociateMouseAndMouseCursorPosition(boolean_t(1)) }
        CGWarpMouseCursorPosition(point)
        Thread.sleep(forTimeInterval: 0.03)
        guard let current = CGEvent(source: nil)?.location,
              hypot(current.x - point.x, current.y - point.y) <= 2
        else { throw InputError.cursorPositioningFailed }
        move.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.03)
        down.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.05)
        up.post(tap: .cghidEventTap)
    }

    private func screenPoint(for bounds: NormalizedBounds, in window: MirrorWindow) -> CGPoint {
        MirrorCoordinateMapper.screenPoint(for: bounds, in: window.bounds)
    }

    private func preflight(window: MirrorWindow) throws {
        guard AXIsProcessTrusted() else { throw InputError.accessibilityNotGranted }
        let application = NSRunningApplication(processIdentifier: window.ownerPID)
        application?.activate(options: [.activateAllWindows])

        let applicationElement = AXUIElementCreateApplication(window.ownerPID)
        var windowsValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            applicationElement,
            kAXWindowsAttribute as CFString,
            &windowsValue
        ) == .success,
           let windows = windowsValue as? [AXUIElement],
           let sourceWindow = windows.first
        {
            AXUIElementPerformAction(sourceWindow, kAXRaiseAction as CFString)
        }
        // Activation is asynchronous. Give the selected source a tiny focus
        // handoff before emitting the local input events.
        Thread.sleep(forTimeInterval: 0.20)
    }

    private static func hardwareKeystroke(
        for character: Character
    ) -> (keyCode: CGKeyCode, flags: CGEventFlags)? {
        let value = String(character)
        let lower = value.lowercased()
        let keyCode: CGKeyCode? = switch lower {
        case "a": 0
        case "s": 1
        case "d": 2
        case "f": 3
        case "h": 4
        case "g": 5
        case "z": 6
        case "x": 7
        case "c": 8
        case "v": 9
        case "b": 11
        case "q": 12
        case "w": 13
        case "e": 14
        case "r": 15
        case "y": 16
        case "t": 17
        case "1": 18
        case "2": 19
        case "3": 20
        case "4": 21
        case "5": 23
        case "6": 22
        case "7": 26
        case "8": 28
        case "9": 25
        case "0": 29
        case "o": 31
        case "u": 32
        case "i": 34
        case "p": 35
        case "l": 37
        case "j": 38
        case "k": 40
        case "n": 45
        case "m": 46
        case " ": 49
        default: nil
        }
        guard let keyCode else { return nil }
        let isUppercaseLetter = value != lower && lower.rangeOfCharacter(from: .letters) != nil
        return (keyCode, isUppercaseLetter ? .maskShift : [])
    }
}
