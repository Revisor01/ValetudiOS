import SwiftUI
import os

struct ObstaclePhotoView: View {
    let obstacleId: String
    let label: String?
    let api: ValetudoAPI

    @State private var imageData: Data?
    @State private var isLoading = true
    @State private var loadError = false

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "ObstaclePhoto")

    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
            } else {
                ContentUnavailableView(
                    String(localized: "obstacle.no_image"),
                    systemImage: "photo.badge.exclamationmark",
                    description: Text("obstacle.no_image.description")
                )
            }
        }
        .navigationTitle(label ?? String(localized: "obstacle.photo"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: obstacleId) {
            // Lazy-Loading — nur laden wenn View erscheint (Pitfall 5: Rate-Limit beachten)
            isLoading = true
            loadError = false
            do {
                imageData = try await api.getObstacleImage(id: obstacleId)
            } catch {
                logger.error("Failed to load obstacle image \(obstacleId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                loadError = true
            }
            isLoading = false
        }
    }
}
