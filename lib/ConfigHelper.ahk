; =====================================================================
; CapsLock++ 配置助手模块
; 包含：菜单配置、速记路径的GUI编辑功能
; 通过 CapsLock+\ 快捷键启动
; 工具函数（ShowTooltip）在 lib/Utils.ahk 中声明
; =====================================================================

global lastTerminalIndex := 2
global lastKeepWindow := false

EnsureDataSync() {
    SyncMenuItemLVToArray()
}

ShowConfigHelper() {
    global configHelperGui

    if (configHelperGui != "" && WinExist("ahk_id " configHelperGui.Hwnd)) {
        configHelperGui.Destroy()
        configHelperGui := ""
        return
    }

    configHelperGui := Gui("+Resize", "CapsLock++ 配置助手")
    configHelperGui.SetFont("s10", "Segoe UI")
    configHelperGui.OnEvent("Close", (*) => (configHelperGui := ""))

    tabs := configHelperGui.Add("Tab3", "x0 y0 w800 h560", ["菜单配置", "速记路径"])

    tabs.UseTab(1)
    BuildMenuPage(configHelperGui)
    tabs.UseTab(2)
    BuildNotePage(configHelperGui)
    tabs.UseTab(0)

    configHelperGui.Add("Button", "x580 y570 w100 h32", "重新加载").OnEvent("Click", (*) => ConfigReloadWithConfirm())
    configHelperGui.Add("Button", "x690 y570 w100 h32", "保存配置").OnEvent("Click", (*) => ConfigSave())

    configHelperGui.Show("w800 h610")
    ConfigReload()
}

BuildNotePage(gui) {
    gui.Add("Text", "x10 y35 w780 h20", "速记目标配置 - 关键词与文件路径的映射")
    global noteLV := gui.Add("ListView", "x10 y60 w780 h420 -Multi", ["关键词", "文件路径"])
    noteLV.ModifyCol(1, 150)
    noteLV.ModifyCol(2, 600)
    gui.Add("Button", "x10 y490 w80 h28", "添加").OnEvent("Click", NoteAdd)
    gui.Add("Button", "x100 y490 w80 h28", "编辑").OnEvent("Click", ConfigNoteEdit)
    gui.Add("Button", "x190 y490 w80 h28", "删除").OnEvent("Click", NoteDel)
    gui.Add("Button", "x280 y490 w60 h28", "上移").OnEvent("Click", (*) => LVMove(noteLV, -1))
    gui.Add("Button", "x350 y490 w60 h28", "下移").OnEvent("Click", (*) => LVMove(noteLV, 1))
}

NoteAdd(*) {
    kwResult := InputBox("输入关键词", "添加速记目标")
    if (kwResult.Result != "OK" || kwResult.Value = "")
        return
    pathResult := InputBox("输入文件路径", "添加速记目标")
    if (pathResult.Result != "OK" || pathResult.Value = "")
        return
    noteLV.Add("", kwResult.Value, pathResult.Value)
}

ConfigNoteEdit(*) {
    row := noteLV.GetNext()
    if (!row)
        return
    kw := noteLV.GetText(row, 1)
    path := noteLV.GetText(row, 2)
    kwResult := InputBox("编辑关键词", "编辑速记目标", , kw)
    if (kwResult.Result != "OK")
        return
    pathResult := InputBox("编辑文件路径", "编辑速记目标", , path)
    if (pathResult.Result != "OK")
        return
    noteLV.Modify(row, "", kwResult.Value, pathResult.Value)
}

NoteDel(*) {
    row := noteLV.GetNext()
    if (row) {
        noteLV.Delete(row)
        }
}

LVMove(lv, direction) {
    row := lv.GetNext()
    if (!row)
        return
    target := row + direction
    if (target < 1 || target > lv.GetCount())
        return
    cols := lv.GetCount("Col")
    rowData := []
    targetRowData := []
    loop cols {
        rowData.Push(lv.GetText(row, A_Index))
        targetRowData.Push(lv.GetText(target, A_Index))
    }
    lv.Modify(row, "", targetRowData*)
    lv.Modify(target, "", rowData*)
    lv.Modify(target, "+Select +Focus Vis")
}

