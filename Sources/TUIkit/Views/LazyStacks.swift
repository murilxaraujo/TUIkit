//  🖥️ TUIKit — Terminal UI Kit for Swift
//  LazyStacks.swift
//
//  Created by LAYERED.work
//  License: MIT

// MARK: - LazyVStack

/// A view that arranges its children in a line that grows vertically,
/// creating items only as needed.
///
/// Unlike ``VStack``, which renders all views immediately, `LazyVStack`
/// measures its children and renders only those inside the visible height.
///
/// Use `LazyVStack` when you have a large number of items or want to
/// defer rendering of offscreen content.
///
/// # Example
///
/// ```swift
/// ScrollView {
///     LazyVStack {
///         ForEach(1...1000, id: \.self) { i in
///             Text("Row \(i)")
///         }
///     }
/// }
/// ```
///
/// - Note: When used in ``ScrollView``, all children are measured to determine
///   the total content height, but only visible children are rendered. Child
///   creation and measurement can still visit every collection element.
public struct LazyVStack<Content: View>: View {
    /// The horizontal alignment of the children.
    public let alignment: HorizontalAlignment

    /// The vertical spacing between children.
    public let spacing: Int

    /// The content of the stack.
    public let content: Content

    /// Creates a lazy vertical stack with the specified options.
    ///
    /// - Parameters:
    ///   - alignment: The horizontal alignment of children (default: .center).
    ///   - spacing: The spacing between children in lines (default: 0).
    ///   - content: A ViewBuilder that defines the children.
    public init(
        alignment: HorizontalAlignment = .center,
        spacing: Int = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        _LazyVStackCore(alignment: alignment, spacing: spacing, content: content)
    }
}

// MARK: - Internal LazyVStack Core

/// Internal view that handles the actual rendering of LazyVStack.
private struct _LazyVStackCore<Content: View>: View, Renderable, Layoutable {
    let alignment: HorizontalAlignment
    let spacing: Int
    let content: Content

    var body: Never {
        fatalError("_LazyVStackCore renders via Renderable")
    }

    func sizeThatFits(proposal: ProposedSize, context: RenderContext) -> ViewSize {
        let (_, sizes) = measureChildren(context: context, width: proposal.width ?? context.availableWidth)
        let totalHeight = sizes.reduce(0) { $0 + $1.height } + max(0, sizes.count - 1) * spacing
        let maxWidth = sizes.map(\.width).max() ?? 0
        return ViewSize(
            width: proposal.width ?? maxWidth,
            height: totalHeight,
            isWidthFlexible: true,
            isHeightFlexible: sizes.contains(where: \.isHeightFlexible)
        )
    }

    func renderToBuffer(context: RenderContext) -> FrameBuffer {
        let viewport = context.environment.scrollViewport
        let (children, sizes) = measureChildren(context: context, width: context.availableWidth)
        let spacerCount = children.filter(\.isSpacer).count
        let fixedHeight = zip(children, sizes).reduce(0) { total, pair in
            total + (pair.0.isSpacer ? 0 : pair.1.height)
        }
        let totalSpacing = max(0, children.count - 1) * spacing
        let availableForSpacers = max(0, context.availableHeight - fixedHeight - totalSpacing)
        let spacerHeight = spacerCount > 0 ? availableForSpacers / spacerCount : 0
        let spacerRemainder = spacerCount > 0 ? availableForSpacers % spacerCount : 0
        let childMaxWidth = sizes.map(\.width).max() ?? 0
        let maxWidth = spacerCount > 0 ? context.availableWidth : childMaxWidth

        var childHeights: [Int] = []
        var spacerIndex = 0
        for (child, size) in zip(children, sizes) {
            if child.isSpacer {
                let extraHeight = spacerIndex < spacerRemainder ? 1 : 0
                childHeights.append(max(child.spacerMinLength ?? 0, spacerHeight + extraHeight))
                spacerIndex += 1
            } else {
                childHeights.append(size.height)
            }
        }

        let totalHeight = childHeights.reduce(0, +) + totalSpacing
        let outputHeight = viewport == nil ? min(totalHeight, context.availableHeight) : totalHeight
        var lines = Array(repeating: "", count: outputHeight)
        let visibleTop = viewport?.offset ?? 0
        let visibleBottom = visibleTop + (viewport?.height ?? context.availableHeight)
        var contentLineOffset = 0

        for index in children.indices {
            let childHeight = childHeights[index]
            if childHeight > 0 && contentLineOffset < visibleBottom && contentLineOffset + childHeight > visibleTop {
                let childBuffer: FrameBuffer
                if children[index].isSpacer {
                    childBuffer = FrameBuffer(emptyWithHeight: childHeight)
                } else {
                    childBuffer = children[index].render(
                        width: maxWidth,
                        height: childHeight,
                        context: context
                    )
                }
                let aligned = alignBuffer(childBuffer, toWidth: maxWidth, alignment: alignment)
                for lineIndex in 0..<min(childHeight, aligned.height) where contentLineOffset + lineIndex < outputHeight {
                    lines[contentLineOffset + lineIndex] = aligned.lines[lineIndex]
                }
            }
            contentLineOffset += childHeight + (index + 1 < children.count ? spacing : 0)
        }

        return FrameBuffer(lines: lines)
    }

    private func measureChildren(context: RenderContext, width: Int) -> ([ChildView], [ViewSize]) {
        let children = resolveChildViews(from: content, context: context)
        let measureContext = context.withPhase(.measure)
        let proposal = ProposedSize(width: width, height: nil)
        let sizes = children.map { $0.measure(proposal: proposal, context: measureContext) }
        return (children, sizes)
    }

