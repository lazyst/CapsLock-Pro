; =====================================================================
; CapsLock++ 快捷菜单系统模块
; 包含：菜单组配置、菜单GUI创建/显示/关闭、菜单项执行、热键绑定等
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
    global forceKeepMenu

    if (!MenuSettings.AnimationEnabled) {
        return
    }

    forceKeepMenu := true
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
    forceKeepMenu := false
}

FadeOutWindow(hwnd, duration := 100) {
    if (!MenuSettings.AnimationEnabled) {
        return
    }

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

CheckActiveWindow(*) {
    global currentMenuGui, forceKeepMenu

    if (forceKeepMenu)
        return

    if (!currentMenuGui || !WinExist("ahk_id " currentMenuGui))
        return

    try {
        activeWin := WinGetID("A")

        if (activeWin != currentMenuGui) {
            CloseMenu()
        }
    } catch Error as e {
        CloseMenu()
    }
}

InitMenuGroups() {
    global menuGroupNum, enableGroup, groupName, groupCount, MenuGroups

    menuGroupNum := ReadIniValueUTF8(A_ScriptDir "\CapsLock++.ini", "MenuGroupNum", "num", "0")
    menuGroupNum := Integer(menuGroupNum)

    enableGroup := []
    groupName := []
    groupCount := []

    loop 10 {
        i := A_Index
        enableGroup.Push(ReadIniValueUTF8(A_ScriptDir "\CapsLock++.ini", "MenuGroupsEnable", "enableGroup" i, "false") =
        "true")
    }

    loop 10 {
        i := A_Index
        groupName.Push(ReadIniValueUTF8(A_ScriptDir "\CapsLock++.ini", "MenuGroupName", "name" i, "组 " i))
    }

    loop 10 {
        i := A_Index
        count := ReadIniValueUTF8(A_ScriptDir "\CapsLock++.ini", "MenuGroupCount", "count" i, "0")
        groupCount.Push(Integer(count))
    }

    MenuGroups := Map()

    loop 10 {
        groupIndex := A_Index

        if (enableGroup[groupIndex]) {
            menuItems := []

            loop groupCount[groupIndex] {
                itemIndex := A_Index
                sectionName := "MenuGroups" groupIndex "Items"

                itemName := ReadIniValueUTF8(A_ScriptDir "\CapsLock++.ini", sectionName, "name" itemIndex, "")
                itemIcon := ReadIniValueUTF8(A_ScriptDir "\CapsLock++.ini", sectionName, "icon" itemIndex, "")
                itemIconType := ReadIniValueUTF8(A_ScriptDir "\CapsLock++.ini", sectionName, "icontype" itemIndex, "")
                itemActionStr := ReadIniValueUTF8(A_ScriptDir "\CapsLock++.ini", sectionName, "action" itemIndex, "")

                if (itemName != "") {
                    itemAction := GetActionFromString(itemActionStr)

                    menuItems.Push({
                        name: itemName,
                        icon: itemIcon,
                        iconType: itemIconType,
                        action: itemAction
                    })
                }
            }

            MenuGroups[groupIndex] := {
                name: groupName[groupIndex],
                items: menuItems
            }
        }
    }
}

GetActionFromString(actionStr) {
    actionStr := Trim(actionStr)

    switch actionStr {
        case "ManageProcessWithCtrlCheck(`"启用`")": return (*) => ManageProcessWithCtrlCheck("启用")
        case "ManageProcessWithCtrlCheck(`"终止`")": return (*) => ManageProcessWithCtrlCheck("终止")
        case "SendInput(`"#d`")": return (*) => SendInput("#d")
        case "WebsiteLogin()": return (*) => WebsiteLogin()

        default:
            websiteLoginPattern := 'i)^WebsiteLogin\(\s*"(.*?)"\s*\)$'
            if RegExMatch(actionStr, websiteLoginPattern, &wlMatch) {
                wlUrl := wlMatch[1]
                return (*) => WebsiteLogin(wlUrl)
            }

            runCmdPattern := 'i)^RunCommand\(\s*"(.*?)"\s*,\s*"(.*?)"\s*\)$'
            if RegExMatch(actionStr, runCmdPattern, &cmdMatch) {
                cmdStr := cmdMatch[1]
                workdir := cmdMatch[2]
                return (*) => RunCommand(cmdStr, workdir)
            }

            pattern := 'i)^ActivateOrRun\(\s*"(.*?)"\s*,\s*(.*?)\s*\)$'

            if RegExMatch(actionStr, pattern, &match) {
                param1 := match[1]
                param2Raw := Trim(match[2])

                param2 := ""

                if (param2Raw = "A_MyDocuments") {
                    param2 := A_MyDocuments
                } else if (param2Raw = "A_UserProfile") {
                    param2 := EnvGet("USERPROFILE")
                } else if (SubStr(param2Raw, 1, StrLen("A_UserProfile")) = "A_UserProfile") {
                    pathPart := Trim(SubStr(param2Raw, StrLen("A_UserProfile") + 1))
                    if (SubStr(pathPart, 1, 1) = '"')
                        pathPart := SubStr(pathPart, 2)
                    if (SubStr(pathPart, -0) = '"')
                        pathPart := SubStr(pathPart, 1, -1)
                    param2 := EnvGet("USERPROFILE") . pathPart
                } else if (SubStr(param2Raw, 1, StrLen("A_MyDocuments")) = "A_MyDocuments") {
                    pathPart := Trim(SubStr(param2Raw, StrLen("A_MyDocuments") + 1))
                    if (SubStr(pathPart, 1, 1) = '"')
                        pathPart := SubStr(pathPart, 2)
                    if (SubStr(pathPart, -0) = '"')
                        pathPart := SubStr(pathPart, 1, -1)
                    param2 := A_MyDocuments . pathPart
                } else {
                    pathPart := param2Raw
                    if (SubStr(pathPart, 1, 1) = '"')
                        pathPart := SubStr(pathPart, 2)
                    if (SubStr(pathPart, -0) = '"')
                        pathPart := SubStr(pathPart, 1, -1)
                    param2 := pathPart
                }

                return (*) => ActivateOrRun(param1, param2)

            } else {
                ToolTip("GetActionFromString 无法解析: " actionStr)
                SetTimer(() => ToolTip(), -3000)
                return (*) => {}
            }
    }
}

