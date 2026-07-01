//  🖥️ TUIKit — Terminal UI Kit for Swift
//  AppHeaderTests.swift
//
//  Created by LAYERED.work
//  License: MIT

import Testing

@testable import TUIkit

@MainActor
@Suite("AppHeader Tests")
struct AppHeaderTests {
    @Test("App header does not append trailing spaces to content")
    func contentLineIsNotPadded() {
        let context = RenderContext(
            availableWidth: 10,
            availableHeight: 2,
            environment: EnvironmentValues(),
            tuiContext: TUIContext()
        )
        let header = AppHeader(contentBuffer: FrameBuffer(lines: ["Header"]))

        let buffer = renderToBuffer(header, context: context)

        #expect(buffer.lines.first == "Header")
        #expect(buffer.lines.first?.hasSuffix(" ") == false)
    }

    @Test("App header divider still spans available width")
    func dividerSpansAvailableWidth() {
        let context = RenderContext(
            availableWidth: 10,
            availableHeight: 2,
            environment: EnvironmentValues(),
            tuiContext: TUIContext()
        )
        let header = AppHeader(contentBuffer: FrameBuffer(lines: ["Header"]))

        let buffer = renderToBuffer(header, context: context)

        #expect(buffer.lines.count == 2)
        #expect(buffer.lines[1].strippedLength == 10)
    }
}
