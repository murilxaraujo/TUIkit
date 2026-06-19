//  🖥️ TUIKit — Terminal UI Kit for Swift
//  ScrollView.swift
//
//  Created by LAYERED.work
//  License: MIT

/// The initial scroll position for a vertical ``ScrollView``.
public enum ScrollViewInitialAnchor: Sendable, Equatable {
    /// Start at the top of the content.
    case top

    /// Start at the bottom of the content, and keep following the bottom while
    /// the user has not manually scrolled away.
    case bottom
}

/// A vertically scrollable viewport for content that can exceed the available height.
///
/// `ScrollView` is intentionally SwiftUI-shaped for the common vertical case:
///
/// ```swift
/// ScrollView {
///     LazyVStack(alignment: .leading) {
///         ForEach(messages) { message in
///             MessageRow(message)
///         }
///     }
/// }
/// ```
///
/// In a terminal, scrolling is keyboard-driven. When the scroll view is present
/// in the hierarchy it handles `↑`, `↓`, Page Up, Page Down, Home, and End when
/// those keys are not consumed by a focused text input.
public struct ScrollView<Content: View>: View {
    let showsIndicators: Bool
    let initialAnchor: ScrollViewInitialAnchor
    let content: Content

    /// Creates a vertical scroll view.
    ///
    /// - Parameters:
    ///   - showsIndicators: Whether to render top/bottom overflow indicators.
    ///   - initialAnchor: The initial position. Use `.bottom` for chat logs.
    ///   - content: The scrollable content.
    public init(
        showsIndicators: Bool = true,
        initialAnchor: ScrollViewInitialAnchor = .top,
        @ViewBuilder content: () -> Content
    ) {
        self.showsIndicators = showsIndicators
        self.initialAnchor = initialAnchor
        self.content = content()
    }

    public var body: some View {
        _ScrollViewCore(
            showsIndicators: showsIndicators,
            initialAnchor: initialAnchor,
            content: content
        )
    }
}

// MARK: - Internal Core

private struct _ScrollViewCore<Content: View>: View, Renderable, Layoutable {
    let showsIndicators: Bool
    let initialAnchor: ScrollViewInitialAnchor
    let content: Content

    var body: Never {
        fatalError("_ScrollViewCore renders via Renderable")
    }

    func sizeThatFits(proposal: ProposedSize, context: RenderContext) -> ViewSize {
        ViewSize(
            width: proposal.width ?? 1,
            height: max(1, proposal.height ?? 1),
            isWidthFlexible: true,
            isHeightFlexible: true
        )
    }

    func renderToBuffer(context: RenderContext) -> FrameBuffer {
        let stateStorage = context.environment.stateStorage!
        let offsetKey = StateStorage.StateKey(identity: context.identity, propertyIndex: 0)
        let lastHeightKey = StateStorage.StateKey(identity: context.identity, propertyIndex: 1)
        let offsetBox: StateBox<Int> = stateStorage.storage(for: offsetKey, default: 0)
        let lastContentHeightBox: StateBox<Int> = stateStorage.storage(for: lastHeightKey, default: 0)

        let viewportHeight = max(1, context.availableHeight)
        let contentBuffer = renderContent(context: context)
        let contentHeight = contentBuffer.height
        let visibleContentCapacityAtEdge = showsIndicators && contentHeight > viewportHeight
            ? max(1, viewportHeight - 1)
            : viewportHeight
        let maxOffset = max(0, contentHeight - visibleContentCapacityAtEdge)

        let previousVisibleContentCapacityAtEdge = showsIndicators && lastContentHeightBox.value > viewportHeight
            ? max(1, viewportHeight - 1)
            : viewportHeight
        let previousMaxOffset = max(0, lastContentHeightBox.value - previousVisibleContentCapacityAtEdge)
        let wasFollowingBottom = initialAnchor == .bottom && (
            lastContentHeightBox.value == 0 || offsetBox.value >= previousMaxOffset
        )

        if wasFollowingBottom {
            offsetBox.value = maxOffset
        } else {
            offsetBox.value = min(max(0, offsetBox.value), maxOffset)
        }
        lastContentHeightBox.value = contentHeight

        registerKeyHandlers(offsetBox: offsetBox, maxOffset: maxOffset, viewportHeight: viewportHeight, context: context)

        return viewport(contentBuffer, offset: offsetBox.value, height: viewportHeight, context: context)
    }

