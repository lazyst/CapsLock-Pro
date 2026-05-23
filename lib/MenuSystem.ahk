; =====================================================================
; CapsLock++ 快捷菜单系统模块
; 包含：菜单组配置、菜单显示、菜单项执行、热键绑定等
; =====================================================================

#Include "ui\MenuUI.ahk"
#Include "core\ConfigManager.ahk"
#Include "core\Logger.ahk"
#Include "Utils.ahk"

; ---------------------------------------------------------------------
; InitMenuGroups - 初始化菜单组
; 使用 ConfigManager.LoadMenus() 加载菜单配置
; ---------------------------------------------------------------------
InitMenuGroups() {
    global MenuGroups, menuGroupNum, enableGroup, groupName, groupCount

    LogInfo("MenuSystem", "开始初始化菜单组")

    configManager := GetConfigManager()
    menus := configManager.LoadMenus()
    settings := configManager.GetSettings()

    if settings.HasOwnProp("ui") && settings.ui.HasOwnProp("darkMode") {
        ApplyMenuTheme.Call(settings.ui.darkMode)
    }

    MenuGroups := Map()
    enableGroup := []
    groupName := []
    groupCount := []

    loop 10 {
        enableGroup.Push(false)
        groupName.Push("组 " A_Index)
        groupCount.Push(0)
    }

    if !IsObject(menus) || !menus.HasOwnProp("groups") {
        LogWarn("MenuSystem", "菜单配置无效或为空")
        return
    }

    enabledCount := 0
    for groupData in menus.groups {
        groupIndex := groupData.HasOwnProp("id") ? groupData.id : A_Index
        groupEnabled := groupData.HasOwnProp("enabled") ? groupData.enabled : true

        if groupIndex < 1 || groupIndex > 10 {
            LogWarn("MenuSystem", "菜单组索引超出范围", { index: groupIndex })
            continue
        }

        enableGroup[groupIndex] := groupEnabled
        groupName[groupIndex] := groupData.HasOwnProp("name") ? groupData.name : ("组 " groupIndex)

        if groupEnabled {
            enabledCount++
        }

        items := []
        if groupData.HasOwnProp("items") {
            for itemData in groupData.items {
                itemName := itemData.HasOwnProp("name") ? itemData.name : ""
                if itemName = "" {
                    continue
                }

                itemAction := itemData.HasOwnProp("action") ? itemData.action : ""

                items.Push({
                    name: itemName,
                    actionConfig: itemAction
                })
            }
        }

        groupCount[groupIndex] := items.Length

        if groupEnabled && items.Length > 0 {
            MenuGroups[groupIndex] := {
                name: groupName[groupIndex],
                items: items
            }
            LogDebug("MenuSystem", "加载菜单组", { index: groupIndex, name: groupName[groupIndex], itemCount: items.Length })
        }
    }

    menuGroupNum := enabledCount
    LogInfo("MenuSystem", "菜单组初始化完成", { enabledGroups: enabledCount })
}

; ---------------------------------------------------------------------
; ExecuteActionFromConfig - 根据配置执行动作
; @param actionConfig 动作配置对象
; ---------------------------------------------------------------------
ExecuteActionFromConfig(actionConfig) {
    CloseMenu()

    if Type(actionConfig) = "String" {
        if actionConfig != "" {
            ExecuteCustomAction(actionConfig)
        }
        return
    }

    if !IsObject(actionConfig) {
        return
    }

    actionType := actionConfig.HasOwnProp("type") ? actionConfig.type : "None"
    params := actionConfig.HasOwnProp("params") ? actionConfig.params : {}

    try {
        switch actionType {
            case "None", "":
                return

            case "RunApp":
                path := params.HasOwnProp("path") ? params.path : ""
                workdir := params.HasOwnProp("workdir") ? params.workdir : ""
                if path != "" {
                    Run(path, workdir != "" ? workdir : A_Desktop)
                }

            case "SendKeys":
                keys := params.HasOwnProp("keys") ? params.keys : ""
                if keys != "" {
                    SendInput(keys)
                }

            case "SendText":
                text := params.HasOwnProp("text") ? params.text : ""
                if text != "" {
                    SendText(text)
                }

            case "ProcessKill":
                name := params.HasOwnProp("name") ? params.name : ""
                if name != "" {
                    ProcessClose(name)
                }

            case "Custom":
                if params.HasOwnProp("code") && params.code != "" {
                    ExecuteCustomAction(params.code)
                }
        }
    } catch Error as e {
        LogError("MenuSystem", "动作执行失败", { error: e.Message })
        ShowTooltipNearMouse("动作执行失败: " e.Message)
    }
}

