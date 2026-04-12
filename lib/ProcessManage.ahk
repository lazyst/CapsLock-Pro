; =====================================================================
; CapsLock++ 进程管理模块
; 包含：进程启用/终止、进程选择GUI、批量选择操作等功能
; =====================================================================

ManageProcess(action) {
    CloseMenu()

    switch action {
        case "启用":
            ShowTooltipNearMouse("正在启用指定进程...")
            i := 1
            Loop {
                processToStart := IniRead(A_ScriptDir "\CapsLock++.ini", "ProcessesToStart", "Item" i, "")
                if (processToStart = "")
                    break
                Run(processToStart)
                i++
            }
            ShowTooltipNearMouse("已尝试启用指定配置进程")

        case "终止":
            ShowTooltipNearMouse("正在终止指定进程...")
            i := 1
            terminatedCount := 0
            Loop {
                processToTerminate := IniRead(A_ScriptDir "\CapsLock++.ini", "ProcessesToTerminate", "Item" i, "")
                if (processToTerminate = "")
                    break
                try {
                    SplitPath(processToTerminate, &processName)
                    ProcessClose(processName)
                    terminatedCount++
                } catch Error as e {
                }
                i++
            }
            ShowTooltipNearMouse("已尝试终止指定进程 (" terminatedCount " 个成功)")
    }
}

ManageProcessWithCtrlCheck(action) {
    if (GetKeyState("Alt", "P")) {
        ShowProcessSelectionGUI(action)
    } else {
        ManageProcess(action)
    }
}

ShowProcessSelectionGUI(action) {
    CloseMenu()

    processList := []

    sectionName := action = "启用" ? "GUIProcessesToStart" : "GUIProcessesToTerminate"

    i := 1
    Loop {
        nameKey := "Item" i "_Name"
        pathKey := "Item" i "_Path"
        checkedKey := "Item" i "_Checked"

        procName := IniRead(A_ScriptDir "\CapsLock++.ini", sectionName, nameKey, "")
        if (procName = "")
            break

        procPath := IniRead(A_ScriptDir "\CapsLock++.ini", sectionName, pathKey, "")
        procChecked := IniRead(A_ScriptDir "\CapsLock++.ini", sectionName, checkedKey, "true") = "true"

        processList.Push({name: procName, path: procPath, checked: procChecked})

        i++
    }

    if (processList.Length = 0) {
        ShowTooltipNearMouse("错误: 无法从INI文件读取 " . sectionName . " 列表")
        return
    }

    processGui := Gui("+AlwaysOnTop +ToolWindow")
    processGui.Title := action = "启用" ? "选择要启用的进程" : "选择要终止的进程"

    listView := processGui.Add("ListView", "x10 y10 w400 h300 Checked", ["进程名称", "路径"])

    for _, proc in processList {
        row := listView.Add(proc.checked ? "Check" : "", proc.name, proc.path)
    }

    listView.ModifyCol(1, 150)
    listView.ModifyCol(2, "Auto")

    btnSelectAll := processGui.Add("Button", "x10 y320 w90 h30", "全选")
    btnSelectAll.OnEvent("Click", (*) => SelectAllItems(listView, true))

    btnSelectNone := processGui.Add("Button", "x110 y320 w90 h30", "全不选")
    btnSelectNone.OnEvent("Click", (*) => SelectAllItems(listView, false))

    btnInvert := processGui.Add("Button", "x210 y320 w90 h30", "反选")
    btnInvert.OnEvent("Click", (*) => InvertSelection(listView))

    btnOk := processGui.Add("Button", "x310 y320 w100 h30", action)
    btnOk.OnEvent("Click", (*) => ProcessSelection(action, listView, processList, processGui))

    btnBack := processGui.Add("Button", "x10 y360 w190 h30", "← 返回")
    btnBack.OnEvent("Click", BackToMainMenu)

    btnCancel := processGui.Add("Button", "x210 y360 w200 h30", "取消")
    btnCancel.OnEvent("Click", (*) => processGui.Destroy())

    listView.OnEvent("DoubleClick", (*) => ProcessSingleItem(action, listView, processList, processGui))

    processGui.OnEvent("Escape", (*) => processGui.Destroy())
    processGui.OnEvent("Close", (*) => processGui.Destroy())

    processGui.Show("w420 h400")
    listView.Focus()
}

ProcessSelection(action, listView, processList, gui) {
    selectedItems := []
    row := 0

    Loop {
        row := listView.GetNext(row, "Checked")
        if (!row)
            break
        selectedItems.Push(processList[row])
    }

    gui.Destroy()

    if (selectedItems.Length > 0) {
        if (action = "启用") {
            for _, item in selectedItems {
                try {
                    Run(item.path)
                    Sleep(200)
                } catch {
                }
            }
            ShowTooltipNearMouse("已启用 " . selectedItems.Length . " 个进程")
        } else {
            for _, item in selectedItems {
                try {
                    SplitPath(item.path, &processName)
                    ProcessClose(processName)
                } catch {
                }
            }
            ShowTooltipNearMouse("已终止 " . selectedItems.Length . " 个进程")
        }
    }
}

ProcessSingleItem(action, listView, processList, gui) {
    row := listView.GetNext(0, "Focused")
    if (row) {
        proc := processList[row]

        gui.Destroy()

        if (action = "启用") {
            try {
                Run(proc.path)
                ShowTooltipNearMouse("已启用: " . proc.name)
            } catch {
                ShowTooltipNearMouse("无法启用: " . proc.name)
            }
        } else {
            try {
                SplitPath(proc.path, &processName)
                ProcessClose(processName)
                ShowTooltipNearMouse("已终止: " . proc.name)
            } catch {
                ShowTooltipNearMouse("无法终止: " . proc.name)
            }
        }
    }
}

SelectAllItems(listView, check) {
    totalItems := listView.GetCount()

    Loop totalItems {
        if (check) {
            listView.Modify(A_Index, "Check")
        } else {
            listView.Modify(A_Index, "-Check")
        }
    }
}

InvertSelection(listView) {
    totalItems := listView.GetCount()

    Loop totalItems {
        isChecked := listView.GetNext(A_Index - 1, "Checked") = A_Index

        if (isChecked) {
            listView.Modify(A_Index, "-Check")
        } else {
            listView.Modify(A_Index, "Check")
        }
    }
}

BackToMainMenu(*) {
    processGui := WinGetID("A")
    if (processGui)
        WinClose("ahk_id " processGui)

    ShowMenu(1)
}
