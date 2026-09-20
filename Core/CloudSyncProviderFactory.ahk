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
