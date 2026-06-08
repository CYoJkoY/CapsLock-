ShowTopMostOSD(targetHwnd, isOnTop) {
    static currentOSD := ""

    ; 如果上一个 OSD 还没消失，先强制销毁它（防止快速连按导致重叠）
    if IsObject(currentOSD) {
        try currentOSD.Destroy()
        currentOSD := ""
    }

    ; 创建 OSD GUI：置顶、无标题栏、工具窗口、鼠标穿透(+E0x20)
    osd := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    osd.BackColor := "1E1E1E"
    osd.SetFont("s12 cWhite bold", "Segoe UI")

    text := isOnTop ? "📌 已置顶" : "解除置顶"
    osd.Add("Text", "w120 Center", text)

    try {
        WinGetPos(&wx, &wy, &ww, &wh, targetHwnd)
        osd.Show("Hide")
        osd.GetPos(, , &ow, &oh)

        posX := wx + (ww / 2) - (ow / 2)
        posY := wy + 10

        osd.Show("x" . posX . " y" . posY . " NoActivate")
        WinSetTransparent(0, osd)

        currentOSD := osd

        ; 【修复点】：初始调用时，传入状态 "fade_in"
        SetTimer(FadeOSD.Bind(osd, "fade_in"), -10)
    } catch {
        osd.Destroy()
    }
}

; 【修复点】：增加 state 参数，实现严格的状态机
FadeOSD(osd, state) {
    static step := 15
    static maxAlpha := 220
    static holdTime := 1200

    try {
        trans := WinGetTransparent(osd)
    } catch {
        return ; 窗口已销毁，直接退出
    }

    if (state = "fade_in") {
        if (trans < maxAlpha) {
            WinSetTransparent(trans + step, osd)
            SetTimer(FadeOSD.Bind(osd, "fade_in"), -16)
        } else {
            ; 淡入完成，进入停留阶段
            SetTimer(FadeOSD.Bind(osd, "hold"), -holdTime)
        }
    }
    else if (state = "hold") {
        ; 停留结束，进入淡出阶段
        SetTimer(FadeOSD.Bind(osd, "fade_out"), -16)
    }
    else if (state = "fade_out") {
        if (trans > 0) {
            WinSetTransparent(trans - step, osd)
            SetTimer(FadeOSD.Bind(osd, "fade_out"), -16)
        } else {
            ; 淡出完成，彻底销毁！
            try osd.Destroy()
        }
    }
}
