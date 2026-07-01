//  🖥️ TUIKit — Terminal UI Kit for Swift
//  RenderInvalidationStressTests.swift
//
//  Created by LAYERED.work
//  License: MIT

import Testing

@testable import TUIkit

@MainActor
@Suite("Render Invalidation Stress Tests")
struct RenderInvalidationStressTests {

    @Test("RenderCache and TUIContext rapid state changes invalidate only the owning context cache")
    func renderCacheTUIContextRapidStateChangesPreserveContextCacheIsolation() {
        let contextA = TUIContext()
        let contextB = TUIContext()
        let parent = ViewIdentity(path: "Root/Panel")
        let child = ViewIdentity(path: "Root/Panel/Counter")
        let sibling = ViewIdentity(path: "Root/Sidebar")
        let key = StateStorage.StateKey(identity: child, propertyIndex: 0)
        let box: StateBox<Int> = contextA.stateStorage.storage(for: key, default: 0)

        for iteration in 1...100 {
            populateCache(contextA.renderCache, iteration: iteration, parent: parent, child: child, sibling: sibling)
            populateCache(contextB.renderCache, iteration: iteration, parent: parent, child: child, sibling: sibling)

            box.value = iteration

            #expect(
                contextA.renderCache.lookup(identity: parent, view: "parent-\(iteration)", contextWidth: 80, contextHeight: 24) == nil,
                "Owning context should clear ancestor cache entries affected by child state"
            )
            #expect(
                contextA.renderCache.lookup(identity: child, view: "child-\(iteration)", contextWidth: 80, contextHeight: 24) == nil,
                "Owning context should clear exact child cache entries affected by child state"
            )
            #expect(
                contextA.renderCache.lookup(identity: sibling, view: "sibling-\(iteration)", contextWidth: 80, contextHeight: 24) != nil,
                "Owning context should retain sibling cache entries during targeted state invalidation"
            )

            #expect(
                contextB.renderCache.lookup(identity: parent, view: "parent-\(iteration)", contextWidth: 80, contextHeight: 24) != nil,
                "Independent context parent cache should survive another context's state changes"
            )
            #expect(
                contextB.renderCache.lookup(identity: child, view: "child-\(iteration)", contextWidth: 80, contextHeight: 24) != nil,
                "Independent context child cache should survive another context's state changes"
            )
            #expect(
                contextB.renderCache.lookup(identity: sibling, view: "sibling-\(iteration)", contextWidth: 80, contextHeight: 24) != nil,
                "Independent context sibling cache should survive another context's state changes"
            )
        }
    }

    @Test("Rapid focus changes request rendering without clearing context caches")
    func rapidFocusChangesRequestRenderWithoutClearingCaches() {
        let appState = AppState()
        let focusManager = FocusManager()
        let contextA = TUIContext()
        let contextB = TUIContext()
        let identity = ViewIdentity(path: "Root/FocusableList")
        var focusChangeCount = 0

        focusManager.onFocusChange = {
            focusChangeCount += 1
            appState.setNeedsRender()
        }

        for index in 0..<8 {
            focusManager.register(StressFocusable(id: "item-\(index)"))
        }
        appState.didRender()
        focusChangeCount = 0

        contextA.renderCache.store(
            identity: identity,
            view: "context-a-list",
            buffer: FrameBuffer(lines: ["A"]),
            contextWidth: 80,
            contextHeight: 24
        )
        contextB.renderCache.store(
            identity: identity,
            view: "context-b-list",
            buffer: FrameBuffer(lines: ["B"]),
            contextWidth: 80,
            contextHeight: 24
        )

        for _ in 0..<200 {
            focusManager.focusNext()
        }

        #expect(focusChangeCount == 200)
        #expect(appState.needsRender == true)
        #expect(contextA.renderCache.count == 1)
        #expect(contextB.renderCache.count == 1)
        #expect(
            contextA.renderCache.lookup(identity: identity, view: "context-a-list", contextWidth: 80, contextHeight: 24) != nil
        )
        #expect(
            contextB.renderCache.lookup(identity: identity, view: "context-b-list", contextWidth: 80, contextHeight: 24) != nil
        )
    }

    @Test("PulseTimer and CursorTimer invalidations request renders while preserving context caches")
    func pulseTimerAndCursorTimerInvalidationsRequestRenderWhilePreservingContextCaches() async throws {
        let appState = AppState()
        let pulseTimer = PulseTimer(renderNotifier: appState)
        let cursorTimer = CursorTimer(renderNotifier: appState)
        let contextA = TUIContext()
        let contextB = TUIContext()
        let pulseIdentity = ViewIdentity(path: "Root/FocusPulse")
        let cursorIdentity = ViewIdentity(path: "Root/TextField/Cursor")

        for context in [contextA, contextB] {
            context.renderCache.store(
                identity: pulseIdentity,
                view: "pulse",
                buffer: FrameBuffer(lines: ["pulse"]),
                contextWidth: 80,
                contextHeight: 24
            )
            context.renderCache.store(
                identity: cursorIdentity,
                view: "cursor",
                buffer: FrameBuffer(lines: ["cursor"]),
                contextWidth: 80,
                contextHeight: 24
            )
        }

        appState.didRender()
        pulseTimer.start()
        cursorTimer.start()
        try await Task.sleep(for: .milliseconds(260))
        pulseTimer.stop()
        cursorTimer.stop()

        #expect(appState.needsRender == true)
        #expect(contextA.renderCache.count == 2)
        #expect(contextB.renderCache.count == 2)
        for context in [contextA, contextB] {
            #expect(context.renderCache.lookup(identity: pulseIdentity, view: "pulse", contextWidth: 80, contextHeight: 24) != nil)
            #expect(context.renderCache.lookup(identity: cursorIdentity, view: "cursor", contextWidth: 80, contextHeight: 24) != nil)
        }
    }

    private func populateCache(
        _ cache: RenderCache,
        iteration: Int,
        parent: ViewIdentity,
        child: ViewIdentity,
        sibling: ViewIdentity
    ) {
        cache.store(
            identity: parent,
            view: "parent-\(iteration)",
            buffer: FrameBuffer(lines: ["parent"]),
            contextWidth: 80,
            contextHeight: 24
        )
        cache.store(
            identity: child,
            view: "child-\(iteration)",
            buffer: FrameBuffer(lines: ["child"]),
            contextWidth: 80,
            contextHeight: 24
        )
        cache.store(
            identity: sibling,
            view: "sibling-\(iteration)",
            buffer: FrameBuffer(lines: ["sibling"]),
            contextWidth: 80,
            contextHeight: 24
        )
    }
}

private final class StressFocusable: Focusable {
    let focusID: String
    let canBeFocused = true

    init(id: String) {
        self.focusID = id
    }

    func onFocusReceived() {}
    func onFocusLost() {}
    func handleKeyEvent(_ event: KeyEvent) -> Bool { false }
}
