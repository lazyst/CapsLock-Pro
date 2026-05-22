; =====================================================================
; CapsLock++ 公共工具函数
; =====================================================================

; 显示在鼠标旁边的提示
ShowTooltipNearMouse(text, duration := 2000) {
    ToolTip()
    CoordMode("Mouse", "Screen")
    CoordMode("ToolTip", "Screen")
    MouseGetPos(&mouseX, &mouseY)
    ToolTip(text, mouseX + 20, mouseY + 20)
    SetTimer(ToolTipClear, -duration)
}

; 清除ToolTip的回调函数
ToolTipClear() {
    ToolTip()
}

; 格式化数字，保留2位小数
FormatNumber(num) {
    return Round(num, 2)
}

; 切换调试提示的显示状态
ToggleDebugTooltips() {
    global showDebugTooltips
    showDebugTooltips := !showDebugTooltips
    ToolTip("调试信息显示: " (showDebugTooltips ? "开启" : "关闭"))
    SetTimer () => ToolTip(), -2000
}

; 显示调试信息提示
ShowDebugTooltip(text, duration := 3000) {
    global showDebugTooltips
    
    if !showDebugTooltips
        return
        
    ToolTip(text)
    SetTimer () => ToolTip(), -duration
}

; 检查值是否在数组中
HasVal(arr, val) {
    for v in arr {
        if v = val
            return true
    }
    return false
}

; 字符串哈希算法，用于区分同一程序的不同窗口
StrHash(str) {
    hash := 0
    if (StrLen(str) == 0)
        return hash
        
    for i, char in StrSplit(str) {
        hash := ((hash << 5) - hash) + Ord(char)
        hash := hash & hash
    }
    
    return hash
}

; 添加CapsLock+兼容性处理，用于调试可能的按键冲突问题
ShowKeyPressDebug(keyName, source := "AHK") {
    global showDebugTooltips
    
    if !showDebugTooltips
        return
        
    ToolTip("按键检测：" keyName " (来源: " source ")")
    SetTimer () => ToolTip(), -1000
}

; 定义常用程序的优先级映射
GetProcessPriority(processName) {
    return 900 + Mod(StrHash(processName), 100)
}

; 判断窗口是否为任务栏窗口
IsTaskbarWindow(hwnd) {
    global showDebugTooltips, blacklistClasses, blacklistProcessNames
    
    if !WinExist("ahk_id " hwnd) || !DllCall("IsWindowVisible", "Ptr", hwnd)
        return false
    
    title := WinGetTitle("ahk_id " hwnd)
    
    if title = ""
        return false
    
    className := WinGetClass("ahk_id " hwnd)
    
    pid := WinGetPID("ahk_id " hwnd)
    processPath := ProcessGetPath(pid)
    SplitPath(processPath, &processName)
    
    if IsSet(blacklistProcessNames) && HasVal(blacklistProcessNames, processName) {
        if (showDebugTooltips) {
            ToolTip("排除黑名单进程: " processName)
            SetTimer () => ToolTip(), -1000
        }
        return false
    }
        
    for blackClass in (IsSet(blacklistClasses) ? blacklistClasses : []) {
        if (InStr(className, blackClass) || className = blackClass) {
            if (showDebugTooltips) {
                ToolTip("排除黑名单类名: " className)
                SetTimer () => ToolTip(), -1000
            }
            return false
        }
    }
    
    exStyle := WinGetExStyle("ahk_id " hwnd)
    if (exStyle & 0x80)  ; WS_EX_TOOLWINDOW
        return false
    
    if (exStyle & 0x40000) && !(exStyle & 0x100)  ; WS_EX_APPWINDOW without WS_EX_CONTROLPARENT
        return true
    
    if (className = "Shell_TrayWnd" || className = "Shell_SecondaryTrayWnd")
        return false
    
    if (className = "Progman" || className = "WorkerW")
        return false
    
    if (WinGetMinMax("ahk_id " hwnd) = -1)
        return false
    
    return true
}

; 读取INI文件的值，并使用UTF-8编码
ReadIniValueUTF8(filePath, section, key, defaultValue := "") {
    try {
        fileContent := FileRead(filePath, "UTF-8")
        
        sectionPattern := "\[" section "\]\s*(?:\r?\n|\r)([^\[]*)"
        if RegExMatch(fileContent, sectionPattern, &sectionMatch) {
            sectionContent := sectionMatch[1]
            
            keyPattern := "(?m)^" key "\s*=\s*(.*?)(?:\r?\n|\r|$)"
            if RegExMatch(sectionContent, keyPattern, &keyMatch) {
                value := Trim(keyMatch[1])
                
                dq := Chr(34)
                if (SubStr(value, 1, 1) = dq) and (SubStr(value, -1) = dq)
                    value := SubStr(value, 2, -1)
                value := StrReplace(value, '\"', dq)
                
                if (value != "")
                    return value
            }
        }
    } catch Error as e {
        ; 文件读取失败
    }
    
    try {
        return IniRead(filePath, section, key, defaultValue)
    } catch Error {
        return defaultValue
    }
}

