#Requires AutoHotkey v2.0

LoadConfig() {
    global DeleteMode, DeleteDelay, CleanupInterval, ConfigFile
    global ImageMagickExe, MaxHistory, PasteMode

    oldPath := A_ScriptDir "\ImageMagickPath.txt"
    if FileExist( oldPath ) {
        try {
            legacyExe := FileRead( oldPath, "UTF-8" )
            if ( legacyExe != "" ) {
                IniWrite( legacyExe, ConfigFile, "ImageMagick", "Path" )
            }
            FileDelete( oldPath )
        }
    }

    if !FileExist( ConfigFile ) {
        return
    }

    try {
        DeleteMode := IniRead( ConfigFile, "Cleanup", "DeleteMode", 1 )
        DeleteDelay := IniRead( ConfigFile, "Cleanup", "DeleteDelay", 10 )
        CleanupInterval := IniRead( ConfigFile, "Cleanup", "CleanupInterval", 30 )
        ImageMagickExe := IniRead( ConfigFile, "ImageMagick", "Path", "" )
        MaxHistory := IniRead( ConfigFile, "History", "MaxHistory", 10000 )
        PasteMode := IniRead( ConfigFile, "General", "PasteMode", 1 )
    }
}

SaveConfig() {
    global DeleteMode, DeleteDelay, CleanupInterval, ConfigFile, MaxHistory, PasteMode

    try {
        IniWrite( DeleteMode, ConfigFile, "Cleanup", "DeleteMode" )
        IniWrite( DeleteDelay, ConfigFile, "Cleanup", "DeleteDelay" )
        IniWrite( CleanupInterval, ConfigFile, "Cleanup", "CleanupInterval" )
        IniWrite( MaxHistory, ConfigFile, "History", "MaxHistory" )
        IniWrite( PasteMode, ConfigFile, "General", "PasteMode" )
    }
}
