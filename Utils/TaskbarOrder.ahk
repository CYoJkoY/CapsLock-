#Requires AutoHotkey v2.0

class TaskbarOrder {
    static _cachedOrder := []
    static _cacheValid := false
    static _lastForeground := 0

    static GetWindows() {
        freshList := this._BuildWindowList()
        
        if freshList.Length == 0
            return []

        if this._cacheValid && this._cachedOrder.Length > 0 {
            result := this._MergeWithCache(freshList)
        } else {
            result := freshList
        }

        this._cachedOrder := result.Clone()
        this._cacheValid := true
        
        return result
    }

    static _BuildWindowList() {
        result := []
        seen := Map()

        try {
            shell := ComObject("Shell.Application")
            for w in shell.Windows {
                try {
                    hwnd := w.Hwnd
                    if hwnd && WinExist("ahk_id " hwnd) {
                        if !this.IsToolWindow(hwnd) && !seen.Has(hwnd) {
                            result.Push(hwnd)
                            seen[hwnd] := true
                        }
                    }
                }
            }
        } catch {
        }

        ids := WinGetList()
        for id in ids {
            if !seen.Has(id) && !this.IsToolWindow(id) && (WinGetStyle(id) & 0x10000000) {
                result.Push(id)
                seen[id] := true
            }
        }
        
        return result
    }

    static _MergeWithCache(freshList) {
        availableSet := Map()
        for hwnd in freshList {
            availableSet[hwnd] := true
        }

        merged := []
        seen := Map()
        
        for hwnd in this._cachedOrder {
            if availableSet.Has(hwnd) && !seen.Has(hwnd) {
                merged.Push(hwnd)
                seen[hwnd] := true
            }
        }

        for hwnd in freshList {
            if !seen.Has(hwnd) {
                merged.Push(hwnd)
                seen[hwnd] := true
            }
        }
        
        return merged
    }

    static InvalidateCache() {
        this._cacheValid := false
        this._cachedOrder := []
    }

    static IsToolWindow(hwnd) {
        try {
            return (WinGetExStyle(hwnd) & 0x80) != 0
        } catch {
            return true
        }
    }
}
