#Requires AutoHotkey v2.0

class CloudSyncCredentials {
    static Get(provider, key, default := "") {
        store := this._LoadStore()
        if !store.Has(provider) || !(store[provider] is Map)
            return default

        return store[provider].Has(key)
            ? store[provider][key]
            : default
    }

    static Set(provider, key, value) {
        store := this._LoadStore()

        if !store.Has(provider)
            store[provider] := Map()

        store[provider][key] := String(value)
        return this._SaveStore(store)
    }

    static Delete(provider) {
        store := this._LoadStore()
        if store.Has(provider)
            store.Delete(provider)
        return this._SaveStore(store)
    }

    static Clear() {
        SecureStorage.Delete(AppState.CloudSyncCredentialFile)
        return true
    }

    static _LoadStore() {
        text := SecureStorage.Load(AppState.CloudSyncCredentialFile)
        if text == ""
            return Map()

        try {
            value := Json.Parse(text)
            return value is Map ? value : Map()
        } catch {
            return Map()
        }
    }

    static _SaveStore(store) {
        try {
            SecureStorage.Save(
                AppState.CloudSyncCredentialFile,
                Json.Stringify(store, false)
            )
            return true
        } catch {
            return false
        }
    }
}