BuildMenuPage(gui) {
    gui.Add("GroupBox", "x10 y30 w250 h460", "菜单组")
    global menuGroupLV := gui.Add("ListView", "x20 y55 w230 h380 -Multi -HDR", ["组名"])
    menuGroupLV.ModifyCol(1, 200)
    menuGroupLV.OnEvent("ItemFocus", MenuGroupFocus)
    gui.Add("Button", "x20 y440 w70 h24", "编辑名称").OnEvent("Click", MenuEditGroup)
    gui.Add("Button", "x100 y440 w70 h24", "启用/禁用").OnEvent("Click", MenuToggleGroup)
    gui.Add("Button", "x175 y440 w35 h24", "▲").OnEvent("Click", MenuGroupMoveUp)
    gui.Add("Button", "x215 y440 w35 h24", "▼").OnEvent("Click", MenuGroupMoveDown)
    gui.Add("GroupBox", "x280 y55 w510 h435", "菜单项")
    global menuItemLV := gui.Add("ListView", "x290 y75 w490 h340 -Multi", ["名称", "命令"])
    menuItemLV.ModifyCol(1, 120)
    menuItemLV.ModifyCol(2, 350)
    menuItemLV.OnEvent("DoubleClick", MenuEditItem)
    gui.Add("Button", "x290 y425 w60 h24", "添加").OnEvent("Click", MenuAddItem)
    gui.Add("Button", "x360 y425 w60 h24", "删除").OnEvent("Click", MenuDelItem)
    gui.Add("Button", "x430 y425 w40 h24", "▲").OnEvent("Click", MenuMoveItemUp)
    gui.Add("Button", "x475 y425 w40 h24", "▼").OnEvent("Click", MenuMoveItemDown)
    global menuGroupEnabled := []
    global menuGroupItems := []
    global currentMenuGroup := 0
    loop 10 {
        menuGroupEnabled.Push(true)
        menuGroupItems.Push([])
    }
}

MenuGroupFocus(ctrl, itemNum) {
    global menuGroupItems, currentMenuGroup

    if (currentMenuGroup >= 1 && currentMenuGroup <= menuGroupItems.Length && currentMenuGroup != itemNum) {
        SyncMenuItemLVToArray()
    }

    currentMenuGroup := itemNum
    menuItemLV.Delete()
    if (itemNum < 1 || itemNum > menuGroupItems.Length)
        return
    items := menuGroupItems[itemNum]
    for item in items {
        actionStr := IsObject(item.action) ? "" : item.action
        parsed := ParseCommandString(actionStr)
        menuItemLV.Add("", item.name, parsed.cmd)
    }
}

ExtractMenuGroupName(displayText) {
    if (SubStr(displayText, 1, 2) = "✓ " || SubStr(displayText, 1, 2) = "✗ ")
        return SubStr(displayText, 3)
    return displayText
}

MenuEditGroup(*) {
    row := menuGroupLV.GetNext()
    if (!row)
        return
    current := menuGroupLV.GetText(row, 1)
    realName := ExtractMenuGroupName(current)
    result := InputBox("输入新的菜单组名称", "编辑组名称", , realName)
    if (result.Result = "OK" && result.Value != "") {
        state := menuGroupEnabled[row] ? "✓ " : "✗ "
        menuGroupLV.Modify(row, "", state result.Value)
        }
}

MenuToggleGroup(*) {
    global menuGroupEnabled
    row := menuGroupLV.GetNext()
    if (!row)
        return
    menuGroupEnabled[row] := !menuGroupEnabled[row]
    state := menuGroupEnabled[row] ? "✓ " : "✗ "
    name := menuGroupLV.GetText(row, 1)
    realName := ExtractMenuGroupName(name)
    menuGroupLV.Modify(row, "", state realName)
}

