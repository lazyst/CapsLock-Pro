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
        raw := ReadIniValueUTF8(iniPath, "noteTargets", "")
        if raw != "" {
            loop parse, raw, "`n", "`r" {
                if A_LoopField = ""
                    continue
                if RegExMatch(A_LoopField, '^==(.+)==(.+)$', &m) {
                    noteTargets.Push({ keyword: m[1], path: m[2] })
                }
            }
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
                    IniWrite(group.name, iniPath, "MenuGroupName", "name" idx)
                if group.HasOwnProp("enabled")
                    IniWrite(group.enabled ? "true" : "false", iniPath, "MenuGroupsEnable", "enableGroup" idx)
                if group.HasOwnProp("items") {
                    itemCount := 0
                    for item in group.items {
                        itemCount++
                        section := "MenuGroups" idx "Items"
                        if item.HasOwnProp("name")
                            IniWrite(item.name, iniPath, section, "name" itemCount)
                        if item.HasOwnProp("icon")
                            IniWrite(item.icon, iniPath, section, "icon" itemCount)
                        if item.HasOwnProp("iconType")
                            IniWrite(item.iconType, iniPath, section, "icontype" itemCount)
                        actionStr := ""
                        if item.HasOwnProp("action") && !IsObject(item.action) {
                            actionStr := item.action
                        }
                        IniWrite(actionStr, iniPath, section, "action" itemCount)
                    }
                    IniWrite(itemCount, iniPath, "MenuGroupCount", "count" idx)
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
                IniWrite(settings.ui.darkMode ? "true" : "false", iniPath, "MenuGroupsColourMode", "DarkMode")
            if settings.HasOwnProp("mouse") && settings.mouse.HasOwnProp("speed")
                IniWrite(settings.mouse.speed, iniPath, "MouseMode", "Speed")
            if settings.HasOwnProp("noteTargets") {
                noteText := ""
                for item in settings.noteTargets {
                    keyword := item.HasOwnProp("keyword") ? item.keyword : ""
                    path := item.HasOwnProp("path") ? item.path : ""
                    if keyword != "" && path != ""
                        noteText .= "==" keyword "==" path "`n"
                }
                IniWrite(Trim(noteText, "`n"), iniPath, "noteTargets")
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
