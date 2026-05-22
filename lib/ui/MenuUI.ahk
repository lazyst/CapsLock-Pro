; =====================================================================
; CapsLock++ 菜单UI
; =====================================================================

CreateMenuGUI(groupObj, groupIndex) {
    global currentMenuGui

    if currentMenuGui != 0 && WinExist("ahk_id " currentMenuGui) {
        WinClose("ahk_id " currentMenuGui)
    }

    items := groupObj.HasOwnProp("items") ? groupObj.items : []
    if items.Length = 0 {
        ShowTooltipNearMouse("该菜单组没有项目")
        return
    }

    gui := Gui("+AlwaysOnTop +ToolWindow +Border", groupObj.HasOwnProp("name") ? groupObj.name : "菜单")
    gui.SetFont("s10", "Segoe UI")
    gui.MarginX := 0
    gui.MarginY := 0
    gui.OnEvent("Escape", (*) => CloseMenu())
    gui.OnEvent("Close", (*) => CloseMenu())

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

    gui.BackColor := bgColor

    for i, item in items {
        itemName := item.HasOwnProp("name") ? item.name : ""
        if itemName = ""
            continue

        btn := gui.Add("Text", "x0 y" ((i - 1) * 36) " w280 h36 Center 0x200", "  " itemName)
        btn.SetFont("s10", "Segoe UI")
        btn.OnEvent("Click", MakeMenuItemHandler(groupIndex, i))
        btn.OnEvent("DoubleClick", MakeMenuItemHandler(groupIndex, i))
    }

    gui.Show("x" (A_ScreenWidth / 2 - 140) " y" (A_ScreenHeight / 2 - items.Length * 18) " w280 h" (items.Length * 36))
    currentMenuGui := gui.Hwnd
}

MakeMenuItemHandler(groupIndex, itemIndex) {
    return (*) => ExecuteMenuItem(groupIndex, itemIndex)
}

CloseMenu() {
    global currentMenuGui
    try {
        if currentMenuGui != 0 && WinExist("ahk_id " currentMenuGui) {
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
}
