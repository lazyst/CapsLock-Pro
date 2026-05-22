; =====================================================================
; CapsLock++ 配置助手模块
; 包含：菜单配置、速记路径、动作管理的GUI编辑功能
; 通过 CapsLock+\ 快捷键启动
; 工具函数（ShowTooltip）在 lib/Utils.ahk 中声明
; =====================================================================

#Include "ui\ActionEditor.ahk"

EscapeQuotes(str) {
    return StrReplace(str, '"', '\"')
}

UnescapeQuotes(str) {
    return StrReplace(str, '\"', '"')
}

EnsureDataSync() {
    SyncMenuItemLVToArray()
}

global configHelperGui := ""

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

    tabs := configHelperGui.Add("Tab3", "x0 y0 w800 h560", ["菜单配置", "速记路径", "动作管理"])

    tabs.UseTab(1)
    BuildMenuPage(configHelperGui)
    tabs.UseTab(2)
    BuildNotePage(configHelperGui)
    tabs.UseTab(3)
    BuildActionPage(configHelperGui)
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
    if (row)
        noteLV.Delete(row)
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
    global darkModeCB := gui.Add("CheckBox", "x290 y35 w120 h20", "暗色模式")
    gui.Add("GroupBox", "x280 y55 w510 h435", "菜单项")
    global menuItemLV := gui.Add("ListView", "x290 y75 w490 h340 -Multi", ["名称", "图标", "图标类型", "动作"])
    menuItemLV.ModifyCol(1, 80)
    menuItemLV.ModifyCol(2, 80)
    menuItemLV.ModifyCol(3, 60)
    menuItemLV.ModifyCol(4, 240)
    menuItemLV.OnEvent("DoubleClick", MenuItemDoubleClick)
    gui.Add("Button", "x290 y425 w60 h24", "添加").OnEvent("Click", MenuAddItem)
    gui.Add("Button", "x360 y425 w60 h24", "编辑").OnEvent("Click", MenuEditItem)
    gui.Add("Button", "x430 y425 w60 h24", "删除").OnEvent("Click", MenuDelItem)
    gui.Add("Button", "x500 y425 w40 h24", "▲").OnEvent("Click", MenuMoveItemUp)
    gui.Add("Button", "x545 y425 w40 h24", "▼").OnEvent("Click", MenuMoveItemDown)
    gui.Add("Button", "x600 y425 w80 h24", "编辑动作").OnEvent("Click", MenuEditItemAction)
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
        actionDisplay := FormatActionDisplay(item.action)
        menuItemLV.Add("", item.name, item.icon, item.icontype, actionDisplay)
    }
}

