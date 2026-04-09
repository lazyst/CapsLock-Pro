#Requires AutoHotkey v2.0
#SingleInstance Force

global iniFile := A_ScriptDir "\CapsLock++.ini"
global currentMenuGroup := 0

ReadIniValueUTF8(file, section, key, default := "") {
    try {
        val := IniRead(file, section, key, default)
        dq := Chr(34)
        if (SubStr(val, 1, 1) = dq) and (SubStr(val, -1) = dq)
            val := SubStr(val, 2, -1)
        val := StrReplace(val, '\"', dq)
        return val
    } catch Error {
        return default
    }
}

EscapeIniValue(val) {
    dq := Chr(34)
    val := StrReplace(val, dq, '\"')
    return dq val dq
}

ShowTooltip(text, duration := 1500) {
    ToolTip(text)
    SetTimer(() => ToolTip(), -duration)
}

ShowConfigHelper() {
    cfgGui := Gui("+Resize", "CapsLock++ 配置助手")
    cfgGui.SetFont("s10", "Segoe UI")
    cfgGui.OnEvent("Close", (*) => ExitApp())

    tabs := cfgGui.Add("Tab3", "x0 y0 w800 h560", ["黑名单窗口", "速记路径", "菜单配置", "进程管理", "网站配置", "自定义命令"])

    tabs.UseTab(1)
    BuildBlacklistPage(cfgGui)
    tabs.UseTab(2)
    BuildNotePage(cfgGui)
    tabs.UseTab(3)
    BuildMenuPage(cfgGui)
    tabs.UseTab(4)
    BuildProcessPage(cfgGui)
    tabs.UseTab(5)
    BuildWebsitePage(cfgGui)
    tabs.UseTab(6)
    BuildCustomCmdPage(cfgGui)
    tabs.UseTab(0)

    cfgGui.Add("Button", "x580 y570 w100 h32", "重新加载").OnEvent("Click", (*) => ConfigReload())
    cfgGui.Add("Button", "x690 y570 w100 h32", "保存配置").OnEvent("Click", (*) => ConfigSave())

    cfgGui.Show("w800 h610")
    ConfigReload()
}

BuildBlacklistPage(gui) {
    gui.Add("GroupBox", "x10 y30 w380 h460", "进程黑名单")
    global blProcLV := gui.Add("ListView", "x20 y55 w360 h400 -HDR -Multi", ["进程路径"])
    blProcLV.ModifyCol(1, 340)
    gui.Add("GroupBox", "x410 y30 w380 h460", "窗口类名黑名单")
    global blClassLV := gui.Add("ListView", "x420 y55 w360 h400 -HDR -Multi", ["窗口类名"])
    blClassLV.ModifyCol(1, 340)
    gui.Add("Button", "x10 y500 w80 h28", "添加进程").OnEvent("Click", BLAddProc)
    gui.Add("Button", "x100 y500 w80 h28", "编辑进程").OnEvent("Click", BLEditProc)
    gui.Add("Button", "x190 y500 w80 h28", "删除进程").OnEvent("Click", BLDelProc)
    gui.Add("Button", "x410 y500 w80 h28", "添加类名").OnEvent("Click", BLAddClass)
    gui.Add("Button", "x500 y500 w80 h28", "编辑类名").OnEvent("Click", BLEditClass)
    gui.Add("Button", "x590 y500 w80 h28", "删除类名").OnEvent("Click", BLDelClass)
    gui.Add("Button", "x700 y500 w90 h28", "捕获窗口").OnEvent("Click", BLCaptureWindow)
}

BLAddProc(*) {
    result := InputBox("输入进程名或路径", "添加进程黑名单")
    if (result.Result = "OK" && result.Value != "")
        blProcLV.Add("", result.Value)
}

BLEditProc(*) {
    row := blProcLV.GetNext()
    if (!row)
        return
    current := blProcLV.GetText(row, 1)
    result := InputBox("编辑进程黑名单", "编辑进程",, current)
    if (result.Result = "OK" && result.Value != "")
        blProcLV.Modify(row, "", result.Value)
}

BLDelProc(*) {
    row := blProcLV.GetNext()
    if (row)
        blProcLV.Delete(row)
}

BLAddClass(*) {
    result := InputBox("输入窗口类名", "添加类名黑名单")
    if (result.Result = "OK" && result.Value != "")
        blClassLV.Add("", result.Value)
}

BLEditClass(*) {
    row := blClassLV.GetNext()
    if (!row)
        return
    current := blClassLV.GetText(row, 1)
    result := InputBox("编辑类名黑名单", "编辑类名",, current)
    if (result.Result = "OK" && result.Value != "")
        blClassLV.Modify(row, "", result.Value)
}

BLDelClass(*) {
    row := blClassLV.GetNext()
    if (row)
        blClassLV.Delete(row)
}

BLCaptureWindow(*) {
    ShowTooltip("3秒后捕获鼠标下窗口信息...")
    Sleep(3000)
    MouseGetPos(, , &mouseWin)
    if (mouseWin) {
        className := WinGetClass("ahk_id " mouseWin)
        pid := WinGetPID("ahk_id " mouseWin)
        try {
            processPath := ProcessGetPath(pid)
            SplitPath(processPath, &processName)
        } catch Error {
            processName := ""
        }
        if (processName)
            blProcLV.Add("", processName)
        if (className)
            blClassLV.Add("", className)
        ShowTooltip("已捕获: " processName " / " className)
    } else {
        ShowTooltip("未捕获到窗口")
    }
}

