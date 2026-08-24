#Requires AutoHotkey v2.0

class TaskbarSwitch {
    static Next() {
        this.Switch(-1)
    }
    
    static Prev() {
        this.Switch(1)
    }
    
    static Switch(direction) {
        windows := TaskbarOrder.GetWindows()
        if windows.Length <= 1
            return
        
        current := WinExist("A")
        if !current {
            target := windows[1]
            if WinExist("ahk_id " target) {
                WinActivate("ahk_id " target)
            }
            return
        }

        idx := 0
        for i, hwnd in windows {
            if hwnd == current {
                idx := i
                break
            }
        }

        if idx == 0 {
            if direction > 0 {
                target := windows[1]
            } else {
                target := windows[windows.Length]
            }
            if WinExist("ahk_id " target) {
                WinActivate("ahk_id " target)
            }
            return
        }

        idx += direction

        if idx < 1
            idx := windows.Length
        if idx > windows.Length
            idx := 1
        
        target := windows[idx]
        if WinExist("ahk_id " target) {
            WinActivate("ahk_id " target)
        }
    }
}