    /// Aligns a buffer horizontally within the given width.
    private func alignBuffer(_ buffer: FrameBuffer, toWidth width: Int, alignment: HorizontalAlignment) -> FrameBuffer {
        guard buffer.width < width else { return buffer }

        var alignedLines: [String] = []

        let bufferOffset: Int
        switch alignment {
        case .leading:
            bufferOffset = 0
        case .center:
            bufferOffset = (width - buffer.width) / 2
        case .trailing:
            bufferOffset = width - buffer.width
        }

        let leftPadding = String(repeating: " ", count: bufferOffset)
        let rightPaddingCount = width - bufferOffset - buffer.width

        for line in buffer.lines {
            let lineWidth = line.strippedLength
            let paddedLine = line + String(repeating: " ", count: max(0, buffer.width - lineWidth))
            alignedLines.append(leftPadding + paddedLine + String(repeating: " ", count: max(0, rightPaddingCount)))
        }

        return FrameBuffer(lines: alignedLines)
    }
}

// MARK: - LazyHStack

/// A view that arranges its children in a line that grows horizontally,
/// creating items only as needed.
///
/// Unlike ``HStack``, which renders all views immediately, `LazyHStack`
/// only renders views when they become visible. In a terminal context,
/// this means views outside the available width are not rendered.
///
/// Use `LazyHStack` when you have a large number of items or want to
/// defer rendering of offscreen content.
///
/// # Example
///
/// ```swift
/// ScrollView(.horizontal) {
///     LazyHStack {
///         ForEach(1...1000, id: \.self) { i in
///             Text("Column \(i)")
///         }
///     }
/// }
/// ```
///
/// - Note: In TUIKit's terminal context, lazy rendering is based on
///   `availableWidth` in the render context. Items beyond this width
///   are not rendered until they scroll into view.
public struct LazyHStack<Content: View>: View {
    /// The vertical alignment of the children.
    public let alignment: VerticalAlignment

    /// The horizontal spacing between children.
    public let spacing: Int

    /// The content of the stack.
    public let content: Content

    /// Creates a lazy horizontal stack with the specified options.
    ///
    /// - Parameters:
    ///   - alignment: The vertical alignment of children (default: .center).
    ///   - spacing: The spacing between children in characters (default: 1).
    ///   - content: A ViewBuilder that defines the children.
    public init(
        alignment: VerticalAlignment = .center,
        spacing: Int = 1,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        _LazyHStackCore(alignment: alignment, spacing: spacing, content: content)
    }
}

// MARK: - Internal LazyHStack Core

/// Internal view that handles the actual rendering of LazyHStack.
private struct _LazyHStackCore<Content: View>: View, Renderable {
    let alignment: VerticalAlignment
    let spacing: Int
    let content: Content

    var body: Never {
        fatalError("_LazyHStackCore renders via Renderable")
    }

    func renderToBuffer(context: RenderContext) -> FrameBuffer {
        let infos = resolveChildInfos(from: content, context: context)

        // Lazy rendering: only render items that fit within availableWidth
        let availableWidth = context.availableWidth

        // Spacer distribution (same as HStack)
        let spacerCount = infos.filter(\.isSpacer).count
        let fixedWidth = infos.compactMap(\.buffer).reduce(0) { $0 + $1.width }
        let totalSpacing = max(0, infos.count - 1) * spacing

        let availableForSpacers = max(0, availableWidth - fixedWidth - totalSpacing)
        let spacerWidth = spacerCount > 0 ? availableForSpacers / spacerCount : 0
        let spacerRemainder = spacerCount > 0 ? availableForSpacers % spacerCount : 0

        var result = FrameBuffer()
        var currentWidth = 0
        var spacerIndex = 0

        for (index, info) in infos.enumerated() {
            let spacingToApply = index > 0 ? spacing : 0

            if info.isSpacer {
                let extraWidth = spacerIndex < spacerRemainder ? 1 : 0
                let width = max(info.spacerMinLength ?? 0, spacerWidth + extraWidth)

                // Lazy: check if spacer fits
                if currentWidth + spacingToApply + width > availableWidth {
                    break
                }

                let maxHeight = infos.compactMap(\.buffer).map(\.height).max() ?? 1
                let spacerBuffer = FrameBuffer(emptyWithWidth: width, height: maxHeight)
                result.appendHorizontally(spacerBuffer, spacing: spacingToApply)
                currentWidth += spacingToApply + width
                spacerIndex += 1
            } else if let buffer = info.buffer {
                // Lazy: check if item fits
                if currentWidth + spacingToApply + buffer.width > availableWidth {
                    break
                }

                result.appendHorizontally(buffer, spacing: spacingToApply)
                currentWidth += spacingToApply + buffer.width
            }
        }

        return result
    }
}

// MARK: - Equatable Conformances

extension LazyVStack: @preconcurrency Equatable where Content: Equatable {
    public static func == (lhs: LazyVStack<Content>, rhs: LazyVStack<Content>) -> Bool {
        lhs.alignment == rhs.alignment &&
        lhs.spacing == rhs.spacing &&
        lhs.content == rhs.content
    }
}

extension LazyHStack: @preconcurrency Equatable where Content: Equatable {
    public static func == (lhs: LazyHStack<Content>, rhs: LazyHStack<Content>) -> Bool {
        lhs.alignment == rhs.alignment &&
        lhs.spacing == rhs.spacing &&
        lhs.content == rhs.content
    }
}