MenuGroupMoveUp(*) {
    global menuGroupItems, menuGroupEnabled, currentMenuGroup

    SyncMenuItemLVToArray()

    row := menuGroupLV.GetNext()
    if (!row || row <= 1)
        return
    target := row - 1
    rowData := menuGroupLV.GetText(row, 1)
    targetRowData := menuGroupLV.GetText(target, 1)
    menuGroupLV.Modify(row, "", targetRowData)
    menuGroupLV.Modify(target, "", rowData)
    menuGroupLV.Modify(target, "+Select +Focus Vis")
    tmp := menuGroupItems[target]
    menuGroupItems[target] := menuGroupItems[row]
    menuGroupItems[row] := tmp
    tmpE := menuGroupEnabled[target]
    menuGroupEnabled[target] := menuGroupEnabled[row]
    menuGroupEnabled[row] := tmpE
    currentMenuGroup := target
    MenuGroupFocus(menuGroupLV, target)
}

MenuGroupMoveDown(*) {
    global menuGroupItems, menuGroupEnabled, currentMenuGroup

    SyncMenuItemLVToArray()

    row := menuGroupLV.GetNext()
    if (!row || row >= menuGroupLV.GetCount())
        return
    target := row + 1
    rowData := menuGroupLV.GetText(row, 1)
    targetRowData := menuGroupLV.GetText(target, 1)
    menuGroupLV.Modify(row, "", targetRowData)
    menuGroupLV.Modify(target, "", rowData)
    menuGroupLV.Modify(target, "+Select +Focus Vis")
    tmp := menuGroupItems[target]
    menuGroupItems[target] := menuGroupItems[row]
    menuGroupItems[row] := tmp
    tmpE := menuGroupEnabled[target]
    menuGroupEnabled[target] := menuGroupEnabled[row]
    menuGroupEnabled[row] := tmpE
    currentMenuGroup := target
    MenuGroupFocus(menuGroupLV, target)
}

TerminalToKey(displayName) {
    switch displayName {
        case "PowerShell 7": return "pwsh7"
        case "PowerShell 5": return "pwsh5"
        case "CMD": return "cmd"
        case "Git Bash": return "gitbash"
        case "WSL Bash": return "wslbash"
        default: return "direct"
    }
}

TerminalToIndex(key) {
    switch key {
        case "pwsh7": return 2
        case "pwsh5": return 3
        case "cmd": return 4
        case "gitbash": return 5
        case "wslbash": return 6
        default: return 1
    }
}

MenuAddItem(*) {
    global currentMenuGroup, menuGroupItems, lastTerminalIndex, lastKeepWindow
    row := menuGroupLV.GetNext()
    if (!row) {
        ShowTooltipNearMouse("请先选择一个菜单组")
        return
    }

    editGui := Gui("+AlwaysOnTop +ToolWindow", "添加菜单项")
    editGui.SetFont("s10", "Segoe UI")
    editGui.Add("Text", "x10 y15 w80 h23", "名称:")
    nameEdit := editGui.Add("Edit", "x100 y12 w250 h23", "")
    editGui.Add("Text", "x10 y48 w80 h23", "命令:")
    cmdEdit := editGui.Add("Edit", "x100 y45 w250 h23", "")
    editGui.Add("Text", "x10 y80 w80 h23", "终端:")
    terminalDDL := editGui.Add("DropDownList", "x100 y77 w150", ["直接运行", "PowerShell 7", "PowerShell 5", "CMD", "Git Bash", "WSL Bash"])
    terminalDDL.Choose(lastTerminalIndex)
    keepWindowCB := editGui.Add("CheckBox", "x260 y80 w100 h20", "保持窗口")
    keepWindowCB.Value := lastKeepWindow
    editGui.Add("Text", "x10 y112 w80 h23", "完整命令:")
    previewEdit := editGui.Add("Edit", "x100 y109 w250 h23 +ReadOnly",
        BuildCommandString(cmdEdit.Value, TerminalToKey(terminalDDL.Text), keepWindowCB.Value))

    UpdatePreview(*) {
        previewEdit.Value := BuildCommandString(
            cmdEdit.Value,
            TerminalToKey(terminalDDL.Text),
            keepWindowCB.Value
        )
    }
    cmdEdit.OnEvent("Change", UpdatePreview)
    terminalDDL.OnEvent("Change", UpdatePreview)
    keepWindowCB.OnEvent("Click", UpdatePreview)

    resultObj := {}
    editGui.Add("Button", "x180 y148 w80 h30 Default", "确定").OnEvent("Click", (*) => (
        resultObj.__data := {
            name: nameEdit.Value,
            cmd: cmdEdit.Value,
            terminal: terminalDDL.Text,
            terminalIndex: terminalDDL.Value,
            keepWindow: keepWindowCB.Value
        },
        editGui.Destroy()
    ))
    editGui.Add("Button", "x270 y148 w80 h30", "取消").OnEvent("Click", (*) => (editGui.Destroy()))
    editGui.Show("w380 h198")
    WinWaitClose(editGui.Hwnd)

    if !resultObj.HasOwnProp("__data") || resultObj.__data.name = ""
        return

    d := resultObj.__data
    lastTerminalIndex := d.terminalIndex
    lastKeepWindow := d.keepWindow
    fullCmd := BuildCommandString(d.cmd, TerminalToKey(d.terminal), d.keepWindow)
    menuItemLV.Add("", d.name, d.cmd)

    if (currentMenuGroup >= 1 && currentMenuGroup <= menuGroupItems.Length) {
        items := menuGroupItems[currentMenuGroup]
        items.Push({ name: d.name, action: fullCmd })
    }
}

