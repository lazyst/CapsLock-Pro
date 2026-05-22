; =====================================================================
; CapsLock++ 菜单UI
; 包含：圆角窗口、阴影、淡入淡出动画、悬停效果、点击外部自动关闭
; =====================================================================

EnableRoundedCorners(hwnd, radius := 12) {
    DWMWA_WINDOW_CORNER_PREFERENCE := 33
    DWMWCP_ROUND := 2
    prefBuf := Buffer(4)
    NumPut("UInt", DWMWCP_ROUND, prefBuf)
    DllCall("dwmapi\DwmSetWindowAttribute",
        "Ptr", hwnd,
        "UInt", DWMWA_WINDOW_CORNER_PREFERENCE,
        "Ptr", prefBuf.Ptr,
        "UInt", 4)
}

EnableWindowShadow(hwnd) {
    CS_DROPSHADOW := 0x20000
    GCL_STYLE := -26
    style := DllCall("GetClassLongPtr", "Ptr", hwnd, "Int", GCL_STYLE, "Ptr")
    style |= CS_DROPSHADOW
    DllCall("SetClassLongPtr", "Ptr", hwnd, "Int", GCL_STYLE, "Ptr", style)
}

FadeInWindow(hwnd, duration := 150) {
    try {
        WinSetTransparent(0, "ahk_id " hwnd)
        steps := 15
        stepDuration := duration / steps
        loop steps {
            alpha := Round(255 * (A_Index / steps))
            WinSetTransparent(alpha, "ahk_id " hwnd)
            Sleep(stepDuration)
        }
        WinSetTransparent("Off", "ahk_id " hwnd)
    }
}

FadeOutWindow(hwnd, duration := 100) {
    try {
        steps := 10
        stepDuration := duration / steps
        loop steps {
            alpha := Round(255 * (1 - A_Index / steps))
            WinSetTransparent(alpha, "ahk_id " hwnd)
            Sleep(stepDuration)
        }
    }
}

CreateMenuGUI(groupObj, groupIndex) {
    global currentMenuGui

    if currentMenuGui != 0 && WinExist("ahk_id " currentMenuGui) {
        FadeOutWindow(currentMenuGui)
        WinClose("ahk_id " currentMenuGui)
    }

    items := groupObj.HasOwnProp("items") ? groupObj.items : []
    if items.Length = 0 {
        ShowTooltipNearMouse("该菜单组没有项目")
        return
    }

    menuGui := Gui("+AlwaysOnTop +ToolWindow +Border", groupObj.HasOwnProp("name") ? groupObj.name : "菜单")
    menuGui.SetFont("s10", "Segoe UI")
    menuGui.MarginX := 0
    menuGui.MarginY := 0
    menuGui.OnEvent("Escape", (*) => CloseMenu())
    menuGui.OnEvent("Close", (*) => CloseMenu())

    settings := GetConfigManager().GetSettings()
    isDark := settings.HasOwnProp("ui") && settings.ui.HasOwnProp("darkMode") ? settings.ui.darkMode : false

    if isDark {
        bgColor := "1e1e2e"
        textColor := "cdd6f4"
        hoverBg := "313244"
    } else {
        bgColor := "ffffff"
        textColor := "1e1e2e"
        hoverBg := "f5f5f5"
    }

    menuGui.BackColor := bgColor

    for i, item in items {
        itemName := item.HasOwnProp("name") ? item.name : ""
        if itemName = ""
            continue

        colorOpt := isDark ? " c" textColor : ""
        btn := menuGui.Add("Text", "x0 y" ((i - 1) * 36) " w280 h36 Center 0x200" colorOpt, "  " itemName)
        btn.SetFont("s10", "Segoe UI")

        btn_handler := MakeMenuItemHandler(groupIndex, i)

        btn.OnEvent("Click", btn_handler)
        btn.OnEvent("DoubleClick", btn_handler)
    }

    menuGui.Show("x" (A_ScreenWidth / 2 - 140) " y" (A_ScreenHeight / 2 - items.Length * 18) " w280 h" (items.Length * 36))
    currentMenuGui := menuGui.Hwnd

    EnableRoundedCorners(currentMenuGui)
    EnableWindowShadow(currentMenuGui)
    FadeInWindow(currentMenuGui)

    ; Auto-close when clicking outside the menu
    SetTimer(CheckMenuActive, 50)
}

CheckMenuActive() {
    global currentMenuGui
    if !currentMenuGui || !WinExist("ahk_id " currentMenuGui) {
        SetTimer(CheckMenuActive, 0)
        return
    }
    try {
        activeWin := WinGetID("A")
        if activeWin != currentMenuGui {
            CloseMenu()
            SetTimer(CheckMenuActive, 0)
        }
    }
}

MakeMenuItemHandler(groupIndex, itemIndex) {
    return (*) => ExecuteMenuItem(groupIndex, itemIndex)
}

CloseMenu() {
    global currentMenuGui
    SetTimer(CheckMenuActive, 0)
    try {
        if currentMenuGui != 0 && WinExist("ahk_id " currentMenuGui) {
            FadeOutWindow(currentMenuGui)
            WinClose("ahk_id " currentMenuGui)
        }
    } catch {
    }
    currentMenuGui := 0
}

ClearCapsLockAhkWindows() {
    global currentMenuGui
    try {
        if currentMenuGui != 0 {
            WinClose("ahk_id " currentMenuGui)
        }
    } catch {
    }
    currentMenuGui := 0
    SetTimer(CheckMenuActive, 0)
}
