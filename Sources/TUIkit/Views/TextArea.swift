//  TUIKit - Terminal UI Kit for Swift
//  TextArea.swift
//
//  Created by LAYERED.work
//  License: MIT

// MARK: - TextArea

/// A multiline text editing control tailored for terminal interfaces.
///
/// `TextArea` follows SwiftUI's `TextEditor` shape where possible: it edits a
/// `Binding<String>` directly and can be sized with normal layout modifiers such
/// as `.frame(height:)`. TUIkit uses the `TextArea` name to make the terminal
/// affordance explicit and provides an optional prompt for empty content.
///
/// ## Keyboard Controls
///
/// | Key | Action |
/// |-----|--------|
/// | Any printable | Insert character at cursor |
/// | Enter | Insert a newline |
/// | Backspace | Delete character before cursor |
/// | Delete | Delete character at cursor |
/// | Left/Right | Move cursor horizontally, crossing line boundaries |
/// | Up/Down | Move cursor between lines, preserving column where possible |
/// | Home/End | Move to start/end of current line |
/// | Page Up/Page Down | Move by ten lines |
/// | Ctrl+A | Move to start of document |
/// | Ctrl+E | Move to end of document |
/// | Ctrl+Z | Undo last edit |
///
/// # Basic Example
///
/// ```swift
/// @State private var notes = ""
///
/// TextArea(text: $notes, prompt: Text("Write notes…"))
///     .frame(height: 8)
/// ```
public struct TextArea: View {
    /// The binding to the multiline text content.
    let text: Binding<String>

    /// Optional prompt text shown when the area is empty and unfocused.
    let prompt: Text?

    /// The unique focus identifier.
    var focusID: String?

    /// Whether the text area is disabled.
    var isDisabled: Bool

    /// The preferred height when no parent proposes one.
    var preferredLineCount: Int

    public var body: some View {
        _TextAreaCore(
            text: text,
            prompt: prompt,
            focusID: focusID,
            isDisabled: isDisabled,
            preferredLineCount: preferredLineCount
        )
    }

    /// Creates a text area.
    ///
    /// - Parameters:
    ///   - text: The text to display and edit.
    ///   - prompt: A prompt shown when the text area is empty and unfocused.
    public init(text: Binding<String>, prompt: Text? = nil) {
        self.text = text
        self.prompt = prompt
        self.focusID = nil
        self.isDisabled = false
        self.preferredLineCount = 4
    }
}

// MARK: - TextArea Modifiers

extension TextArea {
    /// Creates a disabled version of this text area.
    ///
    /// Disabled text areas render their content but do not register for focus.
    public func disabled(_ disabled: Bool = true) -> TextArea {
        var copy = self
        copy.isDisabled = disabled
        return copy
    }

    /// Sets a custom focus identifier for this text area.
    public func focusID(_ id: String) -> TextArea {
        var copy = self
        copy.focusID = id
        return copy
    }

    /// Sets the preferred visible line count when no explicit height is proposed.
    ///
    /// Use `.frame(height:)` when a parent layout should control the exact
    /// terminal viewport height; use this modifier for the control's intrinsic
    /// height in flexible layouts.
    public func textAreaLineLimit(_ lineCount: Int) -> TextArea {
        var copy = self
        copy.preferredLineCount = max(1, lineCount)
        return copy
    }
}

// MARK: - Internal Core View

private struct _TextAreaCore: View, Renderable, Layoutable {
    let text: Binding<String>
    let prompt: Text?
    let focusID: String?
    let isDisabled: Bool
    let preferredLineCount: Int

    private let minContentWidth = 10

    var body: Never {
        fatalError("_TextAreaCore renders via Renderable")
    }

    func sizeThatFits(proposal: ProposedSize, context: RenderContext) -> ViewSize {
        ViewSize(
            width: max(minContentWidth + 2, proposal.width ?? minContentWidth + 2),
            height: max(1, proposal.height ?? preferredLineCount),
            isWidthFlexible: true,
            isHeightFlexible: true
        )
    }

    func renderToBuffer(context: RenderContext) -> FrameBuffer {
        let stateStorage = context.environment.stateStorage!
        let palette = context.environment.palette
        let cursorStyle = context.environment.textCursorStyle
        let contentWidth = max(minContentWidth, context.availableWidth - 2)
        let contentHeight = max(1, context.availableHeight)

        let persistedFocusID = FocusRegistration.persistFocusID(
            context: context,
            explicitFocusID: focusID,
            defaultPrefix: "textarea",
            propertyIndex: 1
        )

        let handlerKey = StateStorage.StateKey(identity: context.identity, propertyIndex: 0)
        let handlerBox: StateBox<TextAreaHandler> = stateStorage.storage(
            for: handlerKey,
            default: TextAreaHandler(
                focusID: persistedFocusID,
                text: text,
                canBeFocused: !isDisabled
            )
        )
        let handler = handlerBox.value
        handler.text = text
        handler.canBeFocused = !isDisabled
        handler.clampCursorPosition()

        FocusRegistration.register(context: context, handler: handler)
        let isFocused = FocusRegistration.isFocused(context: context, focusID: persistedFocusID)
        if isFocused {
            handler.ensureCursorVisible(viewportHeight: contentHeight)
        }

        let layout = handler.lineLayout()
        let cursorLocation = handler.lineColumn(for: handler.cursorPosition, layout: layout)
        let renderer = TextAreaContentRenderer(prompt: prompt, isDisabled: isDisabled)
        let contentLines = renderer.buildLines(
            text: text.wrappedValue,
            layout: layout,
            cursorLocation: cursorLocation,
            verticalOffset: handler.verticalOffset,
            isFocused: isFocused,
            palette: palette,
            cursorStyle: cursorStyle,
            cursorTimer: context.environment.cursorTimer,
            contentWidth: contentWidth,
            contentHeight: contentHeight
        )

        let capColor = palette.accent.opacity(ViewConstants.focusBorderDim)
        let openCap = ANSIRenderer.colorize(String(TerminalSymbols.openCap), foreground: capColor)
        let closeCap = ANSIRenderer.colorize(String(TerminalSymbols.closeCap), foreground: capColor)
        return FrameBuffer(lines: contentLines.map { openCap + $0 + closeCap })
    }
}
