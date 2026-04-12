; =====================================================================
; CapsLock++ 工作区管理模块
; 包含：虚拟环境管理、工作区清理、窗口最小化/恢复、文件重命名等功能
; =====================================================================

#HotIf GetKeyState("CapsLock", "P") && isToolEnabled

RButton::
{
    global otherKeyPressed := true
    ToggleWindowPinned()
}

LButton::
{
    global otherKeyPressed := true
    local IsRename := false
    
    try {
        activeWin := WinGetID("A")
        activeWinClass := WinGetClass("ahk_id " activeWin)
    } catch {
        activeWin := 0
        activeWinClass := ""
    }
    
    try {
        MouseGetPos(, , &mouseWin)
        mouseWinClass := WinGetClass("ahk_id " mouseWin)
    } catch {
        mouseWin := 0
        mouseWinClass := ""
    }
    
    needActivate := IsExplorerBrowserOwnerCase(activeWinClass, mouseWinClass)
    
    if (needActivate) {
        WinActivate("ahk_id " mouseWin)
        SetTimer(PerformClick, -40)
        return
    }
    
    Click("Left")
    
    SetTimer (LButtonRenamer), -20
}
#HotIf

PerformClick() {
    Click("Left")
    SetTimer(LButtonRenamer, -20)
}

IsExplorerBrowserOwnerCase(activeWinClass, mouseWinClass) {
    if ((activeWinClass = "ExplorerBrowserOwner" && mouseWinClass != "ExplorerBrowserOwner") ||
        (activeWinClass != "ExplorerBrowserOwner" && mouseWinClass = "ExplorerBrowserOwner")) {
        return true
    }
    return false
}

LButtonRenamer(){
    MouseGetPos(, , &mouseWin)
    if (mouseWin) {
        activeClass := WinGetClass("ahk_id " mouseWin)
    } else {
        activeClass := ""
    }
    
    if (activeClass = "CabinetWClass" || activeClass = "ExploreWClass" || 
        activeClass = "Progman" || activeClass = "WorkerW" || activeClass = "ExplorerBrowserOwner") {
        Send("{F2}")
    }
}

#HotIf GetKeyState("CapsLock", "P") && isToolEnabled
#z::CleanupWorkspaceHotkey()
#HotIf

CleanupWorkspaceHotkey() {
    global minimizedWindows, lastWorkspaceCleanupTime, workspaceCleanupMode
    
    ToolTip("工作区清理功能已触发")
    SetTimer () => ToolTip(), -1000
    
    currentTime := A_TickCount
    
    if (minimizedWindows.Length > 0) {
        windowsChanged := false
        validWindowCount := 0
        
        for _, winInfo in minimizedWindows {
            if (WinExist("ahk_id " winInfo.hwnd)) {
                validWindowCount++
                currentMinState := WinGetMinMax("ahk_id " winInfo.hwnd) = -1
                if (currentMinState != true) {
                    windowsChanged := true
                    break
                }
            }
        }
        
        if (validWindowCount = 0 || windowsChanged) {
            ToolTip("窗口状态已变化或无有效窗口，`n执行最小化操作")
            SetTimer () => ToolTip(), -2000
            minimizedWindows := []
            MinimizeWorkspaceWindows()
        } else {
            RestoreMinimizedWindows()
        }
    } else {
        MinimizeWorkspaceWindows()
    }
    
    lastWorkspaceCleanupTime := currentTime
}

CheckWindowStateChanged() {
    global minimizedWindows, lastWorkspaceCleanupTime
    
    if (minimizedWindows.Length = 0)
        return false
    
    for i, winInfo in minimizedWindows {
        if (!WinExist("ahk_id " winInfo.hwnd))
            return true
        
        currentMinState := WinGetMinMax("ahk_id " winInfo.hwnd) = -1
        if (currentMinState != winInfo.wasMinimized)
            return true
    }
    
    return false
}

MinimizeWorkspaceWindows() {
    global minimizedWindows
    
    minimizedWindows := []
    
    cursorHwnd := GetWindowUnderCursor()
    
    if (cursorHwnd = -1) {
        ToolTip("光标在任务栏上，不执行最小化操作")
        SetTimer () => ToolTip(), -2000
        return
    }
    
    if (!cursorHwnd || !WinExist("ahk_id " cursorHwnd)) {
        try {
            cursorHwnd := WinGetID("A")
        } catch {
            cursorHwnd := 0
        }
    }
    
    if (cursorHwnd && WinExist("ahk_id " cursorHwnd)) {
        MinimizeCursorWindowOrOthers(cursorHwnd)
    } else {
        ToolTip("无法获取有效窗口，清理操作取消")
        SetTimer () => ToolTip(), -2000
    }
}

