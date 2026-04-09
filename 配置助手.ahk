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

    tabs := cfgGui.Add("Tab3", "x0 y0 w800 h560", ["菜单配置", "速记路径", "进程管理", "网站配置"])

    tabs.UseTab(1)
    BuildMenuPage(cfgGui)
    tabs.UseTab(2)
    BuildNotePage(cfgGui)
    tabs.UseTab(3)
    BuildProcessPage(cfgGui)
    tabs.UseTab(4)
    BuildWebsitePage(cfgGui)
    tabs.UseTab(0)

    cfgGui.Add("Button", "x580 y570 w100 h32", "重新加载").OnEvent("Click", (*) => ConfigReload())
    cfgGui.Add("Button", "x690 y570 w100 h32", "保存配置").OnEvent("Click", (*) => ConfigSave())

    cfgGui.Show("w800 h610")
    ConfigReload()
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

DetectActionType(action) {
    if (RegExMatch(action, "i)^RunCommand\("))
        return "自定义命令"
    if (RegExMatch(action, "i)^ActivateOrRun\("))
        return "启动程序"
    return "预设功能"
}

ExtractRunCommandParams(action) {
    if RegExMatch(action, 'i)^RunCommand\(\s*"(.*?)"\s*,\s*"(.*?)"\s*\)$', &m)
        return {command: m[1], workdir: m[2]}
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

    cmdLabel := dlg.Add("Text", "x10 y118", "命令:")
    cmdEdit := dlg.Add("Edit", "x100 y115 w260", "")
    workdirLabel := dlg.Add("Text", "x10 y148", "工作目录:")
    workdirEdit := dlg.Add("Edit", "x100 y145 w200", "")
    dlg.Add("Text", "x305 y148 w60 h20", "(可选)")

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

    dlg.Add("Text", "x10 y178", "生成的动作:")
    ae := dlg.Add("Edit", "x100 y175 w260 +ReadOnly", "")

    atcb.OnEvent("Change", OnActionTypeChange.Bind(atcb, cmdEdit, cmdLabel, workdirEdit, workdirLabel, apNe, apPe, apNeLabel, apPeLabel, elb, tmplLabel, ae))
    cmdEdit.OnEvent("Change", OnRunCommandChange.Bind(cmdEdit, workdirEdit, ae))
    workdirEdit.OnEvent("Change", OnRunCommandChange.Bind(cmdEdit, workdirEdit, ae))
    apNe.OnEvent("Change", OnActivateOrRunChange.Bind(apNe, apPe, ae))
    apPe.OnEvent("Change", OnActivateOrRunChange.Bind(apNe, apPe, ae))
    elb.OnEvent("Change", OnTemplateSelect.Bind(elb, ae))

    OnActionTypeChange(atcb, cmdEdit, cmdLabel, workdirEdit, workdirLabel, apNe, apPe, apNeLabel, apPeLabel, elb, tmplLabel, ae)
    dlg.Add("Button", "x120 y210 w80", "确定").OnEvent("Click", OnMenuAddSubmit.Bind(ne, ie, itcb, ae, dlg))
    dlg.Add("Button", "x210 y210 w80", "取消").OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.Show("w375 h250")
}

OnActionTypeChange(atcb, cmdEdit, cmdLabel, workdirEdit, workdirLabel, apNe, apPe, apNeLabel, apPeLabel, elb, tmplLabel, ae, *) {
    t := atcb.Text
    isCustom := (t = "自定义命令")
    isApp := (t = "启动程序")
    isPreset := (t = "预设功能")
    cmdEdit.Visible := isCustom
    cmdLabel.Visible := isCustom
    workdirEdit.Visible := isCustom
    workdirLabel.Visible := isCustom
    apNe.Visible := isApp
    apPe.Visible := isApp
    apNeLabel.Visible := isApp
    apPeLabel.Visible := isApp
    elb.Visible := isPreset
    tmplLabel.Visible := isPreset
    if (isCustom) {
        OnRunCommandChange(cmdEdit, workdirEdit, ae, "")
    } else if (isApp) {
        dq := Chr(34)
        ae.Value := 'ActivateOrRun(' dq apNe.Value dq ', ' dq apPe.Value dq ')'
    } else {
        ae.Value := elb.Text
    }
}

