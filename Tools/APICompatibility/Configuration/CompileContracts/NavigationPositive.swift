import TUIkit

@MainActor
func stackNavigation(path: Binding<NavigationPath>) -> some View {
    NavigationStack(path: path) {
        NavigationLink("Details", value: "details")
            .navigationDestination(for: String.self) { value in
                Text(value)
            }
    }
}
