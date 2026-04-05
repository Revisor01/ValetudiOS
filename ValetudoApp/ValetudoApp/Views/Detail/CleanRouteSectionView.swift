import SwiftUI

struct CleanRouteSectionView: View {
    let viewModel: RobotDetailViewModel

    var body: some View {
        if viewModel.hasCleanRoute && !viewModel.cleanRoutePresets.isEmpty {
            Section {
                Picker(String(localized: "detail.clean_route"), selection: Binding(
                    get: { viewModel.currentCleanRoute },
                    set: { newValue in
                        Task { await viewModel.setCleanRoute(newValue) }
                    }
                )) {
                    ForEach(viewModel.cleanRoutePresets, id: \.self) { preset in
                        Text(preset.capitalized).tag(preset)
                    }
                }
            } header: {
                Text(String(localized: "detail.clean_route"))
            }
        }
    }
}
