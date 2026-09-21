#Requires AutoHotkey v2.0

class CloudSyncIdentity {
    static Initialize() {
        if !FileExist(AppState.CloudSyncStateFile)
            return this.GetId()

        try {
            id := IniRead(AppState.CloudSyncStateFile, "Device", "id", "")
            if id != "" {
                if AppState.CloudSyncDeviceName == ""
                    AppState.CloudSyncDeviceName := IniRead(
                        AppState.CloudSyncStateFile,
                        "Device",
                        "name",
                        ""
                    )
                return id
            }
        } catch {
        }

        return this.GetId()
    }

    static GetId() {
        if !DirExist(AppState.CloudSyncDir)
            DirCreate(AppState.CloudSyncDir)

        try {
            id := IniRead(AppState.CloudSyncStateFile, "Device", "id", "")
            if id != ""
                return id
        } catch {
        }

        id := SHA256(
            A_ComputerName
            "|" A_UserName
            "|" A_ScriptDir
            "|" A_NowUTC
            "|" A_TickCount
            "|" Random(100000, 999999)
        )

        try {
            IniWrite(id, AppState.CloudSyncStateFile, "Device", "id")
            if AppState.CloudSyncDeviceName != ""
                IniWrite(
                    AppState.CloudSyncDeviceName,
                    AppState.CloudSyncStateFile,
                    "Device",
                    "name"
                )
        } catch {
        }

        return id
    }

    static GetName() {
        if AppState.CloudSyncDeviceName != ""
            return AppState.CloudSyncDeviceName
        return A_ComputerName
    }
}
