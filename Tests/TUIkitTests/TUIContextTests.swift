//  🖥️ TUIKit — Terminal UI Kit for Swift
//  TUIContextTests.swift
//
//  Created by LAYERED.work
//  License: MIT

import Testing

@testable import TUIkit

@MainActor
@Suite("TUIContext Tests")
struct TUIContextTests {

    @Test("Services are independent per context")
    func independentServices() {
        let contextA = TUIContext()
        let contextB = TUIContext()
        // Each context has its own lifecycle manager
        contextA.lifecycle.recordAppear(token: "a") {}
        #expect(contextA.lifecycle.hasAppeared(token: "a") == true)
        #expect(contextB.lifecycle.hasAppeared(token: "a") == false)
    }

    @Test("Render caches are independent per context")
    func renderCachesAreIndependent() {
        let contextA = TUIContext()
        let contextB = TUIContext()
        let identity = ViewIdentity(rootType: TestContextView.self)

        contextA.renderCache.store(
            identity: identity,
            view: Text("Cached"),
            buffer: FrameBuffer(lines: ["Cached"]),
            contextWidth: 10,
            contextHeight: 1
        )

        #expect(contextA.renderCache.count == 1)
        #expect(contextB.renderCache.isEmpty)
    }

    @Test("State changes invalidate owning context render cache")
    func stateChangesInvalidateOwningContextRenderCache() {
        let context = TUIContext()
        let identity = ViewIdentity(rootType: TestContextView.self)
        let key = StateStorage.StateKey(identity: identity, propertyIndex: 0)
        let box: StateBox<Int> = context.stateStorage.storage(for: key, default: 0)

        context.renderCache.store(
            identity: identity,
            view: Text("Cached"),
            buffer: FrameBuffer(lines: ["Cached"]),
            contextWidth: 10,
            contextHeight: 1
        )

        box.value = 1

        #expect(context.renderCache.isEmpty)
    }

    @Test("reset clears all services")
    func resetClears() {
        let context = TUIContext()
        context.lifecycle.recordAppear(token: "test") {}
        context.preferences.setValue("value", forKey: TestContextStringKey.self)
        context.keyEventDispatcher.addHandler { _ in true }

        context.reset()

        #expect(context.lifecycle.hasAppeared(token: "test") == false)
        #expect(context.preferences.current[TestContextStringKey.self] == "default")
    }

    @Test("Preferences storage is functional")
    func preferencesWork() {
        let context = TUIContext()
        context.preferences.setValue("hello", forKey: TestContextStringKey.self)
        #expect(context.preferences.current[TestContextStringKey.self] == "hello")
    }

    @Test("KeyEventDispatcher is functional")
    func dispatcherWorks() {
        let context = TUIContext()
        nonisolated(unsafe) var handled = false
        context.keyEventDispatcher.addHandler { _ in
            handled = true
            return true
        }
        context.keyEventDispatcher.dispatch(KeyEvent(key: .enter))
        #expect(handled == true)
    }
}

/// Test preference key for TUIContext tests.
private struct TestContextStringKey: PreferenceKey {
    static let defaultValue: String = "default"
}

private struct TestContextView: View {
    var body: some View {
        Text("Test")
    }
}
