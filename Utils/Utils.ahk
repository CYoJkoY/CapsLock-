#Requires AutoHotkey v2.0

; ═══════════════════════════════════════════
; 打开历史记录文件夹
; ═══════════════════════════════════════════
OpenHistoryFolder() {
    historyDir := A_ScriptDir "\configs"
    if !DirExist(historyDir) {
        try DirCreate(historyDir)
    }
    Run('explorer.exe "' historyDir '"')
}

; ═══════════════════════════════════════════
; 切换自动清理
; ═══════════════════════════════════════════
ToggleAutoClean() {
    AppState.AutoCleanEnabled := !AppState.AutoCleanEnabled

    if AppState.AutoCleanEnabled {
        SetTimer(AutoCleanHistory, 60000)
        ShowToolTip(Lang("MSG_AUTOCLEAN_ON", , "Auto-clean enabled"), 1500)
    } else {
        SetTimer(AutoCleanHistory, 0)
        ShowToolTip(Lang("MSG_AUTOCLEAN_OFF", , "Auto-clean disabled"), 1500)
    }

    ; ✅ 修复：统一使用 ConfigManager 保存设置
    ConfigManager.Save()
}

; ═══════════════════════════════════════════
; 自动清理逻辑
; ═══════════════════════════════════════════
AutoCleanHistory() {
    if !AppState.AutoCleanEnabled
        return

    maxItems := AppState.MaxHistoryItems
    if (maxItems <= 0)
        return

    if (AppState.History.Length > maxItems) {
        while (AppState.History.Length > maxItems)
            AppState.History.Pop()

        ; ✅ 修复：调用 HistoryManager 的保存方法（而非不存在的 SaveHistory）
        HistoryManager.ScheduleSave()
    }
}
