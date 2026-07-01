//  TUIKit - Terminal UI Kit for Swift
//  TextAreaTests.swift
//
//  Created by LAYERED.work
//  License: MIT

import Testing

@testable import TUIkit

@MainActor
@Suite("TextArea Tests")
struct TextAreaTests {
    private func testContext(width: Int = 40, height: Int = 4) -> RenderContext {
        RenderContext(availableWidth: width, availableHeight: height, tuiContext: TUIContext())
    }

    @Test("TextArea initializes with text binding")
    func initialization() {
        var text = "Hello"
        let binding = Binding(get: { text }, set: { text = $0 })

        let textArea = TextArea(text: binding)

        let buffer = renderToBuffer(textArea, context: testContext())
        #expect(buffer.height == 4)
        #expect(buffer.lines[0].stripped.contains("Hello"))
    }

    @Test("TextArea renders multiple lines")
    func rendersMultipleLines() {
        var text = "First\nSecond"
        let binding = Binding(get: { text }, set: { text = $0 })
        let textArea = TextArea(text: binding)

        let buffer = renderToBuffer(textArea, context: testContext())

        #expect(buffer.height == 4)
        #expect(buffer.lines[0].stripped.contains("First"))
        #expect(buffer.lines[1].stripped.contains("Second"))
    }

    @Test("TextArea renders prompt when empty and unfocused")
    func rendersPrompt() {
        var text = ""
        let binding = Binding(get: { text }, set: { text = $0 })
        let textArea = TextArea(text: binding, prompt: Text("Write notes…")).disabled()

        let buffer = renderToBuffer(textArea, context: testContext())

        #expect(buffer.lines[0].stripped.contains("Write notes…"))
    }

    @Test("Line limit controls intrinsic height")
    func lineLimitControlsIntrinsicHeight() {
        var text = ""
        let binding = Binding(get: { text }, set: { text = $0 })
        let textArea = TextArea(text: binding).textAreaLineLimit(2)

        let buffer = renderToBuffer(textArea, context: RenderContext(availableWidth: 40, availableHeight: 2, tuiContext: TUIContext()))

        #expect(buffer.height == 2)
    }

    @Test("TextArea body is renderable as a View")
    func viewConformance() {
        var text = "Body"
        let binding = Binding(get: { text }, set: { text = $0 })
        let textArea = TextArea(text: binding)

        let buffer = renderToBuffer(textArea.body, context: testContext())

        #expect(buffer.height == 4)
        #expect(buffer.width > 0)
    }

    @Test("Disabled TextArea stores disabled state")
    func disabledState() {
        var text = "Read only"
        let binding = Binding(get: { text }, set: { text = $0 })
        let textArea = TextArea(text: binding).disabled()

        #expect(textArea.isDisabled == true)
    }
}
