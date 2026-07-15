#Requires AutoHotkey v2.0

ProcessImagePathsToPDF() {
    exe := AppState.ImageMagickExe
    if exe == "" || !FileExist( exe ) {
        MsgBox( "请先在托盘菜单中设置 ImageMagick 的 magick.exe 路径", "错误", "Iconx" )
        return ""
    }
    paths := []
    lines := StrSplit( A_Clipboard, "`n", "`r" )
    for line in lines {
        line := Trim( line )
        if line != "" && FileExist( line ) && !InStr( FileExist( line ), "D" ) {
            if FileHelper.ShouldIgnore( line )
                continue

            paths.Push( '"' line '"' )
        }
    }

    if paths.Length == 0 {
        ShowToolTip( "剪贴板中没有有效的图片文件", 2000 )
        return ""
    }

    outputPdf := A_Temp "\ClipTemp_" A_TickCount ".pdf"
    cmd := '"' exe '" ' . Join( paths, " " ) . ' -density 150 -quality 100 "' outputPdf '"'
    try {
        RunWait( cmd, , "Hide" )

        if FileExist( outputPdf ) {
            ShowToolTip( "PDF 创建成功", 2000 )
            return outputPdf
        } else {
            ShowToolTip( "PDF 创建失败（ImageMagick 执行错误）", 2000 )
            return ""
        }

    } catch as err {
        ShowToolTip( "PDF 创建失败: " err.Message, 3000 )
        return ""
    }
}

Join( arr, sep := " " ) {
    s := ""
    for v in arr
        s .= v . sep
    return SubStr( s, 1, -StrLen( sep ) )
}
