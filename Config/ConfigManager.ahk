#Requires AutoHotkey v2.0

LoadConfig() {
    global deleteMode, deleteDelay, cleanupInterval, configFile
    global imageMagickExe, maxHistory, pasteMode

    oldPath := A_ScriptDir "\ImageMagickPath.txt"
    if FileExist( oldPath ) {
        try {
            legacyExe := FileRead( oldPath, "UTF-8" )
            if ( legacyExe != "" ) {
                IniWrite( legacyExe, configFile, "ImageMagick", "Path" )
            }
            FileDelete( oldPath )
        }
    }

    if !FileExist( configFile ) {
        return
    }

    try {
        deleteMode := IniRead( configFile, "Cleanup", "deleteMode", 1 )
        deleteDelay := IniRead( configFile, "Cleanup", "deleteDelay", 10 )
        cleanupInterval := IniRead( configFile, "Cleanup", "cleanupInterval", 30 )
        imageMagickExe := IniRead( configFile, "ImageMagick", "Path", "" )
        maxHistory := IniRead( configFile, "History", "maxHistory", 10000 )
        pasteMode := IniRead( configFile, "General", "pasteMode", 1 )
    }
}

SaveConfig() {
    global deleteMode, deleteDelay, cleanupInterval, configFile, maxHistory, pasteMode

    try {
        IniWrite( deleteMode, configFile, "Cleanup", "deleteMode" )
        IniWrite( deleteDelay, configFile, "Cleanup", "deleteDelay" )
        IniWrite( cleanupInterval, configFile, "Cleanup", "cleanupInterval" )
        IniWrite( maxHistory, configFile, "History", "maxHistory" )
        IniWrite( pasteMode, configFile, "General", "pasteMode" )
    }
}
