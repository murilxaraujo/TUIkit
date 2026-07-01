//  🖥️ TUIKit — Terminal UI Kit for Swift
//  TUIkitPreviewTests.swift
//
//  Created by LAYERED.work
//  License: MIT

import Testing
import TUIkit
import TUIkitPreview

@Suite("TUIkitPreview")
@MainActor
struct TUIkitPreviewTests {
    @Test("Preview renders into requested size")
    func previewRendersIntoRequestedSize() {
        let preview = TUIPreview("Greeting", width: 20, height: 5) {
            Text("Hello")
        }

        let buffer = preview.render()

        #expect(buffer.lines.map(\.stripped) == ["Hello"])
        #expect(buffer.width == 5)
    }

    @Test("Preview size clamps to a valid terminal canvas")
    func previewSizeClamps() {
        let size = TUIPreviewSize(width: 0, height: -10)

        #expect(size.width == 1)
        #expect(size.height == 1)
    }

    @Test("Preview IDs are URL and CLI friendly")
    func previewID() {
        let preview = TUIPreview("Main Dashboard / Empty State") {
            Text("Empty")
        }

        #expect(preview.id == "main-dashboard-empty-state")
    }

    @Test("Preview builder supports conditionals and arrays")
    func previewBuilder() {
        let includeExtra = true
        let previews = buildPreviews(includeExtra: includeExtra)

        #expect(previews.map(\.id) == ["one", "two", "extra"])
    }

    @Test("Registry stores descriptors in registration order")
    func registryStoresDescriptors() {
        TUIkitPreviewRegistry.reset()
        defer { TUIkitPreviewRegistry.reset() }

        TUIkitPreviewRegistry.register(TUIPreview("One") { Text("1") }.descriptor)
        TUIkitPreviewRegistry.register(TUIPreview("Two") { Text("2") }.descriptor)

        #expect(TUIkitPreviewRegistry.all().map(\.id) == ["one", "two"])
        #expect(TUIkitPreviewRegistry.find(idOrName: "two")?.name == "Two")
        #expect(TUIkitPreviewRegistry.find(idOrName: "ONE")?.id == "one")
    }

    @Test("Registry ignores duplicate identifiers")
    func registryIgnoresDuplicateIDs() {
        TUIkitPreviewRegistry.reset()
        defer { TUIkitPreviewRegistry.reset() }

        TUIkitPreviewRegistry.register(TUIPreview("Duplicate", id: "same") { Text("A") }.descriptor)
        TUIkitPreviewRegistry.register(TUIPreview("Duplicate Again", id: "same") { Text("B") }.descriptor)

        #expect(TUIkitPreviewRegistry.all().map(\.name) == ["Duplicate"])
    }

    @Test("Preview size parses CLI form")
    func previewSizeParsesCLIForm() throws {
        let size = try #require(TUIPreviewSize(string: "100x30"))
        let unicodeSize = try #require(TUIPreviewSize(string: "48×12"))

        #expect(size == TUIPreviewSize(width: 100, height: 30))
        #expect(unicodeSize == TUIPreviewSize(width: 48, height: 12))
        #expect(TUIPreviewSize(string: "bad") == nil)
    }

    private func buildPreviews(includeExtra: Bool) -> [TUIPreview] {
        TUIPreviewBuilder.buildBlock(
            TUIPreviewBuilder.buildExpression(TUIPreview("One") { Text("1") }),
            TUIPreviewBuilder.buildExpression([TUIPreview("Two") { Text("2") }]),
            includeExtra
                ? TUIPreviewBuilder.buildEither(first: TUIPreviewBuilder.buildExpression(TUIPreview("Extra") { Text("3") }))
                : TUIPreviewBuilder.buildEither(second: [])
        )
    }
}