CheckReloadSignal() {
    signalFile := A_ScriptDir "\.reload_signal"
    if (FileExist(signalFile)) {
        try {
            FileDelete(signalFile)
            ReloadMenuGroups()
            ToolTip("配置已重新加载")
            SetTimer(() => ToolTip(), -2000)
        } catch {
        }
    }
}

ReloadMenuGroups() {
    global menuGroupNum, enableGroup, groupName, groupCount, MenuGroups, iniFile

    menuGroupNum := ReadIniValueUTF8(iniFile, "MenuGroupNum", "num", "0")
    menuGroupNum := Integer(menuGroupNum)

    enableGroup := []
    groupName := []
    groupCount := []

    loop 10 {
        i := A_Index
        enableGroup.Push(ReadIniValueUTF8(iniFile, "MenuGroupsEnable", "enableGroup" i, "false") = "true")
    }

    loop 10 {
        i := A_Index
        groupName.Push(ReadIniValueUTF8(iniFile, "MenuGroupName", "name" i, "组 " i))
    }

    loop 10 {
        i := A_Index
        count := ReadIniValueUTF8(iniFile, "MenuGroupCount", "count" i, "0")
        groupCount.Push(Integer(count))
    }

    MenuGroups := Map()

    loop 10 {
        groupIndex := A_Index

        if (enableGroup[groupIndex]) {
            menuItems := []

            loop groupCount[groupIndex] {
                itemIndex := A_Index
                sectionName := "MenuGroups" groupIndex "Items"

                itemName := ReadIniValueUTF8(iniFile, sectionName, "name" itemIndex, "")
                itemIcon := ReadIniValueUTF8(iniFile, sectionName, "icon" itemIndex, "")
                itemIconType := ReadIniValueUTF8(iniFile, sectionName, "icontype" itemIndex, "")
                itemActionStr := ReadIniValueUTF8(iniFile, sectionName, "action" itemIndex, "")

                if (itemName != "") {
                    itemAction := GetActionFromString(itemActionStr)

                    menuItems.Push({
                        name: itemName,
                        icon: itemIcon,
                        iconType: itemIconType,
                        action: itemAction
                    })
                }
            }

            MenuGroups[groupIndex] := {
                name: groupName[groupIndex],
                items: menuItems
            }
        }
    }

    loadedCount := 0
    for k, v in MenuGroups {
        if (v.HasOwnProp("items") && v.items.Length > 0)
            loadedCount++
    }
    ToolTip("已重新加载菜单配置, 共加载了 " loadedCount " 个组")
    SetTimer () => ToolTip(), -2000
}

