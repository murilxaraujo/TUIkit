//  🖥️ TUIKit — Terminal UI Kit for Swift
//  ForEach.swift
//
//  Created by LAYERED.work
//  License: MIT

/// A view that generates views from a collection of data.
///
/// `ForEach` iterates over a collection and creates a view for each
/// element. The collection elements must be `Identifiable` or an
/// explicit ID key path must be provided.
///
/// ## Rendering
///
/// `ForEach` renders each generated child in collection order. This preserves
/// SwiftUI-style usage in stacks, panels, custom containers, and other
/// `@ViewBuilder` contexts without requiring callers to replace `ForEach` with
/// a `for` loop.
///
/// # Example with Identifiable
///
/// ```swift
/// struct Item: Identifiable {
///     let id: String
///     let name: String
/// }
///
/// let items = [Item(id: "1", name: "One"), Item(id: "2", name: "Two")]
///
/// VStack {
///     ForEach(items) { item in
///         Text(item.name)
///     }
/// }
/// ```
///
/// # Example with explicit ID key path
///
/// ```swift
/// let names = ["Anna", "Bob", "Clara"]
///
/// VStack {
///     ForEach(names, id: \.self) { name in
///         Text(name)
///     }
/// }
/// ```
public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content: View>: View {
    /// The underlying data collection.
    let data: Data

    /// The key path to the unique ID of each element.
    let idKeyPath: KeyPath<Data.Element, ID>

    /// The closure that creates a view for each element.
    let content: (Data.Element) -> Content

    /// Creates a ForEach with an explicit ID key path.
    ///
    /// - Parameters:
    ///   - data: The collection to iterate over.
    ///   - id: The key path to the unique ID of each element.
    ///   - content: The closure that creates the view for each element.
    public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.idKeyPath = id
        self.content = content
    }

    /// Never called — `ForEach` renders directly via ``Renderable``.
    public var body: Never {
        fatalError("ForEach renders via Renderable")
    }
}

// MARK: - Rendering

extension ForEach: Renderable, ChildInfoProvider {
    public func renderToBuffer(context: RenderContext) -> FrameBuffer {
        FrameBuffer(verticallyStacking: childInfos(context: context).compactMap(\.buffer))
    }

    public func childInfos(context: RenderContext) -> [ChildInfo] {
        data.enumerated().map { index, element in
            let view = content(element)
            return makeChildInfo(
                for: view,
                context: context.withChildIdentity(type: type(of: view), index: index)
            )
        }
    }
}

// MARK: - ForEach with Identifiable

extension ForEach where Data.Element: Identifiable, ID == Data.Element.ID {
    /// Creates a ForEach for Identifiable elements.
    ///
    /// - Parameters:
    ///   - data: The collection with Identifiable elements.
    ///   - content: The closure that creates the view for each element.
    public init(
        _ data: Data,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.idKeyPath = \Data.Element.id
        self.content = content
    }
}

// MARK: - ForEach with Range

extension ForEach where Data == Range<Int>, ID == Int {
    /// Creates a ForEach over an integer range.
    ///
    /// - Parameters:
    ///   - data: The range, e.g., `0..<10`.
    ///   - content: The closure that creates the view for each index.
    public init(
        _ data: Range<Int>,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self.data = data
        self.idKeyPath = \.self
        self.content = content
    }
}