MinimizeCursorWindowOrOthers(cursorHwnd) {
    global minimizedWindows, blacklistProcessNames, blacklistClasses, pinnedWindows
    
    title := WinGetTitle("ahk_id " cursorHwnd)
    pid := WinGetPID("ahk_id " cursorHwnd)
    processPath := ProcessGetPath(pid)
    SplitPath(processPath, &processName)
    simpleName := RegExReplace(processName, "\.exe$", "")
    
    winList := WinGetList(,, "Program Manager")
    minimizedCount := 0
    
    pinnedHwndsMap := Map()
    for _, pinnedHwnd in pinnedWindows {
        pinnedHwndsMap[pinnedHwnd] := true
    }
    
    for hwnd in winList {
        if (!IsTaskbarWindow(hwnd))
            continue
            
        if (hwnd = cursorHwnd)
            continue
            
        winTitle := WinGetTitle("ahk_id " hwnd)
        winPid := WinGetPID("ahk_id " hwnd)
        winProcessPath := ProcessGetPath(winPid)
        SplitPath(winProcessPath, &winProcessName)
        winSimpleName := RegExReplace(winProcessName, "\.exe$", "")
        
        className := WinGetClass("ahk_id " hwnd)
        
        if (HasVal(blacklistProcessNames, winProcessName))
            continue
            
        isBlacklistedClass := false
        for blackClass in blacklistClasses {
            if (InStr(className, blackClass) || className = blackClass) {
                isBlacklistedClass := true
                break
            }
        }
        
        if (isBlacklistedClass)
            continue
            
        exStyle := WinGetExStyle("ahk_id " hwnd)
        isPinned := (exStyle & 0x8) != 0
        
        if (isPinned || pinnedHwndsMap.Has(hwnd))
            continue
            
        wasMinimized := WinGetMinMax("ahk_id " hwnd) = -1
        
        if (!wasMinimized) {
            WinMinimize("ahk_id " hwnd)
            
            minimizedWindows.Push({
                hwnd: hwnd,
                title: winTitle,
                processName: winProcessName,
                simpleName: winSimpleName,
                wasMinimized: wasMinimized
            })
            
            minimizedCount++
        }
    }
    
    if (minimizedCount > 0) {
        ShowTooltipNearMouse("已最小化 " minimizedCount " 个其他窗口`n保留窗口: " simpleName "`n再次按Ctrl+Win+Z恢复")
    } else {
        ShowTooltipNearMouse("没有其他需要最小化的窗口")
    }
}

RestoreMinimizedWindows() {
    global minimizedWindows
    
    if (minimizedWindows.Length = 0) {
        ShowTooltipNearMouse("没有需要恢复的窗口")
        return
    }
    
    restoredCount := 0
    invalidCount := 0
    restoredNames := []
    
    for i, winInfo in minimizedWindows {
        try {
            if (WinExist("ahk_id " winInfo.hwnd)) {
                WinRestore("ahk_id " winInfo.hwnd)
                
                WinActivate("ahk_id " winInfo.hwnd)
                
                if (winInfo.HasOwnProp("simpleName") && winInfo.simpleName != "")
                    restoredNames.Push(winInfo.simpleName)
                else if (winInfo.HasOwnProp("processName"))
                    restoredNames.Push(RegExReplace(winInfo.processName, "\.exe$", ""))
                    
                restoredCount++
            } else {
                invalidCount++
            }
        } catch as e {
            ShowTooltipNearMouse("恢复窗口时出错: " e.Message)
            invalidCount++
        }
    }
    
    if (restoredCount > 0) {
        try {
            for _, winInfo in minimizedWindows {
                if (WinExist("ahk_id " winInfo.hwnd)) {
                    WinActivate("ahk_id " winInfo.hwnd)
                    break
                }
            }
        } catch {
        }
    }
    
    minimizedWindows := []
    
    if (restoredCount > 0) {
        resultText := "已恢复 " restoredCount " 个窗口"
        
        if (restoredNames.Length > 0) {
            resultText .= "`n恢复的窗口: "
            maxNamesToShow := Min(restoredNames.Length, 3)
            Loop maxNamesToShow {
                resultText .= restoredNames[A_Index]
                if (A_Index < maxNamesToShow)
                    resultText .= ", "
            }
            
            if (restoredNames.Length > maxNamesToShow)
                resultText .= " 等..."
        }
        
        if (invalidCount > 0)
            resultText .= "`n" invalidCount " 个窗口已不存在"
        
        ToolTip(resultText)
    } else if (invalidCount > 0) {
        ToolTip("所有记录的窗口已不存在")
    }
    
    SetTimer () => ToolTip(), -2000
}

RenameFileUnderCursor() {
    Send("{F2}")
}
