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
    style := DllCall("GetClassLong", "Ptr", hwnd, "Int", GCL_STYLE)
    style |= CS_DROPSHADOW
    DllCall("SetClassLong", "Ptr", hwnd, "Int", GCL_STYLE, "Ptr", style)
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
    global currentMenuGui, MenuSettings

    if currentMenuGui != 0 && WinExist("ahk_id " currentMenuGui) {
        FadeOutWindow(currentMenuGui)
        WinClose("ahk_id " currentMenuGui)
    }

    items := groupObj.HasOwnProp("items") ? groupObj.items : []
    if items.Length = 0 {
        ShowTooltipNearMouse("该菜单组没有项目")
        return
    }

    ; 创建窗口（无标题栏，始终置顶）
    menuGui := Gui("-Caption +AlwaysOnTop +ToolWindow +Owner +E0x02000000")
    menuGui.BackColor := MenuSettings.Background
    menuGui.SetFont("s" MenuSettings.FontSize, MenuSettings.FontName)
    menuGui.OnEvent("Escape", (*) => CloseMenu())
    menuGui.OnEvent("Close", (*) => CloseMenu())

    ; 窗口尺寸
    menuWidth := 300
    leftMargin := 15
    rightMargin := 15

    ; === 标题 ===
    titleBg := menuGui.Add("Text", "x0 y0 w" menuWidth " h45 Center +0x200")
    titleBg.SetFont("s13 bold c" SubStr(MenuSettings.TitleText, 3), MenuSettings.FontName)
    titleBg.Value := groupObj.HasOwnProp("name") ? groupObj.name : ""

    ; === 菜单项 ===
    y := 55
    btnHeight := 42
    btnGap := 6
    numberWidth := 30
    btnWidth := menuWidth - leftMargin - numberWidth - rightMargin

    for i, item in items {
        itemName := item.HasOwnProp("name") ? item.name : ""
        if itemName = ""
            continue

        numText := (i <= 9) ? String(i) : "0"

        ; 序号
        numLabel := menuGui.Add("Text",
            "x" (leftMargin + 5) " y" (y + 10) " w24 h24 BackgroundTrans Center",
            numText)
        numLabel.SetFont("s12 bold c" SubStr(MenuSettings.Accent, 3), MenuSettings.FontName)

        ; 按钮（Win11 原生圆角 + 悬停效果）
        btn := menuGui.Add("Button",
            "x" (leftMargin + 30) " y" y " w" btnWidth " h" btnHeight " -TabStop",
            "  " itemName)
        btn.SetFont("s10 c" SubStr(MenuSettings.Text, 3), MenuSettings.FontName)

        btn_handler := MakeMenuItemHandler(groupIndex, i)
        btn.OnEvent("Click", btn_handler)

        y += btnHeight + btnGap
    }

    ; === 关闭按钮 ===
    y += 8
    closeBtn := menuGui.Add("Button",
        "x" leftMargin " y" y " w" (menuWidth - leftMargin - rightMargin) " h36 -TabStop", "关闭")
    closeBtn.SetFont("s10 c" SubStr(MenuSettings.Text, 3), MenuSettings.FontName)
    closeBtn.OnEvent("Click", (*) => CloseMenu())

    y += 44
    guiHeight := y

    ; === 居中显示 ===
    menuGui.Show("x" (A_ScreenWidth / 2 - menuWidth / 2)
        " y" (A_ScreenHeight / 2 - guiHeight / 2)
        " w" menuWidth " h" guiHeight)
    currentMenuGui := menuGui.Hwnd

    EnableRoundedCorners(currentMenuGui)
    EnableWindowShadow(currentMenuGui)
    FadeInWindow(currentMenuGui)

    ; 自动关闭（点击外部）
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
