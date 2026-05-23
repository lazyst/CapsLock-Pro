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

; 获取光标下的窗口句柄
GetWindowUnderCursor() {
    global showDebugTooltips

    try {
        MouseGetPos(, , &hwnd)

        if (!hwnd || !WinExist("ahk_id " hwnd)) {
            return WinGetID("A")
        }

        class := WinGetClass("ahk_id " hwnd)

        if (class = "Shell_TrayWnd" || class = "Shell_SecondaryTrayWnd")
            return -1

        if (class = "Progman" || class = "WorkerW")
            return 0

        return hwnd
    } catch {
        try {
            return WinGetID("A")
        } catch {
            return 0
        }
    }
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
        sectionRegex := "\[" section "]\K[^[]*"  ; content after [Section] until next [ or EOF

        if RegExMatch(fileContent, sectionRegex, &sectionMatch) {
            sectionContent := sectionMatch[0]
            sectionPos := sectionMatch.Pos
            sectionLen := sectionMatch.Len
            beforeSection := SubStr(fileContent, 1, sectionPos - 1)
            afterSection := SubStr(fileContent, sectionPos + sectionLen)

            keyPattern := "m)^(" key "\s*=\s*)[^\r\n]*(\r?\n?)"
            if RegExMatch(sectionContent, keyPattern, &m) {
                ; Key exists — replace its value within section
                newSection := RegExReplace(sectionContent, keyPattern, m[1] . value . (m.HasOwnProp(2) ? m[2] : "`n"), , 1)
            } else {
                ; Key doesn't exist — append to section content
                newSection := sectionContent . key "=" value "`n"
            }

            fileContent := beforeSection . newSection . afterSection
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
        ; Match [Section]\r\n followed by any number of non-section-header lines
        sectionPattern := "m)^\[" section "]\r?\n(?:[^[\r\n][^\r\n]*\r?\n)*"

        if RegExMatch(fileContent, sectionPattern) {
            fileContent := RegExReplace(fileContent, sectionPattern, "")
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
; 终端命令构造与解析
; =====================================================================

BuildCommandString(cmd, terminal, keepWindow) {
    if (cmd = "")
        return ""
    if (terminal = "direct" || terminal = "")
        return cmd

    switch terminal {
        case "pwsh7":
            return keepWindow
                ? 'wt pwsh -NoExit -c "' cmd '"'
                : 'pwsh -c "' cmd '"'
        case "pwsh5":
            return keepWindow
                ? 'wt powershell -NoExit -Command "' cmd '"'
                : 'powershell -Command "' cmd '"'
        case "cmd":
            return keepWindow
                ? 'wt cmd /k "' cmd '"'
                : 'cmd /c "' cmd '"'
        case "gitbash":
            return keepWindow
                ? 'wt "C:\Program Files\Git\bin\bash.exe" -c "' cmd '"'
                : '"C:\Program Files\Git\bin\bash.exe" -c "' cmd '"'
        case "wslbash":
            return keepWindow
                ? 'wt wsl bash -c "' cmd '"'
                : 'wsl bash -c "' cmd '"'
        default:
            return cmd
    }
}

ParseCommandString(actionStr) {
    if (actionStr = "")
        return { cmd: "", terminal: "direct", keepWindow: false }

    patterns := [
        ; Quoted format (new UI produces these)
        { regex: '^wt pwsh -NoExit -c "(.*)"$', terminal: "pwsh7", keepWindow: true },
        { regex: '^wt powershell -NoExit -Command "(.*)"$', terminal: "pwsh5", keepWindow: true },
        { regex: '^wt cmd /k "(.*)"$', terminal: "cmd", keepWindow: true },
        { regex: '^wt "C:\\Program Files\\Git\\bin\\bash\.exe" -c "(.*)"$', terminal: "gitbash", keepWindow: true },
        { regex: '^wt wsl bash -c "(.*)"$', terminal: "wslbash", keepWindow: true },
        { regex: '^pwsh -c "(.*)"$', terminal: "pwsh7", keepWindow: false },
        { regex: '^powershell -Command "(.*)"$', terminal: "pwsh5", keepWindow: false },
        { regex: '^cmd /c "(.*)"$', terminal: "cmd", keepWindow: false },
        { regex: '^"C:\\Program Files\\Git\\bin\\bash\.exe" -c "(.*)"$', terminal: "gitbash", keepWindow: false },
        { regex: '^wsl bash -c "(.*)"$', terminal: "wslbash", keepWindow: false },
        ; Unquoted format (legacy commands, backward compat)
        { regex: '^wt pwsh -NoExit -c (.+)$', terminal: "pwsh7", keepWindow: true },
        { regex: '^wt powershell -NoExit -Command (.+)$', terminal: "pwsh5", keepWindow: true },
        { regex: '^wt cmd /k (.+)$', terminal: "cmd", keepWindow: true },
        { regex: '^wt "C:\\Program Files\\Git\\bin\\bash\.exe" -c (.+)$', terminal: "gitbash", keepWindow: true },
        { regex: '^wt wsl bash -c (.+)$', terminal: "wslbash", keepWindow: true },
        { regex: '^pwsh -c (.+)$', terminal: "pwsh7", keepWindow: false },
        { regex: '^powershell -Command (.+)$', terminal: "pwsh5", keepWindow: false },
        { regex: '^cmd /c (.+)$', terminal: "cmd", keepWindow: false },
        { regex: '^"C:\\Program Files\\Git\\bin\\bash\.exe" -c (.+)$', terminal: "gitbash", keepWindow: false },
        { regex: '^wsl bash -c (.+)$', terminal: "wslbash", keepWindow: false }
    ]

    for pattern in patterns {
        if RegExMatch(actionStr, pattern.regex, &m)
            return { cmd: m[1], terminal: pattern.terminal, keepWindow: pattern.keepWindow }
    }

    return { cmd: actionStr, terminal: "direct", keepWindow: false }
}

; =====================================================================
; GetCaretPosition / GetCaretPosEx 已移至 lib/CaretPos.ahk
; =====================================================================
