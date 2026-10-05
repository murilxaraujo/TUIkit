//  TUIKit - Terminal UI Kit for Swift
//  TextAreaHandler.swift
//
//  Created by LAYERED.work
//  License: MIT

/// A focus handler for multiline text editing controls.
///
/// `TextAreaHandler` keeps the terminal-specific editing state for ``TextArea``:
/// cursor position, preferred column for vertical movement, viewport offset, and
/// undo history. The cursor position is a character offset in the bound string;
/// newline characters are part of the offset model.
final class TextAreaHandler: Focusable {
    /// The unique identifier for this focusable element.
    let focusID: String

    /// The binding to the multiline text content.
    var text: Binding<String>

    /// Whether this element can currently receive focus.
    var canBeFocused: Bool

    /// The cursor position as a character index in `text`.
    var cursorPosition: Int

    /// First visible logical line in the rendered viewport.
    var verticalOffset: Int

    /// Preferred visual column when moving up/down.
    private var preferredColumn: Int?

    /// Undo history stack storing previous text states and cursor positions.
    private var undoStack: [(text: String, cursor: Int)] = []

    /// Maximum number of undo states to keep.
    private let maxUndoStates = 50

    /// Optional submit action. When set, Return submits and Shift+Return inserts a newline.
    var onSubmit: (() -> Void)?

    init(
        focusID: String,
        text: Binding<String>,
        canBeFocused: Bool = true,
        cursorPosition: Int? = nil,
        onSubmit: (() -> Void)? = nil
    ) {
        self.focusID = focusID
        self.text = text
        self.canBeFocused = canBeFocused
        self.cursorPosition = cursorPosition ?? text.wrappedValue.count
        self.verticalOffset = 0
        self.onSubmit = onSubmit
    }
}

// MARK: - Key Event Handling

extension TextAreaHandler {
    func handleKeyEvent(_ event: KeyEvent) -> Bool {
        if case .character(let character) = event.key {
            return handleCharacter(character, isControlPressed: event.ctrl)
        }

        switch event.key {
        case .space, .enter, .paste, .backspace, .delete:
            return handleEditingKey(event)
        case .left, .right, .up, .down, .home, .end, .pageUp, .pageDown:
            return handleCursorKey(event.key)
        default:
            return false
        }
    }

    private func handleEditingKey(_ event: KeyEvent) -> Bool {
        switch event.key {
        case .space:
            insertText(" ")
        case .enter:
            if let onSubmit, !event.shift {
                onSubmit()
            } else {
                insertText("\n")
            }
        case .paste(let pastedText):
            insertText(pastedText.normalizedNewlines())
        case .backspace:
            deleteBackward()
        case .delete:
            deleteForward()
        default:
            return false
        }
        return true
    }

    private func handleCursorKey(_ key: Key) -> Bool {
        switch key {
        case .left:
            moveCursorLeft()
        case .right:
            moveCursorRight()
        case .up:
            moveCursorUp()
        case .down:
            moveCursorDown()
        case .home:
            moveCursorToLineStart()
        case .end:
            moveCursorToLineEnd()
        case .pageUp:
            moveCursorByLines(-10)
        case .pageDown:
            moveCursorByLines(10)
        default:
            return false
        }
        return true
    }

    private func handleCharacter(_ character: Character, isControlPressed: Bool) -> Bool {
        if isControlPressed {
            return handleControlCharacter(character)
        }

        guard character.isLetter || character.isNumber || character.isPunctuation ||
            character.isSymbol || character.isWhitespace
        else {
            return false
        }

        insertText(String(character))
        return true
    }

    private func handleControlCharacter(_ character: Character) -> Bool {
        switch character {
        case "a", "A":
            cursorPosition = 0
            preferredColumn = nil
            return true
        case "e", "E":
            cursorPosition = text.wrappedValue.count
            preferredColumn = nil
            return true
        case "z", "Z":
            undo()
            return true
        default:
            return false
        }
    }
}

// MARK: - Text Editing

extension TextAreaHandler {
    func insertText(_ string: String) {
        guard !string.isEmpty else { return }
        pushUndoState()

        var current = text.wrappedValue
        let index = current.index(current.startIndex, offsetBy: min(cursorPosition, current.count))
        current.insert(contentsOf: string, at: index)
        text.wrappedValue = current
        cursorPosition += string.count
        preferredColumn = nil
    }

    func deleteBackward() {
        guard cursorPosition > 0 else { return }
        pushUndoState()

        var current = text.wrappedValue
        let index = current.index(current.startIndex, offsetBy: cursorPosition - 1)
        current.remove(at: index)
        text.wrappedValue = current
        cursorPosition -= 1
        preferredColumn = nil
    }