ClearCapsLockAhkWindows() {
    try {
        winList := WinGetList()
        clearedCount := 0

        for hwnd in winList {
            title := WinGetTitle("ahk_id " hwnd)

            if (InStr(title, "CapsLock++.ahk")) {
                style := WinGetStyle("ahk_id " hwnd)

                if (style = 0x940A0000) {
                    WinClose("ahk_id " hwnd)
                    clearedCount++
                }
            }
        }
    } catch as e {
    }
}

IsMenuGroupEmpty(groupIndex) {
    global MenuGroups

    if (!MenuGroups.Has(groupIndex)) {
        return true
    }

    currentGroup := MenuGroups[groupIndex]

    if (!currentGroup.HasOwnProp("items") || currentGroup.items.Length = 0) {
        return true
    }

    return false
}

ShowMenu(groupIndex) {
    global currentMenuGui, currentMenuGroup

    ClearCapsLockAhkWindows()
    if (currentMenuGui && WinExist("ahk_id " currentMenuGui)) {
        try {
            WinClose("ahk_id " currentMenuGui)
            Sleep(50)
        } catch {
        }
        currentMenuGui := 0
        currentMenuGroup := 0
    }

    if (!MenuGroups.Has(groupIndex)) {
        return
    }

    currentGroup := MenuGroups[groupIndex]

    if (!currentGroup.HasOwnProp("items") || currentGroup.items.Length = 0) {
        return
    }

    CreateMenuGUI(currentGroup, groupIndex)

    currentMenuGroup := groupIndex
}