OnRunCommandChange(cmdEdit, workdirEdit, ae, *) {
    dq := Chr(34)
    ae.Value := 'RunCommand(' dq cmdEdit.Value dq ', ' dq workdirEdit.Value dq ')'
}

OnActivateOrRunChange(apNe, apPe, ae, *) {
    dq := Chr(34)
    ae.Value := 'ActivateOrRun(' dq apNe.Value dq ', ' dq apPe.Value dq ')'
}

OnTemplateSelect(elb, ae, *) {
    ae.Value := elb.Text
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

    cmdLabel := dlg.Add("Text", "x10 y118", "命令:")
    cmdEdit := dlg.Add("Edit", "x100 y115 w260", "")
    workdirLabel := dlg.Add("Text", "x10 y148", "工作目录:")
    workdirEdit := dlg.Add("Edit", "x100 y145 w200", "")
    dlg.Add("Text", "x305 y148 w60 h20", "(可选)")
    if (detectedType = "自定义命令") {
        params := ExtractRunCommandParams(action)
        if (params != "") {
            cmdEdit.Value := params.command
            workdirEdit.Value := params.workdir
        }
    }

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

    dlg.Add("Text", "x10 y178", "生成的动作:")
    ae := dlg.Add("Edit", "x100 y175 w260 +ReadOnly", action)

    atcb.OnEvent("Change", OnActionTypeChange.Bind(atcb, cmdEdit, cmdLabel, workdirEdit, workdirLabel, apNe, apPe, apNeLabel, apPeLabel, elb, tmplLabel, ae))
    cmdEdit.OnEvent("Change", OnRunCommandChange.Bind(cmdEdit, workdirEdit, ae))
    workdirEdit.OnEvent("Change", OnRunCommandChange.Bind(cmdEdit, workdirEdit, ae))
    apNe.OnEvent("Change", OnActivateOrRunChange.Bind(apNe, apPe, ae))
    apPe.OnEvent("Change", OnActivateOrRunChange.Bind(apNe, apPe, ae))
    elb.OnEvent("Change", OnTemplateSelect.Bind(elb, ae))

    OnActionTypeChange(atcb, cmdEdit, cmdLabel, workdirEdit, workdirLabel, apNe, apPe, apNeLabel, apPeLabel, elb, tmplLabel, ae)
    dlg.Add("Button", "x120 y210 w80", "确定").OnEvent("Click", OnMenuEditSubmit.Bind(ne, ie, itcb, ae, row, dlg))
    dlg.Add("Button", "x210 y210 w80", "取消").OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.Show("w375 h250")
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
    global startProcLV := gui.Add("ListView", "x20 y55 w360 h170 -Multi Checked", ["", "进程路径"])
    startProcLV.ModifyCol(1, 30)
    startProcLV.ModifyCol(2, 320)
    gui.Add("Button", "x20 y230 w60 h24", "添加").OnEvent("Click", (*) => StartProcAdd())
    gui.Add("Button", "x90 y230 w60 h24", "删除").OnEvent("Click", (*) => LVDeleteSelected(startProcLV))
    gui.Add("Button", "x160 y230 w50 h24", "全选").OnEvent("Click", (*) => LVSelectAll(startProcLV))
    gui.Add("GroupBox", "x410 y30 w380 h220", "直接终止进程")
    global termProcLV := gui.Add("ListView", "x420 y55 w360 h170 -Multi Checked", ["", "进程路径"])
    termProcLV.ModifyCol(1, 30)
    termProcLV.ModifyCol(2, 320)
    gui.Add("Button", "x420 y230 w60 h24", "添加").OnEvent("Click", (*) => TermProcAdd())
    gui.Add("Button", "x490 y230 w60 h24", "删除").OnEvent("Click", (*) => LVDeleteSelected(termProcLV))
    gui.Add("Button", "x560 y230 w50 h24", "全选").OnEvent("Click", (*) => LVSelectAll(termProcLV))
    gui.Add("GroupBox", "x10 y270 w380 h220", "Alt+点击启用进程")
    global guiStartProcLV := gui.Add("ListView", "x20 y295 w360 h170 -Multi Checked", ["", "名称", "路径", "默认选中"])
    guiStartProcLV.ModifyCol(1, 30)
    guiStartProcLV.ModifyCol(2, 70)
    guiStartProcLV.ModifyCol(3, 190)
    guiStartProcLV.ModifyCol(4, 60)
    gui.Add("Button", "x20 y470 w60 h24", "添加").OnEvent("Click", (*) => GUIStartAdd())
    gui.Add("Button", "x90 y470 w60 h24", "删除").OnEvent("Click", (*) => LVDeleteSelected(guiStartProcLV))
    gui.Add("Button", "x160 y470 w50 h24", "全选").OnEvent("Click", (*) => LVSelectAll(guiStartProcLV))
    gui.Add("GroupBox", "x410 y270 w380 h220", "Alt+点击终止进程")
    global guiTermProcLV := gui.Add("ListView", "x420 y295 w360 h170 -Multi Checked", ["", "名称", "路径", "默认选中"])
    guiTermProcLV.ModifyCol(1, 30)
    guiTermProcLV.ModifyCol(2, 70)
    guiTermProcLV.ModifyCol(3, 190)
    guiTermProcLV.ModifyCol(4, 60)
    gui.Add("Button", "x420 y470 w60 h24", "添加").OnEvent("Click", (*) => GUITermAdd())
    gui.Add("Button", "x490 y470 w60 h24", "删除").OnEvent("Click", (*) => LVDeleteSelected(guiTermProcLV))
    gui.Add("Button", "x560 y470 w50 h24", "全选").OnEvent("Click", (*) => LVSelectAll(guiTermProcLV))
}

