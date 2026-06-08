#Requires AutoHotkey v2.0

ExtractResource(source, extractPath, fileName) {
    if !DirExist(extractPath) {
        DirCreate(extractPath)
    }

    targetPath := extractPath "\" fileName

    if !FileExist(targetPath) {
        FileInstall(source, targetPath, 0)
    }

    return targetPath
}