MenuEditItem(*) {
    global menuGroupItems, currentMenuGroup
    row := menuItemLV.GetNext()
    if (!row)
        return

    if (currentMenuGroup < 1 || currentMenuGroup > menuGroupItems.Length)
        return

    items := menuGroupItems[currentMenuGroup]
    if (row > items.Length)
        return

    currentItem := items[row]
    oldName := currentItem.name
    oldAction := IsObject(currentItem.action) ? "" : currentItem.action
    parsed := ParseCommandString(oldAction)

    editGui := Gui("+AlwaysOnTop +ToolWindow", "编辑菜单项")
    editGui.SetFont("s10", "Segoe UI")
    editGui.Add("Text", "x10 y15 w80 h23", "名称:")
    nameEdit := editGui.Add("Edit", "x100 y12 w250 h23", oldName)
    editGui.Add("Text", "x10 y48 w80 h23", "命令:")
    cmdEdit := editGui.Add("Edit", "x100 y45 w250 h23", parsed.cmd)
    editGui.Add("Text", "x10 y80 w80 h23", "终端:")
    terminalDDL := editGui.Add("DropDownList", "x100 y77 w150", ["直接运行", "PowerShell 7", "PowerShell 5", "CMD", "Git Bash", "WSL Bash"])
    terminalDDL.Choose(TerminalToIndex(parsed.terminal))
    keepWindowCB := editGui.Add("CheckBox", "x260 y80 w100 h20", "保持窗口")
    keepWindowCB.Value := parsed.keepWindow
    editGui.Add("Text", "x10 y112 w80 h23", "完整命令:")
    previewEdit := editGui.Add("Edit", "x100 y109 w250 h23 +ReadOnly",
        BuildCommandString(parsed.cmd, parsed.terminal, parsed.keepWindow))

    UpdatePreview(*) {
        previewEdit.Value := BuildCommandString(
            cmdEdit.Value,
            TerminalToKey(terminalDDL.Text),
            keepWindowCB.Value
        )
    }
    cmdEdit.OnEvent("Change", UpdatePreview)
    terminalDDL.OnEvent("Change", UpdatePreview)
    keepWindowCB.OnEvent("Click", UpdatePreview)

    resultObj := {}
    editGui.Add("Button", "x180 y148 w80 h30 Default", "确定").OnEvent("Click", (*) => (
        resultObj.__data := {
            name: nameEdit.Value,
            cmd: cmdEdit.Value,
            terminal: terminalDDL.Text,
            keepWindow: keepWindowCB.Value
        },
        editGui.Destroy()
    ))
    editGui.Add("Button", "x270 y148 w80 h30", "取消").OnEvent("Click", (*) => (editGui.Destroy()))
    cmdEdit.Focus()
    editGui.Show("w380 h198")
    WinWaitClose(editGui.Hwnd)

    if !resultObj.HasOwnProp("__data") || resultObj.__data.name = ""
        return

    d := resultObj.__data
    fullCmd := BuildCommandString(d.cmd, TerminalToKey(d.terminal), d.keepWindow)
    menuItemLV.Modify(row, "", d.name, d.cmd)
    items[row] := { name: d.name, action: fullCmd }
}