; 写入INI文件的值，使用UTF-8编码（与ReadIniValueUTF8配套，避免IniWrite的ANSI编码问题）
WriteIniValueUTF8(filePath, section, key, value) {
    try {
        if !FileExist(filePath) {
            FileOpen(filePath, "w", "UTF-8").Write("[" section "]`n" key "=" value "`n")
            return true
        }

        fileContent := FileRead(filePath, "UTF-8")
        sectionPattern := "\[" section "\]"

        if RegExMatch(fileContent, sectionPattern) {
            ; Section exists — find and replace/add the key
            keyLinePattern := "(?m)^(" key "\s*=\s*).*$(\r?\n)?"
            if RegExMatch(fileContent, keyLinePattern, &m) {
                ; Key exists — replace its value
                replacement := m[1] . value
                if m.HasOwnProp(2)
                    replacement .= m[2]
                fileContent := RegExReplace(fileContent, keyLinePattern, replacement, , 1)
            } else {
                ; Key doesn't exist — add it after section header
                sectionHeaderPattern := "(\[" section "\]\s*\r?\n?)"
                fileContent := RegExReplace(fileContent, sectionHeaderPattern, "$1" key "=" value "`n", , 1)
            }
        } else {
            ; Section doesn't exist — add it at the end
            if (SubStr(fileContent, -1) != "`n")
                fileContent .= "`n"
            fileContent .= "[" section "]`n" key "=" value "`n"
        }

        FileOpen(filePath, "w", "UTF-8").Write(fileContent)
        return true
    } catch {
        return false
    }
}

; 从INI文件删除整个节（UTF-8安全）
DeleteIniSectionUTF8(filePath, section) {
    try {
        if !FileExist(filePath)
            return true

        fileContent := FileRead(filePath, "UTF-8")
        sectionPattern := "(?m)^\[" section "\].*\r?\n(?:[^[\r\n][^\r\n]*\r?\n)*"

        if RegExMatch(fileContent, sectionPattern) {
            fileContent := RegExReplace(fileContent, sectionPattern, "", , 1)
            FileOpen(filePath, "w", "UTF-8").Write(RTrim(fileContent, "`r`n") . "`n")
        }
        return true
    } catch {
        return false
    }
}

; 从INI文件删除一个键（UTF-8安全）
DeleteIniKeyUTF8(filePath, section, key) {
    try {
        if !FileExist(filePath)
            return true

        fileContent := FileRead(filePath, "UTF-8")
        lines := StrSplit(fileContent, "`n", "`r")
        newLines := []
        inTargetSection := false

        for line in lines {
            if RegExMatch(line, "^\[" section "\]$") {
                inTargetSection := true
                newLines.Push(line)
                continue
            }
            if inTargetSection {
                if RegExMatch(line, "^\[.*\]$") {
                    inTargetSection := false
                    newLines.Push(line)
                    continue
                }
                if RegExMatch(line, "^" key "\s*=") {
                    continue  ; Skip this line (delete the key)
                }
            }
            newLines.Push(line)
        }

        result := ""
        for newLine in newLines {
            result .= newLine . "`n"
        }
        FileOpen(filePath, "w", "UTF-8").Write(RTrim(result, "`n") . "`n")
        return true
    } catch {
        return false
    }
}

; URL编码函数
UrlEncode(str) {
    enc := ""
    Loop Parse, str {
        char := A_LoopField
        if (RegExMatch(char, "^[A-Za-z0-9\-_.~]$"))
            enc .= char
        else {
            code := Ord(char)
            if (code < 128)
                enc .= "%" . Format("{:02X}", code)
            else if (code < 2048) {
                enc .= "%" . Format("{:02X}", 0xC0 | (code >> 6))
                enc .= "%" . Format("{:02X}", 0x80 | (code & 0x3F))
            } else {
                enc .= "%" . Format("{:02X}", 0xE0 | (code >> 12))
                enc .= "%" . Format("{:02X}", 0x80 | ((code >> 6) & 0x3F))
                enc .= "%" . Format("{:02X}", 0x80 | (code & 0x3F))
            }
        }
    }
    return enc
}

; 清除所有ToolTip
ClearAllToolTips() {
    Loop 20 {
        ToolTip("", , , A_Index)
    }
}

; =====================================================================
; GetCaretPosition / GetCaretPosEx 已移至 lib/CaretPos.ahk
; =====================================================================
