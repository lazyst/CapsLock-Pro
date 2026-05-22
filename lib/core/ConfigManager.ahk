; =====================================================================
; CapsLock++ 配置管理器
; 从 CapsLock++.ini 读取配置并转换为新格式
; =====================================================================

class ConfigManager {
    iniPath := A_ScriptDir "\CapsLock++.ini"

    LoadMenus() {
        iniPath := this.iniPath
        groups := []
        loop 10 {
            idx := A_Index
            nameKey := "name" idx
            enableKey := "enableGroup" idx
            countKey := "count" idx

            groupName := ReadIniValueUTF8(iniPath, "MenuGroupName", nameKey, "菜单组 " idx)
            groupEnabled := ReadIniValueUTF8(iniPath, "MenuGroupsEnable", enableKey, "true")
            itemCountText := ReadIniValueUTF8(iniPath, "MenuGroupCount", countKey, "0")

            itemCount := Integer(itemCountText)
            items := []
            loop itemCount {
                itemIdx := A_Index
                itemSection := "MenuGroups" idx "Items"
                itemName := ReadIniValueUTF8(iniPath, itemSection, "name" itemIdx, "")
                if itemName = ""
                    continue
                items.Push({
                    name: itemName,
                    icon: ReadIniValueUTF8(iniPath, itemSection, "icon" itemIdx, ""),
                    iconType: ReadIniValueUTF8(iniPath, itemSection, "icontype" itemIdx, "emoji"),
                    action: ReadIniValueUTF8(iniPath, itemSection, "action" itemIdx, "")
                })
            }

            groups.Push({
                id: idx,
                name: groupName,
                enabled: groupEnabled = "true" ? true : false,
                items: items
            })
        }
        return { version: "1.0", groups: groups }
    }

    ReloadMenus() {
        return this.LoadMenus()
    }

    GetSettings() {
        iniPath := this.iniPath
        darkMode := ReadIniValueUTF8(iniPath, "MenuGroupsColourMode", "DarkMode", "true")
        mouseSpeed := ReadIniValueUTF8(iniPath, "MouseMode", "Speed", "7")

        noteTargets := []
        i := 1
        loop {
            keyword := ReadIniValueUTF8(iniPath, "noteTargets", "note" i "1", "")
            if (keyword = "")
                break
            path := ReadIniValueUTF8(iniPath, "noteTargets", "note" i "2", "")
            if (keyword != "" && path != "")
                noteTargets.Push({ keyword: keyword, path: path })
            i++
        }

        return {
            ui: { darkMode: darkMode = "true" ? true : false },
            mouse: { speed: Integer(mouseSpeed) },
            noteTargets: noteTargets
        }
    }

    ReloadSettings() {
        return this.GetSettings()
    }

    SaveMenus(menus) {
        if !IsObject(menus) || !menus.HasOwnProp("groups")
            return false
        try {
            iniPath := this.iniPath
            for group in menus.groups {
                idx := group.HasOwnProp("id") ? group.id : A_Index
                if group.HasOwnProp("name")
                    WriteIniValueUTF8(iniPath, "MenuGroupName", "name" idx, group.name)
                if group.HasOwnProp("enabled")
                    WriteIniValueUTF8(iniPath, "MenuGroupsEnable", "enableGroup" idx, group.enabled ? "true" : "false")
                if group.HasOwnProp("items") {
                    itemCount := 0
                    for item in group.items {
                        itemCount++
                        section := "MenuGroups" idx "Items"
                        if item.HasOwnProp("name")
                            WriteIniValueUTF8(iniPath, section, "name" itemCount, item.name)
                        if item.HasOwnProp("icon")
                            WriteIniValueUTF8(iniPath, section, "icon" itemCount, item.icon)
                        if item.HasOwnProp("iconType")
                            WriteIniValueUTF8(iniPath, section, "icontype" itemCount, item.iconType)
                        actionStr := ""
                        if item.HasOwnProp("action") && !IsObject(item.action) {
                            actionStr := item.action
                        }
                        WriteIniValueUTF8(iniPath, section, "action" itemCount, actionStr)
                    }
                    WriteIniValueUTF8(iniPath, "MenuGroupCount", "count" idx, itemCount)
                }
            }
            return true
        } catch {
            return false
        }
    }

    SaveSettings(settings) {
        if !IsObject(settings)
            return false
        try {
            iniPath := this.iniPath
            if settings.HasOwnProp("ui") && settings.ui.HasOwnProp("darkMode")
                WriteIniValueUTF8(iniPath, "MenuGroupsColourMode", "DarkMode", settings.ui.darkMode ? "true" : "false")
            if settings.HasOwnProp("mouse") && settings.mouse.HasOwnProp("speed")
                WriteIniValueUTF8(iniPath, "MouseMode", "Speed", settings.mouse.speed)
            if settings.HasOwnProp("noteTargets") {
                ; Write in noteX1=keyword / noteX2=path format (compatible with QuickNote's LoadNoteTargetsFromINI)
                DeleteIniSectionUTF8(iniPath, "noteTargets")
                i := 1
                for item in settings.noteTargets {
                    keyword := item.HasOwnProp("keyword") ? item.keyword : ""
                    path := item.HasOwnProp("path") ? item.path : ""
                    if keyword != "" && path != "" {
                        WriteIniValueUTF8(iniPath, "noteTargets", "note" i "1", keyword)
                        WriteIniValueUTF8(iniPath, "noteTargets", "note" i "2", path)
                        i++
                    }
                }
            }
            return true
        } catch {
            return false
        }
    }

}

GetConfigManager() {
    static cm := ConfigManager()
    return cm
}

LoadNoteTargetsFromSettings() {
    try {
        cm := GetConfigManager()
        settings := cm.GetSettings()
        if settings.HasOwnProp("noteTargets") {
            global noteTargets := Map()
            for item in settings.noteTargets {
                keyword := item.HasOwnProp("keyword") ? item.keyword : ""
                path := item.HasOwnProp("path") ? item.path : ""
                if keyword != "" && path != ""
                    noteTargets[keyword] := path
            }
        }
    } catch {
    }
}