MenuDelItem(*) {
    global menuGroupItems, currentMenuGroup
    EnsureDataSync()
    row := menuItemLV.GetNext()
    if (!row)
        return
    menuItemLV.Delete(row)
    if (currentMenuGroup >= 1 && currentMenuGroup <= menuGroupItems.Length) {
        items := menuGroupItems[currentMenuGroup]
        if (row >= 1 && row <= items.Length)
            items.RemoveAt(row)
    }
}

MenuMoveItemUp(*) {
    global menuGroupItems, currentMenuGroup
    EnsureDataSync()
    row := menuItemLV.GetNext()
    if (!row || row <= 1)
        return
    target := row - 1
    cols := menuItemLV.GetCount("Col")
    rowData := []
    targetRowData := []
    loop cols {
        rowData.Push(menuItemLV.GetText(row, A_Index))
        targetRowData.Push(menuItemLV.GetText(target, A_Index))
    }
    menuItemLV.Modify(row, "", targetRowData*)
    menuItemLV.Modify(target, "", rowData*)
    menuItemLV.Modify(target, "+Select +Focus Vis")
    if (currentMenuGroup >= 1 && currentMenuGroup <= menuGroupItems.Length) {
        items := menuGroupItems[currentMenuGroup]
        if (row >= 1 && row <= items.Length && target >= 1 && target <= items.Length) {
            tmp := items[target]
            items[target] := items[row]
            items[row] := tmp
        }
    }
}

MenuMoveItemDown(*) {
    global menuGroupItems, currentMenuGroup
    EnsureDataSync()
    row := menuItemLV.GetNext()
    if (!row || row >= menuItemLV.GetCount())
        return
    target := row + 1
    cols := menuItemLV.GetCount("Col")
    rowData := []
    targetRowData := []
    loop cols {
        rowData.Push(menuItemLV.GetText(row, A_Index))
        targetRowData.Push(menuItemLV.GetText(target, A_Index))
    }
    menuItemLV.Modify(row, "", targetRowData*)
    menuItemLV.Modify(target, "", rowData*)
    menuItemLV.Modify(target, "+Select +Focus Vis")
    if (currentMenuGroup >= 1 && currentMenuGroup <= menuGroupItems.Length) {
        items := menuGroupItems[currentMenuGroup]
        if (row >= 1 && row <= items.Length && target >= 1 && target <= items.Length) {
            tmp := items[target]
            items[target] := items[row]
            items[row] := tmp
        }
    }
}

ConfigReloadWithConfirm() {
    result := MsgBox("重新加载将丢弃所有未保存的更改，是否继续？", "确认重新加载", 0x124)
    if (result = "Yes")
        ConfigReload()
}

