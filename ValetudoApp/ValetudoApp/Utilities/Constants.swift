import Foundation

enum Constants {
    // MARK: - GitHub API
    static let githubApiLatestReleaseUrl = "https://api.github.com/repos/Hypfer/Valetudo/releases/latest"

    // MARK: - External Links
    static let valetudoWebsiteUrl = "https://valetudo.cloud"
    static let valetudoGithubUrl = "https://github.com/Hypfer/Valetudo"
    static let appGithubUrl = "https://github.com/Revisor01/ValetudiOS"

    // MARK: - StoreKit Product IDs
    static let supportSmallId = "de.godsapp.valetudoapp.support.small"
    static let supportMediumId = "de.godsapp.valetudoapp.support.medium"
    static let supportLargeId = "de.godsapp.valetudoapp.support.large"

    static let supportProductIds: Set<String> = [
        supportSmallId,
        supportMediumId,
        supportLargeId
    ]
}
