//  🖥️ TUIKit — Terminal UI Kit for Swift
//  TUIkitPreviewApp.swift
//
//  Created by LAYERED.work
//  License: MIT

import Foundation
import TUIkit

/// Entry point protocol for a TUIkit preview executable.
///
/// Conform from a small executable target and run it with SwiftPM:
///
/// ```swift
/// import TUIkit
/// import TUIkitPreview
///
/// @main
/// struct MyPreviews: TUIkitPreviewApp {
///     static var previews: [TUIPreview] {
///         TUIPreview("Dashboard", size: .desktop) {
///             DashboardView()
///         }
///     }
/// }
/// ```
///
/// ```bash
/// swift run MyPreviews
/// swift run MyPreviews -- --list
/// swift run MyPreviews -- --preview dashboard --width 100 --height 30
/// ```
@MainActor
public protocol TUIkitPreviewApp {
    /// The previews exposed by this executable.
    @TUIPreviewBuilder
    static var previews: [TUIPreview] { get }
}

public extension TUIkitPreviewApp {
    /// Runs the preview command-line interface.
    static func main() {
        TUIkitPreviewConsole(previews: previews).run(arguments: Array(CommandLine.arguments.dropFirst()))
    }
}

/// Terminal console presenter used by ``TUIkitPreviewApp``.
@MainActor
public struct TUIkitPreviewConsole {
    private let previews: [TUIPreview]

    /// Creates a preview console for a set of previews.
    public init(previews: [TUIPreview]) {
        self.previews = previews
    }

    /// Runs the console with command-line arguments.
    public func run(arguments: [String]) {
        let options = PreviewOptions(arguments: arguments)

        if options.help {
            print(Self.help)
            return
        }

        if options.list {
            listPreviews()
            return
        }

        guard let preview = selectedPreview(named: options.previewID) else {
            print("No preview matched '\(options.previewID ?? "")'. Use --list to see available previews.")
            return
        }

        let size = TUIPreviewSize(
            width: options.width ?? preview.size.width,
            height: options.height ?? preview.size.height
        )
        let buffer = preview.render(size: size)

        if options.snapshot {
            print(buffer.lines.joined(separator: "\n"))
        } else {
            print(Self.renderChrome(for: preview, size: size, buffer: buffer))
        }
    }

    private func listPreviews() {
        guard !previews.isEmpty else {
            print("No TUIkit previews registered.")
            return
        }

        for preview in previews {
            print("\(preview.id)\t\(preview.name)\t\(preview.size.width)x\(preview.size.height)")
        }
    }

    private func selectedPreview(named id: String?) -> TUIPreview? {
        guard let id, !id.isEmpty else { return previews.first }
        return previews.first { preview in
            preview.id == id || preview.name.localizedCaseInsensitiveCompare(id) == .orderedSame
        }
    }

    private static func renderChrome(for preview: TUIPreview, size: TUIPreviewSize, buffer: FrameBuffer) -> String {
        let title = " TUIkit Preview: \(preview.name) (\(size.width)×\(size.height)) "
        let borderWidth = max(size.width, title.count + 2)
        let top = "┌" + title.padding(toLength: borderWidth, withPad: "─", startingAt: 0) + "┐"
        let bottom = "└" + String(repeating: "─", count: borderWidth) + "┘"
        let body = normalizedLines(buffer.lines, width: borderWidth, height: size.height)
            .map { "│" + $0 + "│" }
            .joined(separator: "\n")
        let footer = "  --list  show previews    --preview <id> select    --snapshot plain output"
        return [top, body, bottom, footer].joined(separator: "\n")
    }

    private static func normalizedLines(_ lines: [String], width: Int, height: Int) -> [String] {
        let clipped = Array(lines.prefix(height))
        let padded = clipped + Array(repeating: "", count: max(0, height - clipped.count))
        return padded.map { line in
            let visible = line.strippedLength
            if visible >= width { return line.ansiAwarePrefix(visibleCount: width) }
            return line + String(repeating: " ", count: width - visible)
        }
    }

    private static let help = """
    Usage: <PreviewExecutable> [options]

    Options:
      --list                    List registered previews.
      --preview <id-or-name>     Render a specific preview. Defaults to the first preview.
      --width <columns>          Override preview width.
      --height <rows>            Override preview height.
      --snapshot                 Print only the rendered buffer, without preview chrome.
      --help                     Show this help.
    """
}

private struct PreviewOptions {
    var list = false
    var help = false
    var snapshot = false
    var previewID: String?
    var width: Int?
    var height: Int?

    init(arguments: [String]) {
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--":
                continue
            case "--list":
                list = true
            case "--help", "-h":
                help = true
            case "--snapshot":
                snapshot = true
            case "--preview", "-p":
                previewID = iterator.next()
            case "--width", "-w":
                width = iterator.next().flatMap(Int.init)
            case "--height":
                height = iterator.next().flatMap(Int.init)
            default:
                if previewID == nil {
                    previewID = argument
                }
            }
        }
    }
}