ConfigReload() {
    global menuGroupItems, menuGroupEnabled, currentMenuGroup, lastTerminalIndex, lastKeepWindow

    SyncMenuItemLVToArray()

    configManager := GetConfigManager()
    settings := configManager.ReloadSettings()
    menus := configManager.ReloadMenus()

    noteLV.Delete()
    if settings.HasOwnProp("noteTargets") {
        for item in settings.noteTargets {
            keyword := item.HasOwnProp("keyword") ? item.keyword : ""
            path := item.HasOwnProp("path") ? item.path : ""
            if (keyword != "" || path != "") {
                noteLV.Add("", keyword, path)
            }
        }
    }

    menuGroupLV.Delete()
    menuGroupItems := []
    menuGroupEnabled := []
    currentMenuGroup := 0

    if menus.HasOwnProp("groups") {
        for group in menus.groups {
            groupEnabled := group.HasOwnProp("enabled") ? group.enabled : true
            groupName := group.HasOwnProp("name") ? group.name : "菜单组"
            groupId := group.HasOwnProp("id") ? group.id : A_Index

            menuGroupEnabled.Push(groupEnabled)
            prefix := groupEnabled ? "✓ " : "✗ "
            menuGroupLV.Add("", prefix groupName)

            items := []
            if group.HasOwnProp("items") {
                for item in group.items {
                    itemName := item.HasOwnProp("name") ? item.name : ""
                    itemAction := item.HasOwnProp("action") ? item.action : ""

                    if itemName != ""
                        items.Push({ name: itemName, action: itemAction })
                }
            }
            menuGroupItems.Push(items)
        }
    }

    if (menuGroupLV.GetCount() > 0) {
        menuGroupLV.Modify(1, "+Select +Focus")
        MenuGroupFocus(menuGroupLV, 1)
    }

    if settings.HasOwnProp("lastTerminalIndex")
        lastTerminalIndex := settings.lastTerminalIndex
    if settings.HasOwnProp("lastKeepWindow")
        lastKeepWindow := settings.lastKeepWindow

    ShowTooltipNearMouse("配置已加载")
}

ConfigSave() {
    SyncMenuItemLVToArray()

    menus := BuildMenusConfig()
    settings := BuildSettingsConfig()

    configManager := GetConfigManager()

    if !configManager.SaveMenus(menus) {
        ShowTooltipNearMouse("保存菜单配置失败")
        return
    }

    if !configManager.SaveSettings(settings) {
        ShowTooltipNearMouse("保存设置配置失败")
        return
    }

    ReloadMenuGroups()
    LoadNoteTargetsFromSettings()

    ShowTooltipNearMouse("配置已保存并重新加载")
}

SyncMenuItemLVToArray() {
    global menuGroupItems, currentMenuGroup, menuItemLV

    if (currentMenuGroup < 1 || currentMenuGroup > menuGroupItems.Length)
        return

    oldItems := menuGroupItems[currentMenuGroup]
    items := []
    loop menuItemLV.GetCount() {
        i := A_Index
        name := menuItemLV.GetText(i, 1)

        action := ""
        if (i <= oldItems.Length) {
            action := oldItems[i].action
        }

        items.Push({
            name: name,
            action: action
        })
    }
    menuGroupItems[currentMenuGroup] := items
}

BuildSettingsConfig() {
    global lastTerminalIndex, lastKeepWindow
    settings := {
        version: "1.0",
        mouse: {
            speed: 5
        },
        noteTargets: []
    }

    loop noteLV.GetCount() {
        keyword := noteLV.GetText(A_Index, 1)
        path := noteLV.GetText(A_Index, 2)
        settings.noteTargets.Push({ keyword: keyword, path: path })
    }

    configManager := GetConfigManager()
    currentSettings := configManager.GetSettings()
    if currentSettings.HasOwnProp("mouse") && currentSettings.mouse.HasOwnProp("speed") {
        settings.mouse.speed := currentSettings.mouse.speed
    }

    settings.lastTerminalIndex := lastTerminalIndex
    settings.lastKeepWindow := lastKeepWindow

    return settings
}

BuildMenusConfig() {
    global menuGroupItems, menuGroupEnabled

    menus := {
        version: "1.0",
        groups: []
    }

    loop menuGroupLV.GetCount() {
        i := A_Index
        displayName := menuGroupLV.GetText(i, 1)
        groupName := ExtractMenuGroupName(displayName)
        groupEnabled := menuGroupEnabled[i]

        items := []
        if (i <= menuGroupItems.Length) {
            groupItems := menuGroupItems[i]
            for item in groupItems {
                items.Push({
                    name: item.name,
                    action: IsObject(item.action) ? "" : item.action
                })
            }
        }

        menus.groups.Push({
            id: i,
            name: groupName,
            enabled: groupEnabled,
            items: items
        })
    }

    return menus
}