; ---------------------------------------------------------------------
; ExecuteCustomAction - 执行自定义动作代码
; @param code 动作代码字符串
; ---------------------------------------------------------------------
ExecuteCustomAction(code) {
    if code != "" {
        RunCommand(code)
    }
}

; ---------------------------------------------------------------------
; CheckReloadSignal - 检查重载信号文件
; ---------------------------------------------------------------------
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

; ---------------------------------------------------------------------
; ReloadMenuGroups - 重新加载菜单组配置
; 使用 ConfigManager 重新加载配置
; ---------------------------------------------------------------------
ReloadMenuGroups() {
    global MenuGroups, menuGroupNum, enableGroup, groupName, groupCount

    configManager := GetConfigManager()
    menus := configManager.ReloadMenus()
    settings := configManager.GetSettings()

    if settings.HasOwnProp("ui") && settings.ui.HasOwnProp("darkMode") {
        ApplyMenuTheme.Call(settings.ui.darkMode)
    }

    MenuGroups := Map()
    enableGroup := []
    groupName := []
    groupCount := []

    loop 10 {
        enableGroup.Push(false)
        groupName.Push("组 " A_Index)
        groupCount.Push(0)
    }

    if !IsObject(menus) || !menus.HasOwnProp("groups") {
        ToolTip("菜单配置加载失败")
        SetTimer(() => ToolTip(), -2000)
        return
    }

    enabledCount := 0
    for groupData in menus.groups {
        groupIndex := groupData.HasOwnProp("id") ? groupData.id : A_Index
        groupEnabled := groupData.HasOwnProp("enabled") ? groupData.enabled : true

        if groupIndex < 1 || groupIndex > 10 {
            continue
        }

        enableGroup[groupIndex] := groupEnabled
        groupName[groupIndex] := groupData.HasOwnProp("name") ? groupData.name : ("组 " groupIndex)

        if groupEnabled {
            enabledCount++
        }

        items := []
        if groupData.HasOwnProp("items") {
            for itemData in groupData.items {
                itemName := itemData.HasOwnProp("name") ? itemData.name : ""
                if itemName = "" {
                    continue
                }

                itemAction := itemData.HasOwnProp("action") ? itemData.action : ""

                items.Push({
                    name: itemName,
                    actionConfig: itemAction
                })
            }
        }

        groupCount[groupIndex] := items.Length

        if groupEnabled && items.Length > 0 {
            MenuGroups[groupIndex] := {
                name: groupName[groupIndex],
                items: items
            }
        }
    }

    menuGroupNum := enabledCount

    loadedCount := 0
    for k, v in MenuGroups {
        if (v.HasOwnProp("items") && v.items.Length > 0)
            loadedCount++
    }
    ToolTip("已重新加载菜单配置, 共加载了 " loadedCount " 个组")
    SetTimer(() => ToolTip(), -2000)
}

; ---------------------------------------------------------------------
; IsMenuGroupEmpty - 检查菜单组是否为空
; @param groupIndex 菜单组索引
; @return 是否为空
; ---------------------------------------------------------------------
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

; ---------------------------------------------------------------------
; ShowMenu - 显示指定菜单组
; @param groupIndex 菜单组索引
; ---------------------------------------------------------------------
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

; ---------------------------------------------------------------------
; ExecuteMenuItem - 执行菜单项动作
; @param groupIndex 菜单组索引
; @param itemIndex 菜单项索引
; ---------------------------------------------------------------------
ExecuteMenuItem(groupIndex, itemIndex) {
    if (!MenuGroups.Has(groupIndex)) {
        return
    }

    menuGroup := MenuGroups[groupIndex]

    if (!menuGroup.HasOwnProp("items") || itemIndex < 1 || itemIndex > menuGroup.items.Length) {
        return
    }

    menuItem := menuGroup.items[itemIndex]

    if menuItem.HasOwnProp("actionConfig") {
        ExecuteActionFromConfig(menuItem.actionConfig)
    }
}

; =====================================================================
; 热键绑定 - CapsLock+数字键 显示菜单
; =====================================================================

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

; =====================================================================
; 热键绑定 - 菜单内数字键执行菜单项
; =====================================================================

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
