//  TUIKit - Terminal UI Kit for Swift
//  FrameModifierTests.swift
//
//  Created by LAYERED.work
//  License: MIT

import Testing

@testable import TUIkit

// MARK: - Test Helpers

/// Creates a default render context for testing.
private func testContext(width: Int = 40, height: Int = 24) -> RenderContext {
    RenderContext(availableWidth: width, availableHeight: height, tuiContext: TUIContext())
}

// MARK: - FrameModifier Tests

@MainActor
@Suite("FrameModifier Tests")
struct FrameModifierTests {

    @Test(".frame(maxWidth: .infinity) fills available width")
    func frameMaxWidthInfinity() {
        let frame = Text("Hi").frame(maxWidth: .infinity)
        let context = testContext(width: 30)
        let buffer = renderToBuffer(frame, context: context)

        #expect(buffer.width == 30)
    }

    @Test(".frame(maxWidth: .fixed) constrains")
    func frameFixedMaxWidth() {
        let frame = Text("Short").frame(maxWidth: .fixed(10), alignment: .leading)
        let context = testContext(width: 40)
        let buffer = renderToBuffer(frame, context: context)

        // Content "Short" is 5 chars, no maxWidth expansion without infinity
        #expect(buffer.width <= 10)
    }

    @Test(".frame(minWidth:) enforces minimum")
    func frameMinWidth() {
        let frame = Text("Hi").frame(minWidth: 10, alignment: .leading)
        let context = testContext(width: 40)
        let buffer = renderToBuffer(frame, context: context)

        #expect(buffer.width >= 10)
    }

    @Test(".frame(minHeight:) enforces minimum")
    func frameMinHeight() {
        let frame = Text("Hi").frame(minHeight: 5, alignment: .top)
        let context = testContext()
        let buffer = renderToBuffer(frame, context: context)

        #expect(buffer.height >= 5)
    }

    @Test(".frame alignment center")
    func frameCenterAlignment() {
        let frame = Text("Hi").frame(minWidth: 10, minHeight: 3, alignment: .center)
        let context = testContext()
        let buffer = renderToBuffer(frame, context: context)

        #expect(buffer.width >= 10)
        #expect(buffer.height >= 3)
        // Center vertically: content should be on line 1 (middle of 3)
        let contentLine = buffer.lines[1]
        #expect(contentLine.contains("Hi"))
        // Center horizontally: "Hi" is 2 chars, frame is 10, so 4 spaces on left
        let stripped = contentLine.stripped
        let leadingSpaces = stripped.prefix(while: { $0 == " " }).count
        #expect(leadingSpaces == 4, "Content should be horizontally centered with 4 leading spaces")
    }

    @Test(".frame alignment trailing")
    func frameTrailingAlignment() {
        let frame = Text("Hi").frame(minWidth: 10, alignment: .trailing)
        let context = testContext()
        let buffer = renderToBuffer(frame, context: context)

        // "Hi" should be right-aligned within 10 chars
        let line = buffer.lines[0]
        #expect(line.stripped.hasSuffix("Hi"))
    }

    @Test(".frame alignment bottom")
    func frameBottomAlignment() {
        let frame = Text("Hi").frame(minHeight: 3, alignment: .bottom)
        let context = testContext()
        let buffer = renderToBuffer(frame, context: context)

        #expect(buffer.height >= 3)
        // Content on last line
        let lastLine = buffer.lines[buffer.height - 1]
        #expect(lastLine.contains("Hi"))
    }

    @Test(".frame(maxHeight:) constrains available height for content")
    func frameMaxHeight() {
        // maxHeight constrains the availableHeight passed to child rendering,
        // but does not clip content that exceeds constraints. This matches
        // SwiftUI behavior where frame constraints inform layout, not clip.
        let frame = Text("Short").frame(minHeight: 5, maxHeight: .fixed(10), alignment: .top)
        let context = testContext()
        let buffer = renderToBuffer(frame, context: context)

        // minHeight 5 expands the 1-line content to 5 lines
        #expect(buffer.height == 5)
    }

    @Test(".frame(maxHeight: .infinity) fills available space")
    func frameMaxHeightInfinity() {
        let frame = Text("Hi").frame(maxHeight: .infinity, alignment: .top)
        var context = testContext()
        context.availableHeight = 10
        let buffer = renderToBuffer(frame, context: context)

        // Should expand to fill available height
        #expect(buffer.height == 10)
    }
}
