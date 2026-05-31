; =========================== Hotkeys ===========================

*CapsLock:: {
    if !(A_PriorKey = "CapsLock")
        return

    if (A_TimeSincePriorHotkey > 300 || A_TimeSincePriorHotkey < 50)
        return

    if GetKeyState("CapsLock", "T")
        SetCapsLockState "AlwaysOff"
    else
        SetCapsLockState "AlwaysOn"
}

#HotIf GetKeyState("CapsLock", "P")

Left:: Send "^{Left}"
Right:: Send "^{Right}"
Up:: Send "{Home}"
Down:: Send "{End}"

+Left:: Send "^+{Left}"
+Right:: Send "^+{Right}"
+Up:: Send "+{Home}"
+Down:: Send "+{End}"

Space:: Send "^{Left}^+{Right}"

~a:: Send "{Backspace}"
~d:: Send "{Delete}"
~+a:: Send "^{Backspace}"
~+d:: Send "^{Delete}"
~Backspace:: Send "{Home}+{End}{Delete}"
~Delete:: Send "{Home}+{End}{Delete}"

e:: Send "^{PgDn}"
q:: Send "^{PgUp}"

LButton:: {
    AdjustOpacity(20)

    if KeyWait("LButton", "T0.3")
        return

    while GetKeyState("LButton", "P") {
        AdjustOpacity(5)
        Sleep 50
    }
}

RButton:: {
    AdjustOpacity(-20)

    if KeyWait("RButton", "T0.3")
        return

    while GetKeyState("RButton", "P") {
        AdjustOpacity(-5)
        Sleep 50
    }
}

MButton:: {
    hwnd := WinExist("A")
    currentTrans := WinGetTransparent(hwnd)

    if (currentTrans = "" || currentTrans = 255)
        WinSetTransparent(10, hwnd)
    else
        WinSetTransparent(255, hwnd)
}

w::
8::
Numpad8:: {
    if WinGetMinMax("A") = 1
        WinRestore "A"
    else
        WinMaximize "A"
}

s::
2::
Numpad2:: WinMinimize "A"

c:: {
    global IgnoreNextClipChange

    IgnoreNextClipChange := true
    text := CopyAsPlainText()
    IgnoreNextClipChange := false

    if (text != "")
        AddToHistory(text, "Plain Text Copy")
}

v:: {
    global LastManualClipboard, ClipboardHistory, IgnoreNextClipChange

    if (IsImagePathsText(A_Clipboard)) {
        tempPDFPath := ProcessImagePathsToPDF()

        if (tempPDFPath = "") {
            ToolTip "Failed to create PDF"
            SetTimer () => ToolTip(), -2000
            return
        }

        PasteFile(tempPDFPath, "pdf")
        return
    }

    currentClip := A_Clipboard

    if (currentClip != "" && !InStr(currentClip, A_Temp "\ClipTemp_"))
        LastManualClipboard := currentClip

    targetText := (LastManualClipboard != "") ? LastManualClipboard : currentClip

    if (targetText = "") {
        ToolTip "Clipboard is empty, please copy content first"
        SetTimer () => ToolTip(), -2000
        return
    }

    if DllCall("OpenClipboard", "Ptr", A_ScriptHwnd) {
        DllCall("EmptyClipboard")
        DllCall("CloseClipboard")
    }

    sourceInfo := ""

    for item in ClipboardHistory {
        if (item["text"] = targetText) {
            sourceInfo := "Copied from: " item["source"] " (at " item["time"] ")"
            break
        }
    }

    if (sourceInfo = "")
        sourceInfo := "Source: (Direct Paste via Hotkey) | Time: " FormatTime(, "yyyy-MM-dd HH:mm:ss")

    fullContent := "; " sourceInfo "`n`n" targetText
    tempFile := A_Temp "\ClipTemp_" A_TickCount ".txt"
    FileAppend fullContent, tempFile, "UTF-8"
    SetClipboardFile(tempFile)
    Send "^v"

    ScheduleFileDeletion(tempFile)

    SetTimer () => (
        (LastManualClipboard != "") ? (A_Clipboard := LastManualClipboard) : ""
    ), -10000

    SetTimer () => ToolTip(), -2000
}

+v:: ShowHistoryMenu()

f:: {
    global LastManualClipboard, IgnoreNextClipChange

    sourceText := (LastManualClipboard != "") ? LastManualClipboard : A_Clipboard

    if (sourceText = "") {
        ToolTip "No text to paste. Please copy something first."
        SetTimer () => ToolTip(), -1500
        return
    }

    if !RegExMatch(sourceText, "[a-zA-Z]", &match) {
        ToolTip "No English letters found"
        SetTimer () => ToolTip(), -1500
        return
    }

    firstChar := match[0]
    newText := (firstChar ~= "[A-Z]") ? StrLower(sourceText) : StrUpper(sourceText)

    prevCapsState := GetKeyState("CapsLock", "T")

    if prevCapsState
        SetCapsLockState("AlwaysOff")

    IgnoreNextClipChange := true
    A_Clipboard := newText
    Send "^v"
    Sleep 200

    IgnoreNextClipChange := true
    A_Clipboard := sourceText

    if prevCapsState
        SetCapsLockState("AlwaysOn")
}

#HotIf
