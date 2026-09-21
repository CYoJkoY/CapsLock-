#Requires AutoHotkey v2.0

class CloudSyncProviderFactory {
    static Create(providerName) {
        switch StrLower(Trim(providerName)) {
            case "gist":
                return GitHubGistProvider()
            case "github":
                return GitHubRepositoryProvider()
            case "google-drive":
                return GoogleDriveProvider()
            case "onedrive":
                return OneDriveProvider()
            case "webdav":
                return WebDavProvider()
            default:
                throw Error("Unsupported Cloud Sync provider: " providerName)
        }
    }
}


GetCloudSyncProviderKey() {
    provider := StrLower(Trim(AppState.CloudSyncProvider))

    switch provider {
        case "gist":
            return provider "|" Trim(AppState.CloudSyncTarget)

        case "github":
            return provider "|"
                Trim(AppState.CloudSyncGitHubOwner) "|"
                Trim(AppState.CloudSyncGitHubRepository) "|"
                Trim(AppState.CloudSyncGitHubBranch) "|"
                Trim(AppState.CloudSyncGitHubPath)

        case "google-drive":
            return provider "|" Trim(AppState.CloudSyncTarget)

        case "onedrive":
            return provider "|" Trim(AppState.CloudSyncOneDrivePath)

        case "webdav":
            return provider "|"
                Trim(AppState.CloudSyncWebDavUrl) "|"
                Trim(AppState.CloudSyncWebDavPath)

        default:
            return provider
    }
}
