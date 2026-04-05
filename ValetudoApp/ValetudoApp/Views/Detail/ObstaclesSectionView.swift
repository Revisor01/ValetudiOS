import SwiftUI

struct ObstaclesSectionView: View {
    let viewModel: RobotDetailViewModel

    var body: some View {
        if viewModel.hasObstacleImages && !viewModel.obstacles.isEmpty {
            Section {
                ForEach(viewModel.obstacles, id: \.id) { obstacle in
                    NavigationLink {
                        if let api = viewModel.api {
                            ObstaclePhotoView(obstacleId: obstacle.id, label: obstacle.label, api: api)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            Text(obstacle.label ?? String(localized: "obstacle.unknown"))
                                .font(.subheadline)
                        }
                    }
                }
            } header: {
                Text(String(localized: "detail.obstacles"))
            }
        }
    }
}
