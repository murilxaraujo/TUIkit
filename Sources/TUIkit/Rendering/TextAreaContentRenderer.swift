//  TUIKit - Terminal UI Kit for Swift
//  TextAreaContentRenderer.swift
//
//  Created by LAYERED.work
//  License: MIT

// MARK: - Text Area Content Renderer

/// Shared multiline rendering logic for ``TextArea``.
@MainActor
struct TextAreaContentRenderer {
    let prompt: Text?
    let isDisabled: Bool

    func buildLines(
        text: String,
        layout: TextAreaHandler.LineLayout,
        cursorLocation: (line: Int, column: Int),
        verticalOffset: Int,
        isFocused: Bool,
        palette: any Palette,
        cursorStyle: TextCursorStyle,
        cursorTimer: CursorTimer?,
        contentWidth: Int,
        contentHeight: Int
    ) -> [String] {
        let width = max(1, contentWidth)
        let height = max(1, contentHeight)
        let background = palette.accent.opacity(ViewConstants.focusBorderDim)
        let foreground = isDisabled ? palette.foregroundTertiary : palette.foreground

        if text.isEmpty && !isFocused, let prompt {
            var lines = Array(repeating: blankLine(width: width, palette: palette, background: background), count: height)
            lines[0] = promptLine(prompt, width: width, palette: palette, background: background)
            return lines
        }

        let visibleLines = Array(layout.lines.dropFirst(verticalOffset).prefix(height))
        var rendered: [String] = []
        rendered.reserveCapacity(height)

        for row in 0..<height {
            let logicalLine = verticalOffset + row
            let line = row < visibleLines.count ? visibleLines[row] : ""
            let cursorColumn = isFocused && logicalLine == cursorLocation.line ? cursorLocation.column : nil
            rendered.append(
                renderLine(
                    line,
                    cursorColumn: cursorColumn,
                    palette: palette,
                    foreground: foreground,
                    cursorStyle: cursorStyle,
                    cursorTimer: cursorTimer,
                    background: background,
                    width: width
                )
            )
        }

        return rendered
    }

    private func promptLine(_ prompt: Text, width: Int, palette: any Palette, background: Color) -> String {
        let buffer = TUIkit.renderToBuffer(prompt, context: RenderContext(availableWidth: width, availableHeight: 1))
        let promptText = buffer.lines.first?.stripped ?? ""
        let padded = String(promptText.prefix(width)).padding(toLength: width, withPad: " ", startingAt: 0)
        return ANSIRenderer.colorize(padded, foreground: palette.foregroundTertiary, background: background)
    }

    private func blankLine(width: Int, palette: any Palette, background: Color) -> String {
        ANSIRenderer.colorize(String(repeating: " ", count: width), foreground: palette.foreground, background: background)
    }

    private func renderLine(
        _ line: String,
        cursorColumn: Int?,
        palette: any Palette,
        foreground: Color,
        cursorStyle: TextCursorStyle,
        cursorTimer: CursorTimer?,
        background: Color,
        width: Int
    ) -> String {
        let clampedCursorColumn = cursorColumn.map { max(0, min($0, line.count)) }
        let horizontalOffset: Int
        if let clampedCursorColumn, clampedCursorColumn >= width {
            horizontalOffset = clampedCursorColumn - width + 1
        } else {
            horizontalOffset = 0
        }

        let characters = Array(line)
        let (cursorVisible, cursorColor) = computeCursorState(
            baseColor: palette.cursorColor,
            animation: cursorStyle.animation,
            speed: cursorStyle.speed,
            cursorTimer: cursorTimer
        )

        var result = ""
        for visibleColumn in 0..<width {
            let textColumn = horizontalOffset + visibleColumn
            if let clampedCursorColumn, textColumn == clampedCursorColumn {
                if cursorVisible {
                    result += ANSIRenderer.colorize(
                        String(cursorStyle.shape.character),
                        foreground: cursorColor,
                        background: background
                    )
                } else {
                    let char = textColumn < characters.count ? String(characters[textColumn]) : " "
                    result += ANSIRenderer.colorize(char, foreground: foreground, background: background)
                }
            } else if textColumn < characters.count {
                result += ANSIRenderer.colorize(String(characters[textColumn]), foreground: foreground, background: background)
            } else {
                result += ANSIRenderer.colorize(" ", foreground: foreground, background: background)
            }
        }
        return result
    }

    private func computeCursorState(
        baseColor: Color,
        animation: TextCursorStyle.Animation,
        speed: TextCursorStyle.Speed,
        cursorTimer: CursorTimer?
    ) -> (visible: Bool, color: Color) {
        switch animation {
        case .none:
            return (true, baseColor)
        case .blink:
            let visible = cursorTimer?.blinkVisible(for: speed) ?? true
            return (visible, baseColor)
        case .pulse:
            let phase = cursorTimer?.pulsePhase(for: speed) ?? 1.0
            let dimColor = baseColor.opacity(ViewConstants.focusPulseMin)
            let color = Color.lerp(dimColor, baseColor, phase: phase)
            return (true, color)
        }
    }
}