FormatActionDisplay(action) {
    if IsString(action) {
        return action
    }
    if !IsObject(action) {
        return ""
    }
    if !action.HasOwnProp("type") {
        return ""
    }
    return GetActionSummary(action)
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

DetectActionType(action) {
    if (RegExMatch(action, "i)^RunCommand\("))
        return "自定义命令"
    if (RegExMatch(action, "i)^ActivateOrRun\("))
        return "启动程序"
    return "预设功能"
}

ExtractRunCommandParams(action) {
    if RegExMatch(action, 'i)^RunCommand\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)$', &m)
        return { command: UnescapeQuotes(m[1]), workdir: UnescapeQuotes(m[2]) }
    return ""
}

ExtractActivateOrRunParams(action) {
    if RegExMatch(action, 'i)^ActivateOrRun\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)$', &m)
        return { name: UnescapeQuotes(m[1]), path: UnescapeQuotes(m[2]) }
    return ""
}

MenuAddItem(*) {
    global currentMenuGroup, menuGroupItems
    row := menuGroupLV.GetNext()
    if (!row) {
        ShowTooltipNearMouse("请先选择一个菜单组")
        return
    }

    result := ShowActionEditor("", true)
    if !IsObject(result) || !result.HasOwnProp("name") || !result.HasOwnProp("action") {
        return
    }

    actionDisplay := GetActionSummary(result.action)
    menuItemLV.Add("", result.name, result.icon, result.icontype, actionDisplay)

    if (currentMenuGroup >= 1 && currentMenuGroup <= menuGroupItems.Length) {
        items := menuGroupItems[currentMenuGroup]
        items.Push({ name: result.name, icon: result.icon, icontype: result.icontype, action: result.action })
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

    result := ShowActionEditor("", true, currentItem)
    if !IsObject(result) || !result.HasOwnProp("name") || !result.HasOwnProp("action") {
        return
    }

    actionDisplay := GetActionSummary(result.action)
    menuItemLV.Modify(row, "", result.name, result.icon, result.icontype, actionDisplay)
    items[row] := { name: result.name, icon: result.icon, icontype: result.icontype, action: result.action }
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
    global menuGroupItems, menuGroupEnabled, currentMenuGroup, savedActions, savedActionsLV

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
                    itemIcon := item.HasOwnProp("icon") ? item.icon : ""
                    itemIconType := item.HasOwnProp("iconType") ? item.iconType : "emoji"
                    itemAction := item.HasOwnProp("action") ? item.action : { type: "None", params: {} }

                    if itemName != ""
                        items.Push({ name: itemName, icon: itemIcon, icontype: itemIconType, action: itemAction })
                }
            }
            menuGroupItems.Push(items)
        }
    }

    if (menuGroupLV.GetCount() > 0) {
        menuGroupLV.Modify(1, "+Select +Focus")
        MenuGroupFocus(menuGroupLV, 1)
    }

    darkMode := true
    if settings.HasOwnProp("ui") && settings.ui.HasOwnProp("darkMode") {
        darkMode := settings.ui.darkMode
    }
    darkModeCB.Value := darkMode

    savedActionsLV.Delete()
    savedActions := []
    actionsData := configManager.LoadActions()
    if IsObject(actionsData) {
        for actionInfo in actionsData {
            actionName := actionInfo.HasOwnProp("name") ? actionInfo.name : ""
            actionData := actionInfo.HasOwnProp("data") ? actionInfo.data : ""
            createTime := actionInfo.HasOwnProp("createTime") ? actionInfo.createTime : ""

            if actionName != "" && IsObject(actionData) && actionData.HasOwnProp("type") {
                savedActions.Push({ name: actionName, data: actionData, createTime: createTime })
                summary := GetActionSummary(actionData)
                typeName := actionData.type
                savedActionsLV.Add("", actionName, typeName, summary, createTime)
            }
        }
    }

    ShowTooltipNearMouse("配置已加载")
}

ConfigSave() {
    global savedActions

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

    if IsObject(savedActions) {
        actionsToSave := []
        for actionInfo in savedActions {
            actionsToSave.Push({
                name: actionInfo.name,
                data: actionInfo.data,
                createTime: actionInfo.createTime
            })
        }
        configManager.SaveActions(actionsToSave)
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
        icon := menuItemLV.GetText(i, 2)
        icontype := menuItemLV.GetText(i, 3)

        action := ""
        if (i <= oldItems.Length) {
            action := oldItems[i].action
        }

        items.Push({
            name: name,
            icon: icon,
            icontype: icontype,
            action: action
        })
    }
    menuGroupItems[currentMenuGroup] := items
}

