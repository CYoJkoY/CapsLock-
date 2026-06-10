#Requires AutoHotkey v2.0

#Include "libs/ClipboardManager/MathUtils.ahk"
#Include "libs/ClipboardManager/WindowUtils.ahk"
#Include "libs/ClipboardManager/ClipboardCore.ahk"
#Include "libs/ClipboardManager/FileValidation.ahk"
#Include "libs/ClipboardManager/FileOperations.ahk"
#Include "libs/ClipboardManager/ClipboardPaste.ahk"
#Include "libs/ClipboardManager/ImageToPdf.ahk"

global ImageFormats := [
    "png",
    "jpg",
    "jpeg",
    "bmp",
    "gif",
    "tiff"
]
global ImageMagickExe := ""
global LastManualClipboard := ""
global TargetWindow := ""