    private func renderContent(context: RenderContext) -> FrameBuffer {
        var contentContext = context
        // Render enough content to measure and clip. This keeps ScrollView
        // correct for arbitrary content. Lazy containers can still use the
        // viewport context in future once scroll-offset environment support lands.
        contentContext.availableHeight = max(context.availableHeight, 10_000)
        contentContext.hasExplicitHeight = false
        return TUIkit.renderToBuffer(content, context: contentContext)
    }

    private func registerKeyHandlers(
        offsetBox: StateBox<Int>,
        maxOffset: Int,
        viewportHeight: Int,
        context: RenderContext
    ) {
        guard maxOffset > 0 else { return }
        context.environment.keyEventDispatcher!.addHandler { event in
            let oldOffset = offsetBox.value
            switch event.key {
            case .up:
                offsetBox.value = max(0, offsetBox.value - 1)
            case .down:
                offsetBox.value = min(maxOffset, offsetBox.value + 1)
            case .pageUp:
                offsetBox.value = max(0, offsetBox.value - max(1, viewportHeight - 1))
            case .pageDown:
                offsetBox.value = min(maxOffset, offsetBox.value + max(1, viewportHeight - 1))
            case .home:
                offsetBox.value = 0
            case .end:
                offsetBox.value = maxOffset
            default:
                return false
            }
            return offsetBox.value != oldOffset
        }
    }

    private func viewport(_ buffer: FrameBuffer, offset: Int, height: Int, context: RenderContext) -> FrameBuffer {
        guard height > 0 else { return FrameBuffer() }
        guard !buffer.lines.isEmpty else { return FrameBuffer(emptyWithHeight: height) }

        let edgeContentCapacity = showsIndicators && buffer.height > height ? max(1, height - 1) : height
        let clampedOffset = min(max(0, offset), max(0, buffer.height - edgeContentCapacity))
        let hasContentAbove = clampedOffset > 0
        let hasContentBelow = clampedOffset + edgeContentCapacity < buffer.height
        let indicatorCount = showsIndicators ? (hasContentAbove ? 1 : 0) + (hasContentBelow ? 1 : 0) : 0
        let contentHeight = max(0, height - indicatorCount)

        var lines: [String] = []
        if showsIndicators, hasContentAbove {
            lines.append(scrollIndicator(direction: .up, width: context.availableWidth, context: context))
        }

        let sliceEnd = min(buffer.height, clampedOffset + contentHeight)
        if clampedOffset < sliceEnd {
            lines.append(contentsOf: buffer.lines[clampedOffset..<sliceEnd])
        }

        if showsIndicators, hasContentBelow {
            lines.append(scrollIndicator(direction: .down, width: context.availableWidth, context: context))
        }

        if lines.count < height {
            lines.append(contentsOf: Array(repeating: "", count: height - lines.count))
        }

        return FrameBuffer(lines: lines)
    }

    private enum ScrollIndicatorDirection {
        case up
        case down
    }

    private func scrollIndicator(
        direction: ScrollIndicatorDirection,
        width: Int,
        context: RenderContext
    ) -> String {
        let label = switch direction {
        case .up: "↑ more"
        case .down: "↓ more"
        }
        let padded = label.padToVisibleWidth(max(label.count, width))
        return ANSIRenderer.colorize(padded, foreground: context.environment.palette.foregroundTertiary)
    }
}