BuildSettingsConfig() {
    settings := {
        version: "1.0",
        ui: {
            darkMode: darkModeCB.Value
        },
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
                actionObj := item.action
                if IsString(actionObj) {
                    actionObj := ConvertOldActionString(actionObj)
                }

                items.Push({
                    name: item.name,
                    icon: item.icon,
                    iconType: item.icontype,
                    action: actionObj
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

; =====================================================================
; 动作管理页面
; =====================================================================

global savedActionsLV := ""
global savedActions := []

BuildActionPage(gui) {
    global savedActionsLV, savedActions
    gui.Add("Text", "x10 y35 w780 h20", "已保存动作列表 - 可复用的动作配置")
    savedActionsLV := gui.Add("ListView", "x10 y60 w780 h420 -Multi", ["名称", "类型", "摘要", "创建时间"])
    savedActionsLV.ModifyCol(1, 150)
    savedActionsLV.ModifyCol(2, 100)
    savedActionsLV.ModifyCol(3, 350)
    savedActionsLV.ModifyCol(4, 150)
    savedActionsLV.OnEvent("DoubleClick", ActionListDoubleClick)
    gui.Add("Button", "x10 y490 w100 h28", "添加新动作").OnEvent("Click", ActionAddNew)
    gui.Add("Button", "x120 y490 w80 h28", "编辑动作").OnEvent("Click", ActionEdit)
    gui.Add("Button", "x210 y490 w80 h28", "删除动作").OnEvent("Click", ActionDelete)
    gui.Add("Button", "x300 y490 w80 h28", "测试动作").OnEvent("Click", ActionTest)

    savedActions := []
    configManager := GetConfigManager()
    actionsData := configManager.GetActions()
    if IsObject(actionsData) {
        for actionInfo in actionsData {
            actionName := actionInfo.HasOwnProp("name") ? actionInfo.name : ""
            actionData := actionInfo.HasOwnProp("data") ? actionInfo.data : ""
            createTime := actionInfo.HasOwnProp("createTime") ? actionInfo.createTime : ""

            if actionName != "" && IsObject(actionData) && actionData.HasOwnProp("type") {
                savedActions.Push({ name: actionName, data: actionData, createTime: createTime })
                summary := GetActionSummary(actionData)
                typeName := actionData.type
                savedActionsLV.Add("", actionName, typeName, summary, createTime)
            }
        }
    }
}

ActionAddNew(*) {
    nameResult := InputBox("输入动作名称", "添加新动作")
    if (nameResult.Result != "OK" || nameResult.Value = "")
        return

    actionName := nameResult.Value
    actionData := ShowActionEditor("")

    if (!IsObject(actionData) || !actionData.HasOwnProp("type"))
        return

    summary := GetActionSummary(actionData)
    typeName := actionData.type
    createTime := FormatTime(, "yyyy-MM-dd HH:mm:ss")

    savedActions.Push({
        name: actionName,
        data: actionData,
        createTime: createTime
    })

    savedActionsLV.Add("", actionName, typeName, summary, createTime)
}

ActionEdit(*) {
    global savedActions, savedActionsLV
    row := savedActionsLV.GetNext()
    if (!row) {
        ShowTooltipNearMouse("请先选择一个动作")
        return
    }

    if (row > savedActions.Length)
        return

    actionInfo := savedActions[row]
    actionData := ShowActionEditor(actionInfo.data)

    if (!IsObject(actionData) || !actionData.HasOwnProp("type"))
        return

    savedActions[row].data := actionData
    summary := GetActionSummary(actionData)
    typeName := actionData.type

    savedActionsLV.Modify(row, "", actionInfo.name, typeName, summary, savedActions[row].createTime)
}

ActionDelete(*) {
    global savedActions, savedActionsLV
    row := savedActionsLV.GetNext()
    if (!row) {
        ShowTooltipNearMouse("请先选择一个动作")
        return
    }

    savedActionsLV.Delete(row)
    if (row <= savedActions.Length)
        savedActions.RemoveAt(row)
}

ActionTest(*) {
    global savedActions, savedActionsLV
    row := savedActionsLV.GetNext()
    if (!row) {
        ShowTooltipNearMouse("请先选择一个动作")
        return
    }

    if (row > savedActions.Length)
        return

    actionInfo := savedActions[row]
    actionData := actionInfo.data

    try {
        context := CreateActionContext()
        result := ExecuteAction(actionData, context)
        if (result.success) {
            ShowTooltipNearMouse("测试成功: " . result.result)
        } else {
            ShowTooltipNearMouse("测试失败: " . result.error)
        }
    } catch Error as e {
        ShowTooltipNearMouse("测试出错: " . e.Message)
    }
}

ActionListDoubleClick(ctrl, itemNum) {
    global savedActions
    if (itemNum < 1 || itemNum > savedActions.Length)
        return

    actionInfo := savedActions[itemNum]
    actionData := ShowActionEditor(actionInfo.data)

    if (!IsObject(actionData) || !actionData.HasOwnProp("type"))
        return

    savedActions[itemNum].data := actionData
    summary := GetActionSummary(actionData)
    typeName := actionData.type

    savedActionsLV.Modify(itemNum, "", actionInfo.name, typeName, summary, actionInfo.createTime)
}

GetActionSummary(actionData) {
    if (!IsObject(actionData) || !actionData.HasOwnProp("type")) {
        return "无动作"
    }

    meta := ActionGetMeta(actionData.type)
    typeName := meta.HasOwnProp("name") ? meta.name : actionData.type

    if (!actionData.HasOwnProp("params")) {
        return typeName
    }

    summary := typeName
    params := actionData.params

    if (actionData.type = "RunApp" || actionData.type = "ProcessStart") {
        if (params.HasOwnProp("path")) {
            path := params.path
            SplitPath(path, &fileName)
            summary .= ": " . fileName
        }
    } else if (actionData.type = "SendKeys") {
        if (params.HasOwnProp("keys")) {
            keys := params.keys
            if (StrLen(keys) > 20)
                keys := SubStr(keys, 1, 20) . "..."
            summary .= ": " . keys
        }
    } else if (actionData.type = "SendText") {
        if (params.HasOwnProp("text")) {
            text := params.text
            if (StrLen(text) > 20)
                text := SubStr(text, 1, 20) . "..."
            summary .= ": " . text
        }
    } else if (actionData.type = "ProcessKill") {
        if (params.HasOwnProp("name")) {
            summary .= ": " . params.name
        } else if (params.HasOwnProp("pid")) {
            summary .= ": PID " . params.pid
        }
    }

    return summary
}

ConvertOldActionString(actionStr) {
    if (actionStr = "") {
        return ""
    }

    if RegExMatch(actionStr, 'i)^RunCommand\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)$', &m) {
        command := UnescapeQuotes(m[1])
        workdir := UnescapeQuotes(m[2])
        return {
            type: "RunApp",
            params: {
                path: command,
                workdir: workdir
            }
        }
    }

    if RegExMatch(actionStr, 'i)^ActivateOrRun\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)$', &m) {
        name := UnescapeQuotes(m[1])
        path := UnescapeQuotes(m[2])
        return {
            type: "RunApp",
            params: {
                name: name,
                path: path
            }
        }
    }


    if RegExMatch(actionStr, 'i)^SendInput\(\s*"((?:[^"\\]|\\.)*)"\s*\)$', &m) {
        keys := UnescapeQuotes(m[1])
        return {
            type: "SendKeys",
            params: {
                keys: keys
            }
        }
    }

    return {
        type: "Custom",
        params: {
            code: actionStr
        }
    }
}

ConvertToOldActionString(actionData) {
    if (!IsObject(actionData) || !actionData.HasOwnProp("type")) {
        return ""
    }

    type := actionData.type
    params := actionData.HasOwnProp("params") ? actionData.params : {}

    if (type = "RunApp") {
        path := params.HasOwnProp("path") ? params.path : ""
        workdir := params.HasOwnProp("workdir") ? params.workdir : ""
        name := params.HasOwnProp("name") ? params.name : ""

        if (name != "" && path != "") {
            return 'ActivateOrRun("' . EscapeQuotes(name) . '", "' . EscapeQuotes(path) . '")'
        } else if (path != "") {
            return 'RunCommand("' . EscapeQuotes(path) . '", "' . EscapeQuotes(workdir) . '")'
        }
    }

    return ""
}

; =====================================================================
; 菜单项动作编辑增强
; =====================================================================

MenuItemDoubleClick(ctrl, itemNum) {
    global menuGroupItems, currentMenuGroup
    if (!itemNum)
        return

    if (currentMenuGroup < 1 || currentMenuGroup > menuGroupItems.Length)
        return

    items := menuGroupItems[currentMenuGroup]
    if (itemNum > items.Length)
        return

    currentItem := items[itemNum]
    actionData := currentItem.action

    if IsString(actionData) {
        actionData := ConvertOldActionString(actionData)
    }

    newActionData := ShowActionEditor(actionData)

    if (!IsObject(newActionData) || !newActionData.HasOwnProp("type"))
        return

    items[itemNum].action := newActionData
    actionDisplay := GetActionSummary(newActionData)
    menuItemLV.Modify(itemNum, "Col4", actionDisplay)
}

MenuEditItemAction(*) {
    global menuGroupItems, currentMenuGroup
    row := menuItemLV.GetNext()
    if (!row) {
        ShowTooltipNearMouse("请先选择一个菜单项")
        return
    }

    if (currentMenuGroup < 1 || currentMenuGroup > menuGroupItems.Length)
        return

    items := menuGroupItems[currentMenuGroup]
    if (row > items.Length)
        return

    currentItem := items[row]
    actionData := currentItem.action

    if IsString(actionData) {
        actionData := ConvertOldActionString(actionData)
    }

    newActionData := ShowActionEditor(actionData)

    if (!IsObject(newActionData) || !newActionData.HasOwnProp("type"))
        return

    items[row].action := newActionData
    actionDisplay := GetActionSummary(newActionData)
    menuItemLV.Modify(row, "Col4", actionDisplay)
}
