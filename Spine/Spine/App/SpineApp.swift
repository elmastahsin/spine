import SwiftUI

@main
struct SpineApp: App {
    @State private var viewModel = SpineViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environment(viewModel)
        } label: {
            Image(systemName: viewModel.menuBarIconName)
                .opacity(viewModel.menuBarIconOpacity)
        }
        .menuBarExtraStyle(.window)
    }
}