OnGUITermSubmit(ne, pe, ccb, dlg, *) {
    if (ne.Value != "" && pe.Value != "") {
        guiTermProcLV.Add("", "", ne.Value, pe.Value, ccb.Value ? "true" : "false")
        dlg.Destroy()
    }
}

StartProcAdd() {
    dlg := Gui("+Owner", "添加启用进程")
    dlg.SetFont("s10", "Segoe UI")
    dlg.Add("Text", "x15 y15", "进程路径:")
    pe := dlg.Add("Edit", "x15 y40 w300 h24")
    dlg.Add("Button", "x325 y40 w60 h24", "浏览").OnEvent("Click", (*) => BrowseFileProc(pe))
    dlg.Add("Button", "x145 y75 w70 h28", "确定").OnEvent("Click", OnStartProcAddSubmit.Bind(pe, dlg))
    dlg.Add("Button", "x225 y75 w70 h28", "取消").OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.Show()
}

OnStartProcAddSubmit(pe, dlg, *) {
    if (pe.Value != "")
        startProcLV.Add("", "", pe.Value)
    dlg.Destroy()
}

BrowseFileProc(editCtrl) {
    selected := FileSelect(1, "", "选择进程文件", "可执行文件 (*.exe)")
    if (selected != "")
        editCtrl.Value := selected
}

TermProcAdd() {
    dlg := Gui("+Owner", "添加终止进程")
    dlg.SetFont("s10", "Segoe UI")
    dlg.Add("Text", "x15 y15", "进程路径:")
    pe := dlg.Add("Edit", "x15 y40 w300 h24")
    dlg.Add("Button", "x325 y40 w60 h24", "浏览").OnEvent("Click", (*) => BrowseFileProc(pe))
    dlg.Add("Button", "x145 y75 w70 h28", "确定").OnEvent("Click", OnTermProcAddSubmit.Bind(pe, dlg))
    dlg.Add("Button", "x225 y75 w70 h28", "取消").OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.Show()
}

OnTermProcAddSubmit(pe, dlg, *) {
    if (pe.Value != "")
        termProcLV.Add("", "", pe.Value)
    dlg.Destroy()
}

GUIStartAdd() {
    dlg := Gui("+Owner", "添加Ctrl+启用进程")
    dlg.SetFont("s10", "Segoe UI")
    dlg.Add("Text", "x15 y15", "显示名称:")
    ne := dlg.Add("Edit", "x15 y40 w300 h24")
    dlg.Add("Text", "x15 y75", "进程路径:")
    pe := dlg.Add("Edit", "x15 y100 w300 h24")
    dlg.Add("Button", "x325 y100 w60 h24", "浏览").OnEvent("Click", (*) => BrowseFileProc(pe))
    ccb := dlg.Add("CheckBox", "checked x15 y135", "默认选中")
    dlg.Add("Button", "x105 y170 w70 h28", "确定").OnEvent("Click", OnGUIStartSubmit.Bind(ne, pe, ccb, dlg))
    dlg.Add("Button", "x185 y170 w70 h28", "取消").OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.Show()
}

