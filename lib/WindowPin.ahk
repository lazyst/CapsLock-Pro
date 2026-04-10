; =====================================================================
; CapsLock++ 窗口置顶模块
; 包含：全屏检测、窗口置顶/取消置顶功能
; =====================================================================

IsWindowFullScreen(hwnd) {
    isMaximized := WinGetMinMax("ahk_id " hwnd) = 1
    
    WinGetPos(&winX, &winY, &winWidth, &winHeight, "ahk_id " hwnd)
    
    monitorIndex := DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 0x2)
    
    numput("UInt", 40, MONITORINFO := Buffer(40))
    if (DllCall("GetMonitorInfo", "Ptr", monitorIndex, "Ptr", MONITORINFO)) {
        monitorLeft := NumGet(MONITORINFO, 20, "Int")
        monitorTop := NumGet(MONITORINFO, 24, "Int")
        monitorRight := NumGet(MONITORINFO, 28, "Int")
        monitorBottom := NumGet(MONITORINFO, 32, "Int")
        
        monitorFullLeft := NumGet(MONITORINFO, 4, "Int")
        monitorFullTop := NumGet(MONITORINFO, 8, "Int")
        monitorFullRight := NumGet(MONITORINFO, 12, "Int")
        monitorFullBottom := NumGet(MONITORINFO, 16, "Int")
        
        monitorWidth := monitorRight - monitorLeft
        monitorHeight := monitorBottom - monitorTop
        
        monitorFullWidth := monitorFullRight - monitorFullLeft
        monitorFullHeight := monitorFullBottom - monitorFullTop
        
        isFullScreenWithTaskbar := (Abs(winX - monitorFullLeft) <= 1) && 
                        (Abs(winY - monitorFullTop) <= 1) && 
                        (Abs(winWidth - monitorFullWidth) <= 1) && 
                        (Abs(winHeight - monitorFullHeight) <= 1)
        
        isFullScreenWorkArea := (Abs(winX - monitorLeft) <= 1) && 
                        (Abs(winY - monitorTop) <= 1) && 
                        (Abs(winWidth - monitorWidth) <= 1) && 
                        (Abs(winHeight - monitorHeight) <= 1)
        
        return isMaximized || isFullScreenWithTaskbar || isFullScreenWorkArea
    }
    
    screenWidth := A_ScreenWidth
    screenHeight := A_ScreenHeight
    
    isFullScreenBySize := (Abs(winX) <= 1) && 
                          (Abs(winY) <= 1) && 
                          (Abs(winWidth - screenWidth) <= 1) && 
                          (Abs(winHeight - screenHeight) <= 1)
    
    return isMaximized || isFullScreenBySize
}

ToggleWindowPinned() {
    global lastFullscreenWarningTime, lastFullscreenWarningHwnd, fullscreenWarningTimeout
    
    try {
        hwnd := GetWindowUnderCursor()
        
        if !WinExist("ahk_id " hwnd) {
            ToolTip("光标下无有效窗口")
            SetTimer () => ToolTip(), -2000
            return
        }
        if !IsTaskbarWindow(hwnd) {
            ToolTip("当前窗口不是任务栏窗口，无法置顶")
            SetTimer () => ToolTip(), -2000
            return
        }
        
        title := WinGetTitle("ahk_id " hwnd)
        
        pid := WinGetPID("ahk_id " hwnd)
        processPath := ProcessGetPath(pid)
        SplitPath(processPath, &processName)
        
        simpleName := RegExReplace(processName, "\.exe$", "")
        
        className := WinGetClass("ahk_id " hwnd)
        
        if (className = "Progman" || className = "WorkerW") {
            ToolTip("桌面窗口不能置顶")
            SetTimer () => ToolTip(), -2000
            return
        }
        
        exStyle := WinGetExStyle("ahk_id " hwnd)
        isPinned := (exStyle & 0x8) != 0
        
        isFullScreen := IsWindowFullScreen(hwnd)
        
        if (isPinned) {
            WinSetAlwaysOnTop(0, "ahk_id " hwnd)
            
            for i, pinHwnd in pinnedWindows {
                if (pinHwnd = hwnd) {
                    pinnedWindows.RemoveAt(i)
                    break
                }
            }
            
            ToolTip("已取消置顶: " simpleName)
        } else {
            if (isFullScreen) {
                currentTime := A_TickCount
                
                if (hwnd = lastFullscreenWarningHwnd && 
                    (currentTime - lastFullscreenWarningTime) < fullscreenWarningTimeout) {
                    WinSetAlwaysOnTop(1, "ahk_id " hwnd)
                    
                    if !HasVal(pinnedWindows, hwnd)
                        pinnedWindows.Push(hwnd)
                    
                    ToolTip("已强制置顶全屏窗口: " simpleName)
                    
                    lastFullscreenWarningTime := 0
                    lastFullscreenWarningHwnd := 0
                } else {
                    ToolTip("全屏窗口不建议置顶: " simpleName "`n(再次操作将强制置顶)")
                    
                    lastFullscreenWarningTime := currentTime
                    lastFullscreenWarningHwnd := hwnd
                }
                
                SetTimer () => ToolTip(), -fullscreenWarningTimeout
                return
            }
            
            WinSetAlwaysOnTop(1, "ahk_id " hwnd)
            
            if !HasVal(pinnedWindows, hwnd)
                pinnedWindows.Push(hwnd)
            
            ToolTip("已置顶窗口: " simpleName)
        }
        
        SetTimer () => ToolTip(), -2000
        
    } catch as e {
        ToolTip("置顶窗口操作失败: " e.Message)
        SetTimer () => ToolTip(), -2000
    }
}
