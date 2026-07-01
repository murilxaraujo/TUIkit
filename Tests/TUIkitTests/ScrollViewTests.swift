//  TUIKit - Terminal UI Kit for Swift
//  ScrollViewTests.swift
//
//  Created by LAYERED.work
//  License: MIT

import Testing

@testable import TUIkit

@MainActor
private func scrollTestContext(width: Int = 40, height: Int = 5, tuiContext: TUIContext = TUIContext()) -> RenderContext {
    RenderContext(availableWidth: width, availableHeight: height, tuiContext: tuiContext)
}

@MainActor
@Suite("ScrollView Tests")
struct ScrollViewTests {
    @Test("ScrollView clips overflowing content to viewport height")
    func clipsOverflowingContent() {
        let view = ScrollView {
            LazyVStack(alignment: .leading) {
                ForEach(0..<10) { index in
                    Text("Row \(index)")
                }
            }
        }

        let buffer = renderToBuffer(view, context: scrollTestContext(height: 4))
        let content = buffer.lines.joined(separator: "\n")

        #expect(buffer.height == 4)
        #expect(content.contains("Row 0"))
        #expect(!content.contains("Row 9"))
        #expect(content.contains("↓ more"))
    }

    @Test("ScrollView can start anchored to bottom")
    func startsAnchoredToBottom() {
        let view = ScrollView(initialAnchor: .bottom) {
            LazyVStack(alignment: .leading) {
                ForEach(0..<10) { index in
                    Text("Row \(index)")
                }
            }
        }

        let buffer = renderToBuffer(view, context: scrollTestContext(height: 4))
        let content = buffer.lines.joined(separator: "\n")

        #expect(content.contains("Row 9"))
        #expect(!content.contains("Row 0"))
        #expect(content.contains("↑ more"))
    }

    @Test("ScrollView inside a flexible panel does not hide fixed siblings")
    func scrollViewInsideFlexiblePanelDoesNotHideFixedSiblings() {
        let view = VStack(alignment: .leading, spacing: 1) {
            Panel("Chat") {
                ScrollView(initialAnchor: .bottom) {
                    LazyVStack(alignment: .leading) {
                        Text("Ready")
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)

            Text("Prompt")
        }

        let buffer = renderToBuffer(view, context: scrollTestContext(height: 8))
        let content = buffer.lines.joined(separator: "\n")

        #expect(buffer.height == 8)
        #expect(content.contains("Ready"))
        #expect(content.contains("Prompt"))
        #expect(content.contains("╰"), "Panel bottom border should render inside the allocated flexible height")
    }

    @Test("ScrollView responds to keyboard scroll events")
    func respondsToKeyboardScrollEvents() {
        let tuiContext = TUIContext()
        let context = scrollTestContext(height: 4, tuiContext: tuiContext)
        let view = ScrollView {
            LazyVStack(alignment: .leading) {
                ForEach(0..<10) { index in
                    Text("Row \(index)")
                }
            }
        }

        _ = renderToBuffer(view, context: context)
        tuiContext.keyEventDispatcher.dispatch(KeyEvent(key: .pageDown))
        let buffer = renderToBuffer(view, context: context)
        let content = buffer.lines.joined(separator: "\n")

        #expect(content.contains("Row 3") || content.contains("Row 4"))
        #expect(content.contains("↑ more"))
    }
}