GetCharWidthMap() {
    charWidthMap := Map()
    charWidthMap[" "] := 4
    charWidthMap["!"] := 4
    charWidthMap["`""] := 6
    charWidthMap["#"] := 9
    charWidthMap["$"] := 8
    charWidthMap["%"] := 12
    charWidthMap["&"] := 0
    charWidthMap["'"] := 4
    charWidthMap["("] := 5
    charWidthMap[")"] := 5
    charWidthMap["*"] := 6
    charWidthMap["+"] := 10
    charWidthMap[","] := 4
    charWidthMap["-"] := 6
    charWidthMap["."] := 4
    charWidthMap["/"] := 6
    charWidthMap["0"] := 8
    charWidthMap["1"] := 8
    charWidthMap["2"] := 8
    charWidthMap["3"] := 8
    charWidthMap["4"] := 8
    charWidthMap["5"] := 8
    charWidthMap["6"] := 8
    charWidthMap["7"] := 8
    charWidthMap["8"] := 8
    charWidthMap["9"] := 8
    charWidthMap[":"] := 4
    charWidthMap[";"] := 4
    charWidthMap["<"] := 10
    charWidthMap["="] := 10
    charWidthMap[">"] := 10
    charWidthMap["?"] := 7
    charWidthMap["@"] := 14
    charWidthMap["A"] := 10
    charWidthMap["B"] := 9
    charWidthMap["C"] := 9
    charWidthMap["D"] := 11
    charWidthMap["E"] := 8
    charWidthMap["F"] := 7
    charWidthMap["G"] := 10
    charWidthMap["H"] := 11
    charWidthMap["I"] := 4
    charWidthMap["J"] := 6
    charWidthMap["K"] := 9
    charWidthMap["L"] := 7
    charWidthMap["M"] := 13
    charWidthMap["N"] := 11
    charWidthMap["O"] := 11
    charWidthMap["P"] := 9
    charWidthMap["Q"] := 12
    charWidthMap["R"] := 9
    charWidthMap["S"] := 8
    charWidthMap["T"] := 8
    charWidthMap["U"] := 10
    charWidthMap["V"] := 9
    charWidthMap["W"] := 14
    charWidthMap["X"] := 9
    charWidthMap["Y"] := 9
    charWidthMap["Z"] := 9
    charWidthMap["["] := 5
    charWidthMap["\\"] := 6
    charWidthMap["]"] := 5
    charWidthMap["^"] := 10
    charWidthMap["_"] := 7
    charWidthMap["a"] := 8
    charWidthMap["b"] := 9
    charWidthMap["c"] := 7
    charWidthMap["d"] := 9
    charWidthMap["e"] := 8
    charWidthMap["f"] := 5
    charWidthMap["g"] := 9
    charWidthMap["h"] := 9
    charWidthMap["i"] := 4
    charWidthMap["j"] := 4
    charWidthMap["k"] := 8
    charWidthMap["l"] := 4
    charWidthMap["m"] := 13
    charWidthMap["n"] := 9
    charWidthMap["o"] := 9
    charWidthMap["p"] := 9
    charWidthMap["q"] := 9
    charWidthMap["r"] := 6
    charWidthMap["s"] := 7
    charWidthMap["t"] := 5
    charWidthMap["u"] := 9
    charWidthMap["v"] := 7
    charWidthMap["w"] := 11
    charWidthMap["x"] := 7
    charWidthMap["y"] := 8
    charWidthMap["z"] := 7
    charWidthMap["{"] := 5
    charWidthMap["|"] := 4
    charWidthMap["}"] := 5
    charWidthMap["中"] := 14
    charWidthMap["文"] := 14
    charWidthMap["测"] := 14
    charWidthMap["试"] := 14
    return charWidthMap
}

CalculateTextWidth(text, charWidthMap) {
    width := 0
    defaultCharWidth := 7
    spaceWidth := charWidthMap.Has(" ") ? charWidthMap[" "] : 4

    for i, char in StrSplit(text) {
        if (char = " " && spaceWidth > 0)
            width += spaceWidth
        else if (charWidthMap.Has(char))
            width += charWidthMap[char]
        else if (Ord(char) > 127)
            width += charWidthMap.Has("中") ? charWidthMap["中"] : 14
        else
            width += defaultCharWidth
    }

    return width
}

CreateMenuGUI(menuGroup, groupIndex) {
    global currentMenuGui, checkActiveTimerId

    menuGui := Gui("-Caption +AlwaysOnTop +ToolWindow +Owner +E0x02000000")
    menuGui.BackColor := MenuSettings.Background

    currentMenuGui := menuGui.Hwnd

    EnableRoundedCorners(menuGui.Hwnd, MenuSettings.CornerRadius)

    titleBg := menuGui.Add("Text", "x0 y0 w300 h45 Background" MenuSettings.TitleBg " Center +0x200")
    titleBg.SetFont("s13 bold c" MenuSettings.TitleText, MenuSettings.FontName)
    titleBg.Value := menuGroup.name

    if (menuGroup.HasOwnProp("items") && menuGroup.items.Length > 0) {
        y := 55
        leftMargin := 15
        rightMargin := 15
        numWidth := 30
        btnWidth := 300 - leftMargin - numWidth - rightMargin
        btnHeight := 42
        btnGap := 6

        charWidthMap := GetCharWidthMap()
        spaceWidth := charWidthMap.Has(" ") ? charWidthMap[" "] : 4
        if (spaceWidth <= 0) spaceWidth := 4
            iconOffsetPixels := 0
        iconTextGapPixels := 15

        maxTextWidthPixels := 0
        for i, item in menuGroup.items {
            if (i > 12)
                continue
            textWidth := CalculateTextWidth(item.name, charWidthMap)
            if (textWidth > maxTextWidthPixels)
                maxTextWidthPixels := textWidth
        }

        for i, item in menuGroup.items {
            if (i > 12)
                break

            numText := (i <= 9) ? String(i) : "0"
            numLabel := menuGui.Add("Text", "x" (leftMargin + 5) " y" (y + 10) " w24 h24 BackgroundTrans Center",
            numText)
            numLabel.SetFont("s12 bold c" MenuSettings.Accent, MenuSettings.FontName)

            prefixSpaceCount := Ceil(iconOffsetPixels / spaceWidth)
            prefixSpaces := ""
            loop prefixSpaceCount {
                prefixSpaces .= " "
            }

            gapSpaceCount := Ceil(iconTextGapPixels / spaceWidth)
            gapSpaces := ""
            loop gapSpaceCount {
                gapSpaces .= " "
            }

            totalContentWidthPixels := iconOffsetPixels + iconTextGapPixels + maxTextWidthPixels
            currentTextWidth := CalculateTextWidth(item.name, charWidthMap)
            currentTotalWidth := iconOffsetPixels + iconTextGapPixels + currentTextWidth
            textGapPixels := totalContentWidthPixels - currentTotalWidth
            suffixSpaceCount := Ceil(textGapPixels / spaceWidth)

            suffixSpaces := ""
            loop suffixSpaceCount {
                suffixSpaces .= " "
            }

            btnX := leftMargin + 30
            btnTextX := btnX + 8

            if (item.HasOwnProp("iconType") && item.iconType = "file") {
                fullBtnText := prefixSpaces gapSpaces item.name suffixSpaces

                btn := menuGui.Add("Button", "x" btnX " y" y " w" btnWidth " h" btnHeight " -TabStop Background" MenuSettings.ButtonBg, fullBtnText)
                try {
                    btn.SetFont("s10 c" MenuSettings.Text, MenuSettings.FontName)
                    AddButtonIcon(btn, item.icon)
                } catch Error as e {
                    btn.Text := fullBtnText
                }
            } else {
                fullBtnText := prefixSpaces item.icon gapSpaces item.name suffixSpaces
                btn := menuGui.Add("Button", "x" btnX " y" y " w" btnWidth " h" btnHeight " -TabStop Background" MenuSettings.ButtonBg, fullBtnText)
                btn.SetFont("s10 c" MenuSettings.Text, MenuSettings.FontName)
            }

            btn.OnEvent("Click", item.action)

            y += btnHeight + btnGap
        }
    }

    y += 8
    closeBtnWidth := 300 - leftMargin - rightMargin
    closeBtn := menuGui.Add("Button", "x" leftMargin " y" y " w" closeBtnWidth " h36 Background" MenuSettings.ButtonBg, "关闭")
    closeBtn.SetFont("s10 c" MenuSettings.Text, MenuSettings.FontName)
    closeBtn.OnEvent("Click", (*) => CloseMenu())

    y += 44
    guiHeight := y
    menuWidth := 300

    CoordMode("Mouse", "Screen")
    MouseGetPos(&mouseX, &mouseY)
    MonitorGetWorkArea(1, &WLeft, &WTop, &WRight, &WBottom)
    menuCenterX := menuWidth
    menuCenterY := guiHeight
    guiX := mouseX - menuCenterX
    guiY := mouseY - menuCenterY

    if (showDebugTooltips) {
        ToolTip("鼠标位置: X=" mouseX " Y=" mouseY "`n"
            . "菜单尺寸: W=" menuWidth " H=" guiHeight "`n"
            . "菜单中心点: X=" (guiX + menuCenterX) " Y=" (guiY + menuCenterY))
        SetTimer () => ToolTip(), -3000
    }

    if (guiX + 2 * menuWidth > WRight)
        guiX := WRight - 2 * menuWidth
    if (guiX < WLeft)
        guiX := WLeft
    if (guiY + 2 * guiHeight > WBottom)
        guiY := WBottom - 2 * guiHeight
    if (guiY < WTop)
        guiY := WTop

    menuGui.Show("x" guiX " y" guiY " w" menuWidth " h" guiHeight)
    FadeInWindow(menuGui.Hwnd)

    menuGui.OnEvent("Escape", (*) => CloseMenu())
    checkActiveTimerId := SetTimer(CheckActiveWindow, 50)
    menuGui.OnEvent("ContextMenu", (*) => CloseMenu())
}

CloseMenu() {
    global currentMenuGui, currentMenuGroup, checkActiveTimerId, forceKeepMenu

    ClearCapsLockAhkWindows()

    forceKeepMenu := false

    if (currentMenuGui && WinExist("ahk_id " currentMenuGui)) {
        FadeOutWindow(currentMenuGui)
        WinClose("ahk_id " currentMenuGui)
    }

    currentMenuGui := 0
    currentMenuGroup := 0

    if (checkActiveTimerId) {
        SetTimer(checkActiveTimerId, 0)
        checkActiveTimerId := 0
    }
}

ExecuteMenuItem(groupIndex, itemIndex) {
    if (!MenuGroups.Has(groupIndex)) {
        return
    }

    menuGroup := MenuGroups[groupIndex]

    if (!menuGroup.HasOwnProp("items") || itemIndex < 1 || itemIndex > menuGroup.items.Length) {
        return
    }

    menuGroup.items[itemIndex].action()
}

#HotIf GetKeyState("CapsLock", "P") && isToolEnabled
1::
{
    global otherKeyPressed := true
    global currentMenuGroup

    ShowMenu(1)
}

2::
{
    global otherKeyPressed := true
    global currentMenuGroup

    ShowMenu(2)
}

3::
{
    global otherKeyPressed := true
    global currentMenuGroup

    ShowMenu(3)
}

4::
{
    global otherKeyPressed := true
    global currentMenuGroup

    ShowMenu(4)
}

5::
{
    global otherKeyPressed := true
    global currentMenuGroup

    ShowMenu(5)
}

6::
{
    global otherKeyPressed := true
    global currentMenuGroup

    ShowMenu(6)
}

7::
{
    global otherKeyPressed := true
    global currentMenuGroup

    ShowMenu(7)
}

8::
{
    global otherKeyPressed := true
    global currentMenuGroup

    ShowMenu(8)
}

9::
{
    global otherKeyPressed := true
    global currentMenuGroup

    if (IsMenuGroupEmpty(9)) {
        SendText("(")
    } else {
        ShowMenu(9)
    }
}

0::
{
    global otherKeyPressed := true
    global currentMenuGroup

    if (IsMenuGroupEmpty(10)) {
        SendText(")")
    } else {
        ShowMenu(10)
    }
}
#HotIf

#HotIf WinActive("ahk_id " currentMenuGui)
1::
{
    global currentMenuGroup

    try {
        if (MenuGroups.Has(currentMenuGroup)) {
            if (MenuGroups[currentMenuGroup].HasOwnProp("items") && MenuGroups[currentMenuGroup].items.Length >= 1) {
                ExecuteMenuItem(currentMenuGroup, 1)
            }
        }
    } catch Error as e {
    }
}

2::
{
    global currentMenuGroup

    try {
        if (MenuGroups.Has(currentMenuGroup)) {
            if (MenuGroups[currentMenuGroup].HasOwnProp("items") && MenuGroups[currentMenuGroup].items.Length >= 2) {
                ExecuteMenuItem(currentMenuGroup, 2)
            }
        }
    } catch Error as e {
    }
}

3::
{
    global currentMenuGroup
    try {
        if (MenuGroups.Has(currentMenuGroup)) {
            if (MenuGroups[currentMenuGroup].HasOwnProp("items") && MenuGroups[currentMenuGroup].items.Length >= 3) {
                ExecuteMenuItem(currentMenuGroup, 3)
            }
        }
    } catch Error as e {
    }
}

4::
{
    global currentMenuGroup

    try {
        if (MenuGroups.Has(currentMenuGroup)) {
            if (MenuGroups[currentMenuGroup].HasOwnProp("items") && MenuGroups[currentMenuGroup].items.Length >= 4) {
                ExecuteMenuItem(currentMenuGroup, 4)
            }
        }
    } catch Error as e {
    }
}

5::
{
    global currentMenuGroup

    try {
        if (MenuGroups.Has(currentMenuGroup)) {
            if (MenuGroups[currentMenuGroup].HasOwnProp("items") && MenuGroups[currentMenuGroup].items.Length >= 5) {
                ExecuteMenuItem(currentMenuGroup, 5)
            }
        }
    } catch Error as e {
    }
}

6::
{
    global currentMenuGroup

    try {
        if (MenuGroups.Has(currentMenuGroup)) {
            if (MenuGroups[currentMenuGroup].HasOwnProp("items") && MenuGroups[currentMenuGroup].items.Length >= 6) {
                ExecuteMenuItem(currentMenuGroup, 6)
            }
        }
    } catch Error as e {
    }
}

7::
{
    global currentMenuGroup

    try {
        if (MenuGroups.Has(currentMenuGroup)) {
            if (MenuGroups[currentMenuGroup].HasOwnProp("items") && MenuGroups[currentMenuGroup].items.Length >= 7) {
                ExecuteMenuItem(currentMenuGroup, 7)
            }
        }
    } catch Error as e {
    }
}

8::
{
    global currentMenuGroup

    try {
        if (MenuGroups.Has(currentMenuGroup)) {
            if (MenuGroups[currentMenuGroup].HasOwnProp("items") && MenuGroups[currentMenuGroup].items.Length >= 8) {
                ExecuteMenuItem(currentMenuGroup, 8)
            }
        }
    } catch Error as e {
    }
}

9::
{
    global currentMenuGroup

    try {
        if (MenuGroups.Has(currentMenuGroup)) {
            if (MenuGroups[currentMenuGroup].HasOwnProp("items") && MenuGroups[currentMenuGroup].items.Length >= 9) {
                ExecuteMenuItem(currentMenuGroup, 9)
            }
        }
    } catch Error as e {
    }
}

0::
{
    global currentMenuGroup

    try {
        if (MenuGroups.Has(currentMenuGroup)) {
            if (MenuGroups[currentMenuGroup].HasOwnProp("items") && MenuGroups[currentMenuGroup].items.Length >= 10) {
                ExecuteMenuItem(currentMenuGroup, 10)
            }
        }
    } catch Error as e {
    }
}

Escape:: CloseMenu()
#HotIf

ActivateOrRun(processName, runCommand) {
    CloseMenu()

    windowFound := false

    if (InStr(processName, "http://") || InStr(processName, "https://")) {
        url := processName

        domainStart := InStr(url, "://") + 3
        domainEnd := InStr(url, "/", false, domainStart)
        if (domainEnd = 0) {
            domainEnd := StrLen(url) + 1
        }
        domain := SubStr(url, domainStart, domainEnd - domainStart)

        try {
            browserWindows := WinGetList("ahk_exe msedge.exe")

            for hwnd in browserWindows {
                try {
                    winTitle := WinGetTitle("ahk_id " hwnd)

                    if (InStr(winTitle, domain)) {
                        WinActivate("ahk_id " hwnd)
                        windowFound := true
                        break
                    }
                } catch Error as e {
                }
            }

            if (!windowFound) {
                browserWindows := WinGetList("ahk_exe chrome.exe")
                for hwnd in browserWindows {
                    try {
                        winTitle := WinGetTitle("ahk_id " hwnd)
                        if (InStr(winTitle, domain)) {
                            WinActivate("ahk_id " hwnd)
                            windowFound := true
                            break
                        }
                    } catch Error as e {
                    }
                }
            }

            if (!windowFound) {
                browserWindows := WinGetList("ahk_exe firefox.exe")
                for hwnd in browserWindows {
                    try {
                        winTitle := WinGetTitle("ahk_id " hwnd)
                        if (InStr(winTitle, domain)) {
                            WinActivate("ahk_id " hwnd)
                            windowFound := true
                            break
                        }
                    } catch Error as e {
                    }
                }
            }
        } catch Error as e {
        }
    } else if (processName = "explorer.exe") {
        try {
            explorerWindows := WinGetList("ahk_class CabinetWClass")

            for hwnd in explorerWindows {
                try {
                    winTitle := WinGetTitle("ahk_id " hwnd)

                    targetPath := StrReplace(runCommand, "explorer.exe ")

                    SplitPath(targetPath, &targetFolderName)
                    if (targetFolderName = "") {
                        targetFolderName := targetPath
                    }

                    if (InStr(winTitle, targetFolderName)) {
                        WinActivate("ahk_id " hwnd)
                        windowFound := true
                        break
                    }
                } catch Error as e {
                }
            }
        } catch Error as e {
        }
    } else {
        try {
            if (WinExist("ahk_exe " processName)) {
                WinActivate("ahk_exe " processName)
                windowFound := true
            }
        } catch Error as e {
        }
    }

    if (!windowFound) {
        if (runCommand = "wt`"") {
            Run("wt -d" EnvGet("USERPROFILE"))
            return
        }
        try {
            Run('"' runCommand '"')
        } catch Error as e {
            ShowTooltipNearMouse("无法启动程序: `nAction: <" runCommand ">`nError: " e.Message)
        }
    }
}

AdjustVolume(amount) {
    Send("{Volume_Up " amount "}")
}

OpenFolder(path) {
    Run("explorer.exe " path)
}

LaunchApp(exePath) {
    Run(exePath)
}

OpenWebsite(url) {
    Run(url)
}

ExecuteCommand(cmd) {
    Run(A_ComSpec " /c " cmd)
}

AddButtonIcon(ButtonCtrl, IconFile, IconNumber := 1, IconSize := 30) {
    if (InStr(IconFile, ",")) {
        parts := StrSplit(IconFile, ",")
        if (parts.Length >= 2) {
            dllPath := Trim(parts[1])
            iconIndex := Trim(parts[2])

            hIcon := LoadPicture(dllPath, "w" IconSize " h" IconSize " Icon" iconIndex, &imgType)
        } else {
            hIcon := LoadPicture(IconFile, "w" IconSize " h" IconSize, &imgType)
        }
    } else {
        hIcon := LoadPicture(IconFile, "w" IconSize " h" IconSize, &imgType)
    }

    SendMessage(0xF7, IconNumber, hIcon, ButtonCtrl)

    return hIcon
}

RunCommand(cmdStr, workdir := "") {
    if (workdir = "")
        workdir := A_Desktop
    try {
        Run(cmdStr, workdir)
        ShowTooltipNearMouse("执行: " cmdStr)
    } catch Error as e {
        ShowTooltipNearMouse("执行失败: " e.Message, 3000)
    }
}
