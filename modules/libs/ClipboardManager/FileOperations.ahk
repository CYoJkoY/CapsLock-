#Requires AutoHotkey v2.0

#Include "MathUtils.ahk"

ReadMultipleFilesAsText(filePaths) {
    local result := ""
    local timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")

    for idx, filePath in filePaths {
        filePath := Trim(filePath)
        if (filePath = "") {
            continue
        }
        result .= BuildFileHeader(filePath, timestamp)
        result .= ReadFileContentSafe(filePath)
    }
    return RTrim(result, "`n")
}

BuildFileHeader(filePath, timestamp) {
    local fileName := ""
    SplitPath(filePath, &fileName)
    local fileSize := FileGetSize(filePath)
    local sizeStr := FormatBytes(fileSize)

    local header := "; =========================================================================`n"
    header .= "; FILE: " filePath "`n"
    header .= "; NAME: " fileName " | SIZE: " sizeStr " | TIME: " timestamp "`n"
    header .= "; =========================================================================`n"
    return header
}

ReadFileContentSafe(filePath) {
    try {
        local content := FileRead(filePath, "UTF-8")
        return content "`n`n"
    } catch as err {
        return "[ERROR: Failed to read file - " err.Message "]`n`n"
    }
}