BuildNotePage(gui) {
    gui.Add("Text", "x10 y35 w780 h20", "速记目标配置 - 关键词与文件路径的映射")
    global noteLV := gui.Add("ListView", "x10 y60 w780 h420 -Multi", ["关键词", "文件路径"])
    noteLV.ModifyCol(1, 150)
    noteLV.ModifyCol(2, 600)
    gui.Add("Button", "x10 y490 w80 h28", "添加").OnEvent("Click", NoteAdd)
    gui.Add("Button", "x100 y490 w80 h28", "编辑").OnEvent("Click", NoteEdit)
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

NoteEdit(*) {
    row := noteLV.GetNext()
    if (!row)
        return
    kw := noteLV.GetText(row, 1)
    path := noteLV.GetText(row, 2)
    kwResult := InputBox("编辑关键词", "编辑速记目标",, kw)
    if (kwResult.Result != "OK")
        return
    pathResult := InputBox("编辑文件路径", "编辑速记目标",, path)
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
    Loop cols {
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
    global menuItemLV := gui.Add("ListView", "x290 y75 w490 h340 -Multi", ["名称", "图标", "图标类型", "功能"])
    menuItemLV.ModifyCol(1, 80)
    menuItemLV.ModifyCol(2, 80)
    menuItemLV.ModifyCol(3, 60)
    menuItemLV.ModifyCol(4, 240)
    gui.Add("Button", "x290 y425 w60 h24", "添加").OnEvent("Click", MenuAddItem)
    gui.Add("Button", "x360 y425 w60 h24", "编辑").OnEvent("Click", MenuEditItem)
    gui.Add("Button", "x430 y425 w60 h24", "删除").OnEvent("Click", MenuDelItem)
    gui.Add("Button", "x500 y425 w40 h24", "▲").OnEvent("Click", MenuMoveItemUp)
    gui.Add("Button", "x545 y425 w40 h24", "▼").OnEvent("Click", MenuMoveItemDown)
    global menuGroupEnabled := []
    global menuGroupItems := []
    Loop 10 {
        menuGroupEnabled.Push(true)
        menuGroupItems.Push([])
    }
}

MenuGroupFocus(ctrl, itemNum) {
    global menuGroupItems, currentMenuGroup
    currentMenuGroup := itemNum
    menuItemLV.Delete()
    if (itemNum < 1 || itemNum > menuGroupItems.Length)
        return
    items := menuGroupItems[itemNum]
    for item in items {
        menuItemLV.Add("", item.name, item.icon, item.icontype, item.action)
    }
}

MenuEditGroup(*) {
    row := menuGroupLV.GetNext()
    if (!row)
        return
    current := menuGroupLV.GetText(row, 1)
    RegExMatch(current, "[✓✗] (.+)", &m)
    realName := m ? m[1] : current
    result := InputBox("输入新的菜单组名称", "编辑组名称",, realName)
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
    RegExMatch(name, "[✓✗] (.+)", &m)
    realName := m ? m[1] : name
    menuGroupLV.Modify(row, "", state realName)
}

MenuGroupMoveUp(*) {
    global menuGroupItems, menuGroupEnabled, currentMenuGroup
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

GetCustomCmdNames() {
    names := []
    Loop customCmdLV.GetCount() {
        names.Push(customCmdLV.GetText(A_Index, 1))
    }
    return names
}

DetectActionType(action) {
    if (RegExMatch(action, "i)^RunCustomCommand\("))
        return "自定义命令"
    if (RegExMatch(action, "i)^ActivateOrRun\("))
        return "启动程序"
    return "预设功能"
}

ExtractCustomCmdName(action) {
    if RegExMatch(action, 'i)^RunCustomCommand\(\s*"(.*?)"\s*\)$', &m)
        return m[1]
    return ""
}

ExtractActivateOrRunParams(action) {
    if RegExMatch(action, 'i)^ActivateOrRun\(\s*"(.*?)"\s*,\s*"(.*?)"\s*\)$', &m)
        return {name: m[1], path: m[2]}
    return ""
}

MenuAddItem(*) {
    global currentMenuGroup
    row := menuGroupLV.GetNext()
    if (!row) {
        ShowTooltip("请先选择一个菜单组")
        return
    }
    dlg := Gui("+Owner", "添加菜单项")
    dlg.SetFont("s10", "Segoe UI")

    dlg.Add("Text", "x10 y10", "名称:")
    ne := dlg.Add("Edit", "x100 y7 w260", "")
    dlg.Add("Text", "x10 y37", "图标:")
    ie := dlg.Add("Edit", "x100 y34 w260", "")
    dlg.Add("Text", "x10 y64", "图标类型:")
    itcb := dlg.Add("ComboBox", "x100 y61 w260", ["emoji", "file"])
    itcb.Choose(1)
    dlg.Add("Text", "x10 y91", "动作类型:")
    atcb := dlg.Add("ComboBox", "x100 y88 w260", ["预设功能", "自定义命令", "启动程序"])
    atcb.Choose(1)

    cmdLabel := dlg.Add("Text", "x10 y118", "选择命令:")
    cmdCb := dlg.Add("ComboBox", "x100 y115 w170", GetCustomCmdNames())
    newCmdBtn := dlg.Add("Button", "x275 y114 w80 h24", "新建命令")
    newCmdBtn.OnEvent("Click", CreateNewCustomCmd.Bind(cmdCb, ne))

    apNeLabel := dlg.Add("Text", "x10 y118", "程序名:")
    apNe := dlg.Add("Edit", "x100 y115 w110", "")
    apPeLabel := dlg.Add("Text", "x220 y118", "路径:")
    apPe := dlg.Add("Edit", "x255 y115 w105", "")

    tmplLabel := dlg.Add("Text", "x10 y118", "常用模板:")
    templates := [
        'ManageProcessWithCtrlCheck("启用")', 'ManageProcessWithCtrlCheck("终止")',
        'WebsiteLogin()', 'WebsiteLogin("www.bilibili.com")'
    ]
    elb := dlg.Add("ComboBox", "x100 y115 w260", templates)

    dlg.Add("Text", "x10 y148", "生成的动作:")
    ae := dlg.Add("Edit", "x100 y145 w260 +ReadOnly", "")

    atcb.OnEvent("Change", OnActionTypeChange.Bind(atcb, cmdCb, cmdLabel, newCmdBtn, apNe, apPe, apNeLabel, apPeLabel, elb, tmplLabel, ae, ne))
    cmdCb.OnEvent("Change", OnCustomCmdSelect.Bind(cmdCb, ae, ne))
    apNe.OnEvent("Change", OnActivateOrRunChange.Bind(apNe, apPe, ae))
    apPe.OnEvent("Change", OnActivateOrRunChange.Bind(apNe, apPe, ae))
    elb.OnEvent("Change", OnTemplateSelect.Bind(elb, ae))

    OnActionTypeChange(atcb, cmdCb, cmdLabel, newCmdBtn, apNe, apPe, apNeLabel, apPeLabel, elb, tmplLabel, ae, ne)
    dlg.Add("Button", "x120 y190 w80", "确定").OnEvent("Click", OnMenuAddSubmit.Bind(ne, ie, itcb, ae, dlg))
    dlg.Add("Button", "x210 y190 w80", "取消").OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.Show("w375 h225")
}

OnActionTypeChange(atcb, cmdCb, cmdLabel, newCmdBtn, apNe, apPe, apNeLabel, apPeLabel, elb, tmplLabel, ae, ne, *) {
    t := atcb.Text
    isCustom := (t = "自定义命令")
    isApp := (t = "启动程序")
    isPreset := (t = "预设功能")
    cmdCb.Visible := isCustom
    cmdLabel.Visible := isCustom
    newCmdBtn.Visible := isCustom
    apNe.Visible := isApp
    apPe.Visible := isApp
    apNeLabel.Visible := isApp
    apPeLabel.Visible := isApp
    elb.Visible := isPreset
    tmplLabel.Visible := isPreset
    if (isCustom) {
        ae.Value := 'RunCustomCommand("' cmdCb.Text '")'
        if (cmdCb.Text != "" && ne.Value = "")
            ne.Value := cmdCb.Text
    } else if (isApp) {
        dq := Chr(34)
        ae.Value := 'ActivateOrRun(' dq apNe.Value dq ', ' dq apPe.Value dq ')'
    } else {
        ae.Value := elb.Text
    }
}

OnCustomCmdSelect(cmdCb, ae, ne, *) {
    ae.Value := 'RunCustomCommand("' cmdCb.Text '")'
    if (cmdCb.Text != "" && ne.Value = "")
        ne.Value := cmdCb.Text
}

OnActivateOrRunChange(apNe, apPe, ae, *) {
    dq := Chr(34)
    ae.Value := 'ActivateOrRun(' dq apNe.Value dq ', ' dq apPe.Value dq ')'
}

OnTemplateSelect(elb, ae, *) {
    ae.Value := elb.Text
}

CreateNewCustomCmd(cmdCb, ne, *) {
    sub := Gui("+Owner", "新建自定义命令")
    sub.SetFont("s10", "Segoe UI")
    sub.Add("Text",, "命令名称:")
    sne := sub.Add("Edit", "w300")
    sub.Add("Text",, "系统命令:")
    sce := sub.Add("Edit", "w300")
    sub.Add("Text",, "工作目录 (可选):")
    swe := sub.Add("Edit", "w300")
    sub.Add("Button", "w80", "确定").OnEvent("Click", OnCreateNewCmdSubmit.Bind(sne, sce, swe, cmdCb, ne, sub))
    sub.Add("Button", "x+10 wp", "取消").OnEvent("Click", (*) => sub.Destroy())
    sub.OnEvent("Close", (*) => sub.Destroy())
    sub.Show()
}

OnCreateNewCmdSubmit(sne, sce, swe, cmdCb, ne, sub, *) {
    if (sne.Value = "" || sce.Value = "")
        return
    customCmdLV.Add("", sne.Value, sce.Value, swe.Value)
    cmdCb.Delete()
    names := GetCustomCmdNames()
    for n in names
        cmdCb.Add([n])
    cmdCb.Choose(names.Length)
    ne.Value := sne.Value
    sub.Destroy()
}

OnMenuAddSubmit(ne, ie, itcb, ae, dlg, *) {
    global menuGroupItems, currentMenuGroup
    if (ne.Value = "")
        return
    menuItemLV.Add("", ne.Value, ie.Value, itcb.Text, ae.Value)
    if (currentMenuGroup >= 1 && currentMenuGroup <= menuGroupItems.Length) {
        items := menuGroupItems[currentMenuGroup]
        items.Push({name: ne.Value, icon: ie.Value, icontype: itcb.Text, action: ae.Value})
    }
    dlg.Destroy()
}

MenuEditItem(*) {
    global menuGroupItems, currentMenuGroup
    row := menuItemLV.GetNext()
    if (!row)
        return
    name := menuItemLV.GetText(row, 1)
    icon := menuItemLV.GetText(row, 2)
    icontype := menuItemLV.GetText(row, 3)
    action := menuItemLV.GetText(row, 4)
    dlg := Gui("+Owner", "编辑菜单项")
    dlg.SetFont("s10", "Segoe UI")

    dlg.Add("Text", "x10 y10", "名称:")
    ne := dlg.Add("Edit", "x100 y7 w260", name)
    dlg.Add("Text", "x10 y37", "图标:")
    ie := dlg.Add("Edit", "x100 y34 w260", icon)
    dlg.Add("Text", "x10 y64", "图标类型:")
    itcb := dlg.Add("ComboBox", "x100 y61 w260", ["emoji", "file"])
    if (icontype = "file")
        itcb.Choose(2)
    else
        itcb.Choose(1)
    dlg.Add("Text", "x10 y91", "动作类型:")
    atcb := dlg.Add("ComboBox", "x100 y88 w260", ["预设功能", "自定义命令", "启动程序"])
    detectedType := DetectActionType(action)
    if (detectedType = "自定义命令")
        atcb.Choose(2)
    else if (detectedType = "启动程序")
        atcb.Choose(3)
    else
        atcb.Choose(1)

    cmdLabel := dlg.Add("Text", "x10 y118", "选择命令:")
    cmdNames := GetCustomCmdNames()
    cmdCb := dlg.Add("ComboBox", "x100 y115 w170", cmdNames)
    if (detectedType = "自定义命令") {
        cmdName := ExtractCustomCmdName(action)
        if (cmdName != "") {
            for idx, n in cmdNames {
                if (n = cmdName) {
                    cmdCb.Choose(idx)
                    break
                }
            }
        }
    }
    newCmdBtn := dlg.Add("Button", "x275 y114 w80 h24", "新建命令")
    newCmdBtn.OnEvent("Click", CreateNewCustomCmd.Bind(cmdCb, ne))

    apNeLabel := dlg.Add("Text", "x10 y118", "程序名:")
    apNe := dlg.Add("Edit", "x100 y115 w110", "")
    apPeLabel := dlg.Add("Text", "x220 y118", "路径:")
    apPe := dlg.Add("Edit", "x255 y115 w105", "")
    if (detectedType = "启动程序") {
        params := ExtractActivateOrRunParams(action)
        if (params != "") {
            apNe.Value := params.name
            apPe.Value := params.path
        }
    }

    tmplLabel := dlg.Add("Text", "x10 y118", "常用模板:")
    templates := [
        'ManageProcessWithCtrlCheck("启用")', 'ManageProcessWithCtrlCheck("终止")',
        'WebsiteLogin()', 'WebsiteLogin("www.bilibili.com")'
    ]
    elb := dlg.Add("ComboBox", "x100 y115 w260", templates)
    if (detectedType = "预设功能") {
        for idx, tmpl in templates {
            if (tmpl = action) {
                elb.Choose(idx)
                break
            }
        }
    }

    dlg.Add("Text", "x10 y148", "生成的动作:")
    ae := dlg.Add("Edit", "x100 y145 w260 +ReadOnly", action)

    atcb.OnEvent("Change", OnActionTypeChange.Bind(atcb, cmdCb, cmdLabel, newCmdBtn, apNe, apPe, apNeLabel, apPeLabel, elb, tmplLabel, ae, ne))
    cmdCb.OnEvent("Change", OnCustomCmdSelect.Bind(cmdCb, ae, ne))
    apNe.OnEvent("Change", OnActivateOrRunChange.Bind(apNe, apPe, ae))
    apPe.OnEvent("Change", OnActivateOrRunChange.Bind(apNe, apPe, ae))
    elb.OnEvent("Change", OnTemplateSelect.Bind(elb, ae))

    OnActionTypeChange(atcb, cmdCb, cmdLabel, newCmdBtn, apNe, apPe, apNeLabel, apPeLabel, elb, tmplLabel, ae, ne)
    dlg.Add("Button", "x120 y190 w80", "确定").OnEvent("Click", OnMenuEditSubmit.Bind(ne, ie, itcb, ae, row, dlg))
    dlg.Add("Button", "x210 y190 w80", "取消").OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.Show("w375 h225")
}

OnMenuEditSubmit(ne, ie, itcb, ae, row, dlg, *) {
    global menuGroupItems, currentMenuGroup
    menuItemLV.Modify(row, "", ne.Value, ie.Value, itcb.Text, ae.Value)
    if (currentMenuGroup >= 1 && currentMenuGroup <= menuGroupItems.Length) {
        items := menuGroupItems[currentMenuGroup]
        if (row >= 1 && row <= items.Length) {
            items[row] := {name: ne.Value, icon: ie.Value, icontype: itcb.Text, action: ae.Value}
        }
    }
    dlg.Destroy()
}

MenuDelItem(*) {
    global menuGroupItems, currentMenuGroup
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
    row := menuItemLV.GetNext()
    if (!row || row <= 1)
        return
    target := row - 1
    cols := menuItemLV.GetCount("Col")
    rowData := []
    targetRowData := []
    Loop cols {
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
    row := menuItemLV.GetNext()
    if (!row || row >= menuItemLV.GetCount())
        return
    target := row + 1
    cols := menuItemLV.GetCount("Col")
    rowData := []
    targetRowData := []
    Loop cols {
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

BuildProcessPage(gui) {
    gui.Add("GroupBox", "x10 y30 w380 h220", "直接启用进程")
    global startProcLV := gui.Add("ListView", "x20 y55 w360 h170 -HDR -Multi", ["进程路径"])
    startProcLV.ModifyCol(1, 340)
    gui.Add("Button", "x20 y230 w60 h24", "添加").OnEvent("Click", (*) => LVAddItem(startProcLV, "进程路径"))
    gui.Add("Button", "x90 y230 w60 h24", "删除").OnEvent("Click", (*) => LVDelItem(startProcLV))
    gui.Add("GroupBox", "x410 y30 w380 h220", "直接终止进程")
    global termProcLV := gui.Add("ListView", "x420 y55 w360 h170 -HDR -Multi", ["进程路径"])
    termProcLV.ModifyCol(1, 340)
    gui.Add("Button", "x420 y230 w60 h24", "添加").OnEvent("Click", (*) => LVAddItem(termProcLV, "进程路径"))
    gui.Add("Button", "x490 y230 w60 h24", "删除").OnEvent("Click", (*) => LVDelItem(termProcLV))
    gui.Add("GroupBox", "x10 y270 w380 h220", "Ctrl+点击启用进程")
    global guiStartProcLV := gui.Add("ListView", "x20 y295 w360 h170 -Multi", ["名称", "路径", "默认选中"])
    guiStartProcLV.ModifyCol(1, 80)
    guiStartProcLV.ModifyCol(2, 200)
    guiStartProcLV.ModifyCol(3, 60)
    gui.Add("Button", "x20 y470 w60 h24", "添加").OnEvent("Click", GUIStartAdd)
    gui.Add("Button", "x90 y470 w60 h24", "删除").OnEvent("Click", (*) => LVDelItem(guiStartProcLV))
    gui.Add("GroupBox", "x410 y270 w380 h220", "Ctrl+点击终止进程")
    global guiTermProcLV := gui.Add("ListView", "x420 y295 w360 h170 -Multi", ["名称", "路径", "默认选中"])
    guiTermProcLV.ModifyCol(1, 80)
    guiTermProcLV.ModifyCol(2, 200)
    guiTermProcLV.ModifyCol(3, 60)
    gui.Add("Button", "x420 y470 w60 h24", "添加").OnEvent("Click", GUITermAdd)
    gui.Add("Button", "x490 y470 w60 h24", "删除").OnEvent("Click", (*) => LVDelItem(guiTermProcLV))
}

GUIStartAdd(*) {
    dlg := Gui("+Owner", "添加Ctrl+启用进程")
    dlg.SetFont("s10", "Segoe UI")
    dlg.Add("Text",, "显示名称:")
    ne := dlg.Add("Edit", "w300")
    dlg.Add("Text",, "进程路径:")
    pe := dlg.Add("Edit", "w300")
    ccb := dlg.Add("CheckBox", "checked", "默认选中")
    dlg.Add("Button", "w80", "确定").OnEvent("Click", OnGUIStartSubmit.Bind(ne, pe, ccb, dlg))
    dlg.Add("Button", "x+10 wp", "取消").OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.Show()
}

OnGUIStartSubmit(ne, pe, ccb, dlg, *) {
    if (ne.Value != "" && pe.Value != "") {
        guiStartProcLV.Add("", ne.Value, pe.Value, ccb.Value ? "true" : "false")
        dlg.Destroy()
    }
}

GUITermAdd(*) {
    dlg := Gui("+Owner", "添加Ctrl+终止进程")
    dlg.SetFont("s10", "Segoe UI")
    dlg.Add("Text",, "显示名称:")
    ne := dlg.Add("Edit", "w300")
    dlg.Add("Text",, "进程路径:")
    pe := dlg.Add("Edit", "w300")
    ccb := dlg.Add("CheckBox", "checked", "默认选中")
    dlg.Add("Button", "w80", "确定").OnEvent("Click", OnGUITermSubmit.Bind(ne, pe, ccb, dlg))
    dlg.Add("Button", "x+10 wp", "取消").OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.Show()
}

OnGUITermSubmit(ne, pe, ccb, dlg, *) {
    if (ne.Value != "" && pe.Value != "") {
        guiTermProcLV.Add("", ne.Value, pe.Value, ccb.Value ? "true" : "false")
        dlg.Destroy()
    }
}

LVAddItem(lv, prompt) {
    result := InputBox(prompt, "添加")
    if (result.Result = "OK" && result.Value != "")
        lv.Add("", result.Value)
}

LVDelItem(lv) {
    row := lv.GetNext()
    if (row)
        lv.Delete(row)
}

BuildWebsitePage(gui) {
    gui.Add("Text", "x10 y35 w80 h20", "默认网站:")
    global defaultSiteEdit := gui.Add("Edit", "x90 y32 w690 h24")
    gui.Add("Text", "x10 y62 w80 h20", "浏览器偏好:")
    global browserCombo := gui.Add("ComboBox", "x90 y58 w120", ["default", "edge", "chrome", "firefox"])
    gui.Add("Text", "x10 y90 w780 h20", "网站列表:")
    global websiteLV := gui.Add("ListView", "x10 y110 w780 h370 -Multi", ["网站名称", "URL"])
    websiteLV.ModifyCol(1, 200)
    websiteLV.ModifyCol(2, 550)
    gui.Add("Button", "x10 y490 w80 h28", "添加网站").OnEvent("Click", WebsiteAdd)
    gui.Add("Button", "x100 y490 w80 h28", "删除网站").OnEvent("Click", (*) => LVDelItem(websiteLV))
    gui.Add("Button", "x190 y490 w60 h28", "上移").OnEvent("Click", (*) => LVMove(websiteLV, -1))
    gui.Add("Button", "x260 y490 w60 h28", "下移").OnEvent("Click", (*) => LVMove(websiteLV, 1))
}

WebsiteAdd(*) {
    nameResult := InputBox("网站名称", "添加网站")
    if (nameResult.Result != "OK" || nameResult.Value = "")
        return
    urlResult := InputBox("网站URL", "添加网站")
    if (urlResult.Result != "OK" || urlResult.Value = "")
        return
    websiteLV.Add("", nameResult.Value, urlResult.Value)
}

BuildCustomCmdPage(gui) {
    gui.Add("Text", "x10 y35 w780 h20", "自定义命令 - 通过菜单项的 RunCustomCommand 调用")
    global customCmdLV := gui.Add("ListView", "x10 y60 w780 h400 -Multi", ["命令名称", "系统命令", "工作目录(可选)"])
    customCmdLV.ModifyCol(1, 150)
    customCmdLV.ModifyCol(2, 380)
    customCmdLV.ModifyCol(3, 220)
    gui.Add("Button", "x10 y470 w80 h28", "添加").OnEvent("Click", CustomCmdAdd)
    gui.Add("Button", "x100 y470 w80 h28", "编辑").OnEvent("Click", CustomCmdEdit)
    gui.Add("Button", "x190 y470 w80 h28", "删除").OnEvent("Click", (*) => LVDelItem(customCmdLV))
    gui.Add("Button", "x280 y470 w60 h28", "上移").OnEvent("Click", (*) => LVMove(customCmdLV, -1))
    gui.Add("Button", "x350 y470 w60 h28", "下移").OnEvent("Click", (*) => LVMove(customCmdLV, 1))
}

CustomCmdAdd(*) {
    dlg := Gui("+Owner", "添加自定义命令")
    dlg.SetFont("s10", "Segoe UI")
    dlg.Add("Text",, "命令名称:")
    ne := dlg.Add("Edit", "w350")
    dlg.Add("Text",, "系统命令:")
    ce := dlg.Add("Edit", "w350")
    dlg.Add("Text",, "工作目录(可选):")
    we := dlg.Add("Edit", "w350")
    dlg.Add("Button", "w80", "确定").OnEvent("Click", OnCustomCmdAddSubmit.Bind(ne, ce, we, dlg))
    dlg.Add("Button", "x+10 wp", "取消").OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.Show()
}

OnCustomCmdAddSubmit(ne, ce, we, dlg, *) {
    if (ne.Value != "" && ce.Value != "") {
        customCmdLV.Add("", ne.Value, ce.Value, we.Value)
        dlg.Destroy()
    }
}

CustomCmdEdit(*) {
    row := customCmdLV.GetNext()
    if (!row)
        return
    name := customCmdLV.GetText(row, 1)
    cmd := customCmdLV.GetText(row, 2)
    workdir := customCmdLV.GetText(row, 3)
    dlg := Gui("+Owner", "编辑自定义命令")
    dlg.SetFont("s10", "Segoe UI")
    dlg.Add("Text",, "命令名称:")
    ne := dlg.Add("Edit", "w350", name)
    dlg.Add("Text",, "系统命令:")
    ce := dlg.Add("Edit", "w350", cmd)
    dlg.Add("Text",, "工作目录(可选):")
    we := dlg.Add("Edit", "w350", workdir)
    dlg.Add("Button", "w80", "确定").OnEvent("Click", OnCustomCmdEditSubmit.Bind(ne, ce, we, row, dlg))
    dlg.Add("Button", "x+10 wp", "取消").OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.Show()
}

OnCustomCmdEditSubmit(ne, ce, we, row, dlg, *) {
    customCmdLV.Modify(row, "", ne.Value, ce.Value, we.Value)
    dlg.Destroy()
}

ConfigReload() {
    global menuGroupItems, menuGroupEnabled, currentMenuGroup

    blProcLV.Delete()
    blClassLV.Delete()
    i := 1
    Loop {
        try {
            val := ReadIniValueUTF8(iniFile, "blacklist_virtual_env", "black" i, "")
            if (val = "")
                break
            blProcLV.Add("", val)
            i++
        } catch Error {
            break
        }
    }
    i := 1
    Loop {
        try {
            val := ReadIniValueUTF8(iniFile, "blacklist_classes_virtual_env", "blackclasses" i, "")
            if (val = "")
                break
            blClassLV.Add("", val)
            i++
        } catch Error {
            break
        }
    }

    noteLV.Delete()
    i := 1
    Loop {
        try {
            kw := ReadIniValueUTF8(iniFile, "noteTargets", "note" i "1", "")
            if (kw = "")
                break
            path := ReadIniValueUTF8(iniFile, "noteTargets", "note" i "2", "")
            noteLV.Add("", kw, path)
            i++
        } catch Error {
            break
        }
    }

    menuGroupLV.Delete()
    menuGroupItems := []
    menuGroupEnabled := []
    currentMenuGroup := 0
    Loop 10 {
        menuGroupItems.Push([])
        menuGroupEnabled.Push(true)
    }
    Loop 10 {
        i := A_Index
        name := ReadIniValueUTF8(iniFile, "MenuGroupName", "name" i, "菜单组 " i)
        enabled := ReadIniValueUTF8(iniFile, "MenuGroupsEnable", "enableGroup" i, "false") = "true"
        menuGroupEnabled[i] := enabled
        prefix := enabled ? "✓ " : "✗ "
        menuGroupLV.Add("", prefix name)
        count := Integer(ReadIniValueUTF8(iniFile, "MenuGroupCount", "count" i, "0"))
        items := []
        Loop count {
            j := A_Index
            sectionName := "MenuGroups" i "Items"
            itemName := ReadIniValueUTF8(iniFile, sectionName, "name" j, "")
            itemIcon := ReadIniValueUTF8(iniFile, sectionName, "icon" j, "")
            itemIconType := ReadIniValueUTF8(iniFile, sectionName, "icontype" j, "")
            itemAction := ReadIniValueUTF8(iniFile, sectionName, "action" j, "")
            if (itemName != "")
                items.Push({name: itemName, icon: itemIcon, icontype: itemIconType, action: itemAction})
        }
        menuGroupItems[i] := items
    }

    startProcLV.Delete()
    termProcLV.Delete()
    guiStartProcLV.Delete()
    guiTermProcLV.Delete()

    i := 1
    Loop {
        try {
            val := ReadIniValueUTF8(iniFile, "ProcessesToStart", "item" i, "")
            if (val = "")
                break
            startProcLV.Add("", val)
            i++
        } catch Error {
            break
        }
    }
    i := 1
    Loop {
        try {
            val := ReadIniValueUTF8(iniFile, "ProcessesToTerminate", "item" i, "")
            if (val = "")
                break
            termProcLV.Add("", val)
            i++
        } catch Error {
            break
        }
    }
    i := 1
    Loop {
        try {
            n := ReadIniValueUTF8(iniFile, "GUIProcessesToStart", "Item" i "_Name", "")
            if (n = "")
                break
            p := ReadIniValueUTF8(iniFile, "GUIProcessesToStart", "Item" i "_Path", "")
            c := ReadIniValueUTF8(iniFile, "GUIProcessesToStart", "Item" i "_Checked", "true")
            guiStartProcLV.Add("", n, p, c)
            i++
        } catch Error {
            break
        }
    }
    i := 1
    Loop {
        try {
            n := ReadIniValueUTF8(iniFile, "GUIProcessesToTerminate", "Item" i "_Name", "")
            if (n = "")
                break
            p := ReadIniValueUTF8(iniFile, "GUIProcessesToTerminate", "Item" i "_Path", "")
            c := ReadIniValueUTF8(iniFile, "GUIProcessesToTerminate", "Item" i "_Checked", "true")
            guiTermProcLV.Add("", n, p, c)
            i++
        } catch Error {
            break
        }
    }

    defaultSiteEdit.Value := ReadIniValueUTF8(iniFile, "CommonWebsites", "default_site", "")
    browser := ReadIniValueUTF8(iniFile, "CommonWebsites", "browser", "default")
    browserCombo.Text := browser

    websiteLV.Delete()
    i := 1
    Loop {
        try {
            site := ReadIniValueUTF8(iniFile, "CommonWebsites", "site" i, "")
            if (site = "")
                break
            url := ReadIniValueUTF8(iniFile, "CommonWebsites", "url" i, "")
            websiteLV.Add("", site, url)
            i++
        } catch Error {
            break
        }
    }

    customCmdLV.Delete()
    i := 1
    Loop {
        try {
            n := ReadIniValueUTF8(iniFile, "CustomCommands", "cmd" i "_name", "")
            if (n = "")
                break
            c := ReadIniValueUTF8(iniFile, "CustomCommands", "cmd" i "_command", "")
            w := ReadIniValueUTF8(iniFile, "CustomCommands", "cmd" i "_workdir", "")
            customCmdLV.Add("", n, c, w)
            i++
        } catch Error {
            break
        }
    }

    darkMode := ReadIniValueUTF8(iniFile, "MenuGroupsColourMode", "DarkMode", "true") = "true"
    darkModeCB.Value := darkMode

    ShowTooltip("配置已加载")
}

ConfigSave() {
    global menuGroupItems, menuGroupEnabled, darkModeCB

    managedSections := Map(
        "blacklist_virtual_env", true,
        "blacklist_classes_virtual_env", true,
        "noteTargets", true,
        "MenuGroupsColourMode", true,
        "MenuGroupsEnable", true,
        "MenuGroupNum", true,
        "MenuGroupCount", true,
        "MenuGroupName", true,
        "ProcessesToStart", true,
        "ProcessesToTerminate", true,
        "CommonWebsites", true,
        "GUIProcessesToStart", true,
        "GUIProcessesToTerminate", true,
        "CustomCommands", true
    )
    Loop 10 {
        managedSections["MenuGroups" A_Index "Items"] := true
    }

    preservedSections := ""
    try {
        allSections := IniRead(iniFile)
        Loop Parse, allSections, "`n" {
            secName := Trim(A_LoopField)
            if (!managedSections.Has(secName)) {
                preservedSections .= "[" secName "]`n"
                secKeys := IniRead(iniFile, secName)
                Loop Parse, secKeys, "`n" {
                    preservedSections .= A_LoopField "`n"
                }
                preservedSections .= "`n"
            }
        }
    } catch Error {
    }

    s := ""

    s .= "[blacklist_virtual_env]`n"
    Loop blProcLV.GetCount() {
        s .= "black" A_Index "=" EscapeIniValue(blProcLV.GetText(A_Index, 1)) "`n"
    }
    s .= "`n"

    s .= "[blacklist_classes_virtual_env]`n"
    Loop blClassLV.GetCount() {
        s .= "blackclasses" A_Index "=" EscapeIniValue(blClassLV.GetText(A_Index, 1)) "`n"
    }
    s .= "`n"

    s .= "[noteTargets]`n"
    Loop noteLV.GetCount() {
        s .= "note" A_Index "1=" EscapeIniValue(noteLV.GetText(A_Index, 1)) "`n"
        s .= "note" A_Index "2=" EscapeIniValue(noteLV.GetText(A_Index, 2)) "`n"
    }
    s .= "`n"

    s .= "[MenuGroupsColourMode]`n"
    s .= "DarkMode=" (darkModeCB.Value ? "true" : "false") "`n`n"

    s .= "[MenuGroupsEnable]`n"
    Loop 10 {
        s .= "enableGroup" A_Index "=" (menuGroupEnabled[A_Index] ? "true" : "false") "`n"
    }
    s .= "`n"

    enabledCount := 0
    Loop 10 {
        if (menuGroupEnabled[A_Index])
            enabledCount++
    }
    s .= "[MenuGroupNum]`n"
    s .= "num=" enabledCount "`n`n"

    s .= "[MenuGroupCount]`n"
    Loop 10 {
        i := A_Index
        cnt := (i <= menuGroupItems.Length) ? menuGroupItems[i].Length : 0
        s .= "count" i "=" cnt "`n"
    }
    s .= "`n"

    s .= "[MenuGroupName]`n"
    Loop 10 {
        i := A_Index
        name := menuGroupLV.GetText(i, 1)
        RegExMatch(name, "[✓✗] (.+)", &m)
        realName := m ? m[1] : name
        s .= "name" i "=" EscapeIniValue(realName) "`n"
    }
    s .= "`n"

    Loop 10 {
        i := A_Index
        s .= "[MenuGroups" i "Items]`n"
        if (i <= menuGroupItems.Length) {
            items := menuGroupItems[i]
            for j, item in items {
                s .= "name" j "=" EscapeIniValue(item.name) "`n"
                s .= "icon" j "=" EscapeIniValue(item.icon) "`n"
                s .= "icontype" j "=" EscapeIniValue(item.icontype) "`n"
                s .= "action" j "=" EscapeIniValue(item.action) "`n"
            }
        }
        s .= "`n"
    }

    s .= "[ProcessesToStart]`n"
    Loop startProcLV.GetCount() {
        s .= "item" A_Index "=" EscapeIniValue(startProcLV.GetText(A_Index, 1)) "`n"
    }
    s .= "`n"

    s .= "[ProcessesToTerminate]`n"
    Loop termProcLV.GetCount() {
        s .= "item" A_Index "=" EscapeIniValue(termProcLV.GetText(A_Index, 1)) "`n"
    }
    s .= "`n"

    s .= "[CommonWebsites]`n"
    s .= "default_site=" EscapeIniValue(defaultSiteEdit.Value) "`n"
    s .= "browser=" EscapeIniValue(browserCombo.Text) "`n"
    Loop websiteLV.GetCount() {
        s .= "site" A_Index "=" EscapeIniValue(websiteLV.GetText(A_Index, 1)) "`n"
        s .= "url" A_Index "=" EscapeIniValue(websiteLV.GetText(A_Index, 2)) "`n"
    }
    s .= "`n"

    s .= "[GUIProcessesToStart]`n"
    Loop guiStartProcLV.GetCount() {
        i := A_Index
        s .= "Item" i "_Name=" EscapeIniValue(guiStartProcLV.GetText(i, 1)) "`n"
        s .= "Item" i "_Path=" EscapeIniValue(guiStartProcLV.GetText(i, 2)) "`n"
        s .= "Item" i "_Checked=" EscapeIniValue(guiStartProcLV.GetText(i, 3)) "`n"
    }
    s .= "`n"

    s .= "[GUIProcessesToTerminate]`n"
    Loop guiTermProcLV.GetCount() {
        i := A_Index
        s .= "Item" i "_Name=" EscapeIniValue(guiTermProcLV.GetText(i, 1)) "`n"
        s .= "Item" i "_Path=" EscapeIniValue(guiTermProcLV.GetText(i, 2)) "`n"
        s .= "Item" i "_Checked=" EscapeIniValue(guiTermProcLV.GetText(i, 3)) "`n"
    }
    s .= "`n"

    s .= "[CustomCommands]`n"
    Loop customCmdLV.GetCount() {
        i := A_Index
        s .= "cmd" i "_name=" EscapeIniValue(customCmdLV.GetText(i, 1)) "`n"
        s .= "cmd" i "_command=" EscapeIniValue(customCmdLV.GetText(i, 2)) "`n"
        s .= "cmd" i "_workdir=" EscapeIniValue(customCmdLV.GetText(i, 3)) "`n"
    }
    s .= "`n"

    s .= preservedSections

    f := FileOpen(iniFile, "w", "UTF-8")
    f.Write(s)
    f.Close()

    FileDelete(A_ScriptDir "\.reload_signal")
    FileAppend("1", A_ScriptDir "\.reload_signal")

    ShowTooltip("配置已保存，主程序将自动重新加载")
}

ShowConfigHelper()