GUITermAdd() {
    dlg := Gui("+Owner", "添加Ctrl+终止进程")
    dlg.SetFont("s10", "Segoe UI")
    dlg.Add("Text", "x15 y15", "显示名称:")
    ne := dlg.Add("Edit", "x15 y40 w300 h24")
    dlg.Add("Text", "x15 y75", "进程路径:")
    pe := dlg.Add("Edit", "x15 y100 w300 h24")
    dlg.Add("Button", "x325 y100 w60 h24", "浏览").OnEvent("Click", (*) => BrowseFileProc(pe))
    ccb := dlg.Add("CheckBox", "checked x15 y135", "默认选中")
    dlg.Add("Button", "x105 y170 w70 h28", "确定").OnEvent("Click", OnGUITermSubmit.Bind(ne, pe, ccb, dlg))
    dlg.Add("Button", "x185 y170 w70 h28", "取消").OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.Show()
}

OnGUIStartSubmit(ne, pe, ccb, dlg, *) {
    if (ne.Value != "" && pe.Value != "") {
        guiStartProcLV.Add("", "", ne.Value, pe.Value, ccb.Value ? "true" : "false")
        dlg.Destroy()
    }
}

LVSelectAll(lv) {
    Loop lv.GetCount() {
        lv.Modify(A_Index, "Check")
    }
}

LVDeleteSelected(lv) {
    while (row := lv.GetNext(0, "Check")) {
        lv.Delete(row)
    }
}

LVDeleteOne(lv) {
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
    gui.Add("Button", "x100 y490 w80 h28", "删除网站").OnEvent("Click", (*) => LVDeleteOne(websiteLV))
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

ConfigReload() {
    global menuGroupItems, menuGroupEnabled, currentMenuGroup

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
    
    if (menuGroupLV.GetCount() > 0) {
        menuGroupLV.Modify(1, "+Select +Focus")
        MenuGroupFocus(menuGroupLV, 1)
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
            startProcLV.Add("", "", val)
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
            termProcLV.Add("", "", val)
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
            guiStartProcLV.Add("", "", n, p, c)
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
            guiTermProcLV.Add("", "", n, p, c)
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

    darkMode := ReadIniValueUTF8(iniFile, "MenuGroupsColourMode", "DarkMode", "true") = "true"
    darkModeCB.Value := darkMode

    ShowTooltip("配置已加载")
}

ConfigSave() {
    global menuGroupItems, menuGroupEnabled, darkModeCB

    managedSections := Map(
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
        "GUIProcessesToTerminate", true
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
        s .= "item" A_Index "=" EscapeIniValue(startProcLV.GetText(A_Index, 2)) "`n"
    }
    s .= "`n"

    s .= "[ProcessesToTerminate]`n"
    Loop termProcLV.GetCount() {
        s .= "item" A_Index "=" EscapeIniValue(termProcLV.GetText(A_Index, 2)) "`n"
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
        s .= "Item" i "_Name=" EscapeIniValue(guiStartProcLV.GetText(i, 2)) "`n"
        s .= "Item" i "_Path=" EscapeIniValue(guiStartProcLV.GetText(i, 3)) "`n"
        s .= "Item" i "_Checked=" EscapeIniValue(guiStartProcLV.GetText(i, 4)) "`n"
    }
    s .= "`n"

    s .= "[GUIProcessesToTerminate]`n"
    Loop guiTermProcLV.GetCount() {
        i := A_Index
        s .= "Item" i "_Name=" EscapeIniValue(guiTermProcLV.GetText(i, 2)) "`n"
        s .= "Item" i "_Path=" EscapeIniValue(guiTermProcLV.GetText(i, 3)) "`n"
        s .= "Item" i "_Checked=" EscapeIniValue(guiTermProcLV.GetText(i, 4)) "`n"
    }
    s .= "`n"

    s .= preservedSections

    f := FileOpen(iniFile, "w", "UTF-8")
    f.Write(s)
    f.Close()

    try {
        FileDelete(A_ScriptDir "\.reload_signal")
    } catch {
    }
    FileAppend("1", A_ScriptDir "\.reload_signal")

    ShowTooltip("配置已保存，主程序将自动重新加载")
}

ShowConfigHelper()
