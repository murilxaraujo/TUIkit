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
private final class LazyRenderRecorder {
    var renderedRows: [Int] = []
}

private struct LazyRenderProbe: View, Renderable {
    let row: Int
    let recorder: LazyRenderRecorder

    var body: Never {
        fatalError("LazyRenderProbe renders directly")
    }

    func renderToBuffer(context: RenderContext) -> FrameBuffer {
        if context.allowsRenderSideEffects {
            recorder.renderedRows.append(row)
        }
        return FrameBuffer(lines: ["Row \(row)"])
    }
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

    @Test("LazyVStack renders only rows in the ScrollView viewport")
    func lazyStackRendersOnlyVisibleRows() {
        let recorder = LazyRenderRecorder()
        let view = ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading) {
                ForEach(0..<100) { row in
                    LazyRenderProbe(row: row, recorder: recorder)
                }
            }
        }

        let buffer = renderToBuffer(view, context: scrollTestContext(height: 4))

        #expect(buffer.lines.joined().contains("Row 0"))
        #expect(buffer.lines.joined().contains("Row 3"))
        #expect(!recorder.renderedRows.contains(4))
        #expect(recorder.renderedRows.count == 4)
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

        tuiContext.stateStorage.beginRenderPass()
        _ = renderToBuffer(view, context: context)
        tuiContext.stateStorage.endRenderPass()
        tuiContext.keyEventDispatcher.dispatch(KeyEvent(key: .pageDown))
        tuiContext.stateStorage.beginRenderPass()
        let buffer = renderToBuffer(view, context: context)
        tuiContext.stateStorage.endRenderPass()
        let content = buffer.lines.joined(separator: "\n")

        #expect(content.contains("Row 3") || content.contains("Row 4"))
        #expect(content.contains("↑ more"))
    }

    @Test("arrow keys stay with focused controls; page keys scroll")
    func focusedControlsKeepArrowKeys() {
        let tuiContext = TUIContext()
        let focusManager = FocusManager()
        var environment = EnvironmentValues()
        environment.focusManager = focusManager
        environment.keyEventDispatcher = tuiContext.keyEventDispatcher
        environment.stateStorage = tuiContext.stateStorage
        environment.lifecycle = tuiContext.lifecycle
        environment.renderCache = tuiContext.renderCache
        environment.statusBar = StatusBarState()
        environment.palette = SystemPalette.default
        environment.appearance = .default
        let context = RenderContext(
            availableWidth: 40,
            availableHeight: 5,
            environment: environment
        )
        let view = ScrollView {
            VStack(alignment: .leading) {
                Button("First") {}
                Button("Second") {}
                ForEach(0..<10) { index in Text("Row \(index)") }
            }
        }

        _ = renderToBuffer(view, context: context)
        let initialFocus = focusManager.currentFocusedID
        #expect(initialFocus != nil)
        #expect(!tuiContext.keyEventDispatcher.dispatch(KeyEvent(key: .down)))
        #expect(focusManager.dispatchKeyEvent(KeyEvent(key: .down)))
        #expect(focusManager.currentFocusedID != initialFocus)

        tuiContext.keyEventDispatcher.clearHandlers()
        _ = renderToBuffer(view, context: context)
        #expect(tuiContext.keyEventDispatcher.dispatch(KeyEvent(key: .pageDown)))
    }
}
