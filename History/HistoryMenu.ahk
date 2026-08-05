#Requires AutoHotkey v2.0

ShowHistoryMenu(isReturning := false) {
    if AppState.History.Length == 0 {
        ShowToolTip(Lang("MSG_NO_HISTORY"), 1500)
        return
    }

    if !isReturning {
        MouseGetPos(&x, &y)
        AppState.MenuPosX := x
        AppState.MenuPosY := y
        CapturePasteTarget()
    }

    menuItems := []
    total := AppState.History.Length
    displayCount := Min(total, AppState.MAX_VISIBLE_MENU)

    Loop displayCount {
        idx := A_Index
        item := AppState.History[idx]
        timeInfo := SubStr(item["time"], 12, 5)
        label := idx ". [" timeInfo "] " _ClipText(item["text"], 32)

        menuItems.Push({
            label: label,
            callback: CreateHistoryPasteCallback(idx),
            isSep: false
        })
    }

    if total > AppState.MAX_VISIBLE_MENU {
        menuItems.Push({
            label: "",
            callback: "",
            isSep: true
        })

        menuItems.Push({
            label: "📋 " Lang("HISTORY_MENU_VIEW_FULL", "", total),
            callback: CreateShowFullHistoryCallback(),
            isSep: false
        })
    }

    ; --- Accurate height pre-calculation ---
    ; These values MUST match CustomMenu.itemH, CustomMenu.sepH, CustomMenu.topPad.
    ; If you change those constants in CustomMenu.ahk, update these as well.
    static ITEM_H := 34, SEP_H := 9, TOP_PAD := 16

    estimatedH := TOP_PAD
    for entry in menuItems
        estimatedH += entry.isSep ? SEP_H : ITEM_H

    ; Get the working area of the monitor where the cursor is located.
    ; Working area excludes the taskbar, unlike A_ScreenHeight.
    monIdx := _FindMonitorIndex(AppState.MenuPosX, AppState.MenuPosY)
    MonitorGetWorkArea(monIdx, &waLeft, &waTop, &waRight, &waBottom)

    ; Apply the same 75% max-height scaling that CustomMenu.BuildAndShow uses.
    maxAllowed := (waBottom - waTop) * 0.75
    if estimatedH > maxAllowed {
        ratio := maxAllowed / estimatedH
        scaledItemH := Max(Integer(ITEM_H * ratio), 22)
        scaledSepH := Max(Integer(SEP_H * ratio), 4)
        scaledTopPad := Max(Integer(TOP_PAD * ratio), 6)
        estimatedH := scaledTopPad
        for entry in menuItems
            estimatedH += entry.isSep ? scaledSepH : scaledItemH
    }

    ; If the menu's bottom edge would land in or below the taskbar area,
    ; flip it upward: shift the anchor Y so the menu expands above the cursor.
    ; Keep a 12px margin from the working area bottom for safety.
    menuBottom := AppState.MenuPosY + estimatedH
    if (menuBottom > waBottom - 12)
        AppState.MenuPosY := Max(AppState.MenuPosY - estimatedH - 12, waTop)

    CustomMenu.ShowWithItems(AppState.MenuPosX, AppState.MenuPosY, menuItems)
}

; --- Internal helpers (not dependent on CustomMenu being loaded) ---

; Truncate text to fit within maxUnits display width units.
; ASCII = 1 unit, non-ASCII (CJK, emoji, etc.) = 2 units.
; Mirrors CustomMenu.ClipLabel logic but self-contained for #Include order independence.
_ClipText(text, maxUnits := 32) {
    text := RegExReplace(String(text), "\s+", " ")
    text := Trim(text)
    if text == ""
        return "(empty)"

    ; Fast path: short enough to never need truncation
    if StrLen(text) <= maxUnits // 2
        return StrReplace(text, "&", "&&")

    out := ""
    units := 0
    Loop Parse, text {
        ch := A_LoopField
        w := Ord(ch) > 127 ? 2 : 1
        if units + w > maxUnits {
            out .= "…"
            break
        }
        out .= ch
        units += w
    }
    return StrReplace(out, "&", "&&")
}

; Given screen coordinates (x, y), returns the monitor index (1-based)
; whose bounding rectangle contains the point. Falls back to the primary monitor.
_FindMonitorIndex(x, y) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &mL, &mT, &mR, &mB)
        if x >= mL && x < mR && y >= mT && y < mB
            return A_Index
    }
    return MonitorGetPrimary()
}

CreateHistoryPasteCallback(index) {
    return (*) => PasteHistoryByIndex(index)
}

CreateShowFullHistoryCallback() {
    return (*) => ShowFullHistoryGui()
}

PasteHistoryByIndex(index) {
    item := HistoryManager.Get(index)
    if !IsObject(item) {
        ShowToolTip(Lang("MSG_NO_HISTORY"), 1200)
        return
    }

    PasteAsFile(item)
}