    func deleteForward() {
        var current = text.wrappedValue
        guard cursorPosition < current.count else { return }
        pushUndoState()

        let index = current.index(current.startIndex, offsetBy: cursorPosition)
        current.remove(at: index)
        text.wrappedValue = current
        preferredColumn = nil
    }
}

// MARK: - Cursor Navigation

extension TextAreaHandler {
    func moveCursorLeft() {
        if cursorPosition > 0 {
            cursorPosition -= 1
        }
        preferredColumn = nil
    }

    func moveCursorRight() {
        if cursorPosition < text.wrappedValue.count {
            cursorPosition += 1
        }
        preferredColumn = nil
    }

    func moveCursorUp() {
        moveCursorByLines(-1)
    }

    func moveCursorDown() {
        moveCursorByLines(1)
    }

    func moveCursorByLines(_ delta: Int) {
        let layout = lineLayout()
        let location = lineColumn(for: cursorPosition, layout: layout)
        let targetLine = max(0, min(layout.lines.count - 1, location.line + delta))
        let targetColumn = preferredColumn ?? location.column
        cursorPosition = position(line: targetLine, column: targetColumn, layout: layout)
        preferredColumn = targetColumn
    }

    func moveCursorToLineStart() {
        let layout = lineLayout()
        let location = lineColumn(for: cursorPosition, layout: layout)
        cursorPosition = position(line: location.line, column: 0, layout: layout)
        preferredColumn = nil
    }

    func moveCursorToLineEnd() {
        let layout = lineLayout()
        let location = lineColumn(for: cursorPosition, layout: layout)
        cursorPosition = position(line: location.line, column: layout.lines[location.line].count, layout: layout)
        preferredColumn = nil
    }

    func clampCursorPosition() {
        let maxPosition = text.wrappedValue.count
        cursorPosition = max(0, min(cursorPosition, maxPosition))
        let lineCount = lineLayout().lines.count
        verticalOffset = max(0, min(verticalOffset, max(0, lineCount - 1)))
    }

    func ensureCursorVisible(viewportHeight: Int) {
        let layout = lineLayout()
        let line = lineColumn(for: cursorPosition, layout: layout).line
        let height = max(1, viewportHeight)

        if line < verticalOffset {
            verticalOffset = line
        } else if line >= verticalOffset + height {
            verticalOffset = line - height + 1
        }

        verticalOffset = max(0, min(verticalOffset, max(0, layout.lines.count - height)))
    }
}

// MARK: - Line Model

extension TextAreaHandler {
    struct LineLayout {
        let lines: [String]
        let starts: [Int]
    }

    func lineLayout() -> LineLayout {
        let rawLines = text.wrappedValue.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let lines = rawLines.isEmpty ? [""] : rawLines
        var starts: [Int] = []
        var offset = 0
        for line in lines {
            starts.append(offset)
            offset += line.count + 1
        }
        return LineLayout(lines: lines, starts: starts)
    }

    func lineColumn(for position: Int, layout: LineLayout? = nil) -> (line: Int, column: Int) {
        let layout = layout ?? lineLayout()
        let clampedPosition = max(0, min(position, text.wrappedValue.count))

        for index in layout.lines.indices.reversed() where clampedPosition >= layout.starts[index] {
            let column = min(clampedPosition - layout.starts[index], layout.lines[index].count)
            return (index, column)
        }

        return (0, 0)
    }

    func position(line: Int, column: Int, layout: LineLayout? = nil) -> Int {
        let layout = layout ?? lineLayout()
        let clampedLine = max(0, min(line, layout.lines.count - 1))
        let clampedColumn = max(0, min(column, layout.lines[clampedLine].count))
        return layout.starts[clampedLine] + clampedColumn
    }
}

// MARK: - Undo

extension TextAreaHandler {
    func pushUndoState() {
        let state = (text: text.wrappedValue, cursor: cursorPosition)
        if let last = undoStack.last, last.text == state.text {
            return
        }

        undoStack.append(state)
        if undoStack.count > maxUndoStates {
            undoStack.removeFirst()
        }
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        text.wrappedValue = previous.text
        cursorPosition = min(previous.cursor, previous.text.count)
        preferredColumn = nil
    }
}

// MARK: - Focus Lifecycle

extension TextAreaHandler {
    func onFocusReceived() {
        clampCursorPosition()
    }
}

private extension String {
    func normalizedNewlines() -> String {
        replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}
