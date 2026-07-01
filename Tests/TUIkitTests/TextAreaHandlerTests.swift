//  TUIKit - Terminal UI Kit for Swift
//  TextAreaHandlerTests.swift
//
//  Created by LAYERED.work
//  License: MIT

import Testing

@testable import TUIkit

@MainActor
@Suite("TextAreaHandler Tests")
struct TextAreaHandlerTests {
    @Test("Enter inserts newline")
    func enterInsertsNewline() {
        var text = "Hello"
        let binding = Binding(get: { text }, set: { text = $0 })
        let handler = TextAreaHandler(focusID: "area", text: binding)

        let handled = handler.handleKeyEvent(KeyEvent(key: .enter))

        #expect(handled == true)
        #expect(text == "Hello\n")
        #expect(handler.cursorPosition == 6)
    }

    @Test("Return submits when submit action is installed")
    func returnSubmitsWhenSubmitActionInstalled() {
        var text = "Hello"
        var didSubmit = false
        let binding = Binding(get: { text }, set: { text = $0 })
        let handler = TextAreaHandler(focusID: "area", text: binding, onSubmit: { didSubmit = true })

        let handled = handler.handleKeyEvent(KeyEvent(key: .enter))

        #expect(handled == true)
        #expect(didSubmit == true)
        #expect(text == "Hello")
        #expect(handler.cursorPosition == 5)
    }

    @Test("Shift Return inserts newline when submit action is installed")
    func shiftReturnInsertsNewlineWhenSubmitActionInstalled() {
        var text = "Hello"
        var didSubmit = false
        let binding = Binding(get: { text }, set: { text = $0 })
        let handler = TextAreaHandler(focusID: "area", text: binding, onSubmit: { didSubmit = true })

        let handled = handler.handleKeyEvent(KeyEvent(key: .enter, shift: true))

        #expect(handled == true)
        #expect(didSubmit == false)
        #expect(text == "Hello\n")
        #expect(handler.cursorPosition == 6)
    }

    @Test("Up and down preserve preferred column")
    func verticalMovementPreservesColumn() {
        var text = "abcd\nef\nghijk"
        let binding = Binding(get: { text }, set: { text = $0 })
        let handler = TextAreaHandler(focusID: "area", text: binding, cursorPosition: 3)

        _ = handler.handleKeyEvent(KeyEvent(key: .down))
        #expect(handler.cursorPosition == 7)  // End of "ef"

        _ = handler.handleKeyEvent(KeyEvent(key: .down))
        #expect(handler.cursorPosition == 11)  // Column 3 in "ghijk"
    }

    @Test("Home and End move within current line")
    func homeEndMoveWithinLine() {
        var text = "first\nsecond"
        let binding = Binding(get: { text }, set: { text = $0 })
        let handler = TextAreaHandler(focusID: "area", text: binding, cursorPosition: 9)

        _ = handler.handleKeyEvent(KeyEvent(key: .home))
        #expect(handler.cursorPosition == 6)

        _ = handler.handleKeyEvent(KeyEvent(key: .end))
        #expect(handler.cursorPosition == 12)
    }

    @Test("Backspace joins lines")
    func backspaceJoinsLines() {
        var text = "Hello\nWorld"
        let binding = Binding(get: { text }, set: { text = $0 })
        let handler = TextAreaHandler(focusID: "area", text: binding, cursorPosition: 6)

        _ = handler.handleKeyEvent(KeyEvent(key: .backspace))

        #expect(text == "HelloWorld")
        #expect(handler.cursorPosition == 5)
    }

    @Test("Paste preserves multiline content")
    func pastePreservesMultilineContent() {
        var text = ""
        let binding = Binding(get: { text }, set: { text = $0 })
        let handler = TextAreaHandler(focusID: "area", text: binding)

        _ = handler.handleKeyEvent(KeyEvent(key: .paste("a\r\nb\rc")))

        #expect(text == "a\nb\nc")
        #expect(handler.cursorPosition == 5)
    }

    @Test("Ensure cursor visible adjusts viewport")
    func ensureCursorVisibleAdjustsViewport() {
        var text = "0\n1\n2\n3\n4"
        let binding = Binding(get: { text }, set: { text = $0 })
        let handler = TextAreaHandler(focusID: "area", text: binding, cursorPosition: text.count)

        handler.ensureCursorVisible(viewportHeight: 2)

        #expect(handler.verticalOffset == 3)
    }
}
