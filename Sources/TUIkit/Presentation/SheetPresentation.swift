//  🖥️ TUIKit — Terminal UI Kit for Swift
//  SheetPresentation.swift
//
//  Created by LAYERED.work
//  License: MIT

import Foundation

public extension View {
    /// Presents a sheet when a binding to a Boolean value is true.
    ///
    /// Terminal sheets currently share TUIkit's centered modal presentation
    /// mechanics: the background is dimmed and rendered inert, while focus and
    /// keyboard input are routed to the presented content.
    func sheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modal(isPresented: isPresented, content: content)
    }
}
