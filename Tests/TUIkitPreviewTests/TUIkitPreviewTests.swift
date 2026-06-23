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
