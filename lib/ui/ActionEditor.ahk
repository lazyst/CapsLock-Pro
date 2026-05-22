; =====================================================================
; CapsLock++ 动作编辑器
; =====================================================================

ShowActionEditor(initialData, isNew := false, currentItem?) {
    if IsObject(initialData) && initialData != "" {
        result := _EditActionGUI(initialData)
        if result {
            return result
        }
        return false
    }

    if isNew && IsSet(currentItem) && IsObject(currentItem) {
        result := _NewItemActionGUI(currentItem)
        if result {
            return result
        }
        return false
    }

    result := _NewActionGUI()
    if result {
        return result
    }
    return false
}

_NewItemActionGUI(currentItem) {
    oldName := currentItem.HasOwnProp("name") ? currentItem.name : ""
    oldIcon := currentItem.HasOwnProp("icon") ? currentItem.icon : ""
    oldIconType := currentItem.HasOwnProp("iconType") ? currentItem.iconType : "emoji"
    oldAction := currentItem.HasOwnProp("action") ? currentItem.action : ""

    gui := Gui("+AlwaysOnTop +ToolWindow", "编辑菜单项")
    gui.SetFont("s10", "Segoe UI")

    gui.Add("Text", "x10 y15 w80 h23", "名称:")
    nameEdit := gui.Add("Edit", "x100 y12 w250 h23", oldName)

    gui.Add("Text", "x10 y45 w80 h23", "图标:")
    iconEdit := gui.Add("Edit", "x100 y42 w250 h23", oldIcon)

    gui.Add("Text", "x10 y75 w80 h23", "图标类型:")
    typeDDL := gui.Add("DropDownList", "x100 y72 w120", ["emoji", "file"])
    typeDDL.Choose(oldIconType = "file" ? 2 : 1)

    gui.Add("Text", "x10 y105 w80 h23", "动作:")
    actionEdit := gui.Add("Edit", "x100 y102 w250 h23", IsObject(oldAction) ? "" : oldAction)

    resultObj := {}

    gui.Add("Button", "x180 y140 w80 h30 Default", "确定").OnEvent("Click", (*) => (
        resultObj.__data := {
            name: nameEdit.Value,
            icon: iconEdit.Value,
            icontype: typeDDL.Text,
            action: actionEdit.Value
        },
        gui.Destroy()
    ))

    gui.Add("Button", "x270 y140 w80 h30", "取消").OnEvent("Click", (*) => (
        gui.Destroy()
    ))

    gui.Show("w380 h190")
    WinWaitClose(gui.Hwnd)

    if resultObj.HasOwnProp("__data") {
        return resultObj.__data
    }
    return false
}

_EditActionGUI(actionData) {
    oldType := actionData.HasOwnProp("type") ? actionData.type : "Custom"
    oldParams := actionData.HasOwnProp("params") ? actionData.params : {}

    gui := Gui("+AlwaysOnTop +ToolWindow", "编辑动作")
    gui.SetFont("s10", "Segoe UI")

    gui.Add("Text", "x10 y15 w80 h23", "动作类型:")
    typeDDL := gui.Add("DropDownList", "x100 y12 w150", ["RunApp", "SendKeys", "SendText", "ProcessKill", "Custom", "None"])
    typeIndex := 6
    for i, t in ["RunApp", "SendKeys", "SendText", "ProcessKill", "Custom", "None"] {
        if t = oldType {
            typeIndex := i
            break
        }
    }
    typeDDL.Choose(typeIndex)

    gui.Add("Text", "x10 y45 w80 h23", "参数(JSON):")
    paramsEdit := gui.Add("Edit", "x100 y42 w250 h100 Multi", "{}")

    resultObj := {}

    gui.Add("Button", "x180 y160 w80 h30 Default", "确定").OnEvent("Click", (*) => (
        resultObj.__data := {
            type: typeDDL.Text,
            params: {}
        },
        gui.Destroy()
    ))

    gui.Add("Button", "x270 y160 w80 h30", "取消").OnEvent("Click", (*) => (
        gui.Destroy()
    ))

    gui.Show("w380 h210")
    WinWaitClose(gui.Hwnd)

    if resultObj.HasOwnProp("__data") {
        return resultObj.__data
    }
    return false
}

_NewActionGUI() {
    gui := Gui("+AlwaysOnTop +ToolWindow", "新建动作")
    gui.SetFont("s10", "Segoe UI")

    gui.Add("Text", "x10 y15 w80 h23", "动作类型:")
    typeDDL := gui.Add("DropDownList", "x100 y12 w150", ["RunApp", "SendKeys", "SendText", "ProcessKill", "Custom"])
    typeDDL.Choose(1)

    resultObj := {}

    gui.Add("Button", "x180 y50 w80 h30 Default", "确定").OnEvent("Click", (*) => (
        resultObj.__data := {
            type: typeDDL.Text,
            params: {}
        },
        gui.Destroy()
    ))

    gui.Add("Button", "x270 y50 w80 h30", "取消").OnEvent("Click", (*) => (
        gui.Destroy()
    ))

    gui.Show("w380 h100")
    WinWaitClose(gui.Hwnd)

    if resultObj.HasOwnProp("__data") {
        return resultObj.__data
    }
    return false
}
