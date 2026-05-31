; =========================== Config Management ===========================

LoadConfig() {
    global DeleteMode, DeleteDelay, CleanupInterval, ConfigFile, ImageMagickExe

    oldPath := A_ScriptDir "\ImageMagickPath.txt"

    if FileExist(oldPath) {
        try {
            legacyExe := FileRead(oldPath, "UTF-8")

            if (legacyExe != "") {
                IniWrite(legacyExe, ConfigFile, "ImageMagick", "Path")
            }

            FileDelete(oldPath)
        } catch {
            ; Migration failed, ignored.
        }
    }

    if !FileExist(ConfigFile)
        return

    try {
        DeleteMode := IniRead(ConfigFile, "Cleanup", "DeleteMode", 1)
        DeleteDelay := IniRead(ConfigFile, "Cleanup", "DeleteDelay", 10)
        CleanupInterval := IniRead(ConfigFile, "Cleanup", "CleanupInterval", 30)
        ImageMagickExe := IniRead(ConfigFile, "ImageMagick", "Path", "")
    } catch {
        ; Use default value if reading fails, do nothing
    }
}

SaveConfig() {
    global DeleteMode, DeleteDelay, CleanupInterval, ConfigFile

    try {
        IniWrite(DeleteMode, ConfigFile, "Cleanup", "DeleteMode")
        IniWrite(DeleteDelay, ConfigFile, "Cleanup", "DeleteDelay")
        IniWrite(CleanupInterval, ConfigFile, "Cleanup", "CleanupInterval")
    }
}
