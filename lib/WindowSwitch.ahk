; =====================================================================
; CapsLock++ 窗口切换模块
; 包含任务栏窗口切换、排序、最小化等功能及对应热键
; =====================================================================

SwitchTaskbarWindow(direction) {
    SwitchNormalTaskbarWindow(direction)
}

SwitchNormalTaskbarWindow(direction) {
    global useTaskbarOrder, showDebugTooltips, longTipDuration, debugTipDuration, tipDuration

    taskbarWindows := []

    winList := WinGetList(,, "Program Manager")

    if showDebugTooltips {
        ToolTip("原始窗口数量: " winList.Length)
        SetTimer () => ToolTip(), -debugTipDuration
    }

    for hwnd in winList {
        if IsTaskbarWindow(hwnd) {
            pid := WinGetPID("ahk_id " hwnd)
            processPath := ProcessGetPath(pid)
            SplitPath(processPath, &processName)

            title := WinGetTitle("ahk_id " hwnd)

            priority := GetProcessPriority(processName)

            taskbarWindows.Push({
                hwnd: hwnd,
                pid: pid,
                processName: processName,
                title: title,
                priority: priority
            })
        }
    }

    if showDebugTooltips {
        ToolTip("找到的任务栏窗口数量: " taskbarWindows.Length)
        SetTimer () => ToolTip(), -debugTipDuration
    }

    if (taskbarWindows.Length = 0) {
        if showDebugTooltips {
            ToolTip("没有找到可切换的窗口")
            SetTimer () => ToolTip(), -tipDuration
        }
        return
    }

    taskbarWindows := SortByPID(taskbarWindows)

    if showDebugTooltips {
        debugText := "排序后的窗口列表 (按PID和标题):`n"
        for i, win in taskbarWindows {
            debugText .= i ": " win.title " (PID:" win.pid ", 句柄:" win.hwnd ")`n"
            if (i > 8)
                break
        }
        ToolTip(debugText)
        SetTimer () => ToolTip(), -3000
    }

    try {
        activeHwnd := WinGetID("A")
    } catch {
        if (taskbarWindows.Length > 0) {
            nextIndex := direction > 0 ? 1 : taskbarWindows.Length
            nextHwnd := taskbarWindows[nextIndex].hwnd

            WinActivate("ahk_id " nextHwnd)

            if showDebugTooltips {
                ToolTip("从桌面切换到: " taskbarWindows[nextIndex].title " (句柄:" nextHwnd ")")
                SetTimer () => ToolTip(), -debugTipDuration
            }

            Sleep(30)
            if (WinGetMinMax("ahk_id " nextHwnd) = 1) {
                MinimizeOtherMaximizedWindows(nextHwnd, taskbarWindows)
            }
        }
        return
    }

    currentIndex := 0

    for i, win in taskbarWindows {
        if win.hwnd = activeHwnd {
            currentIndex := i
            break
        }
    }

    if showDebugTooltips && currentIndex > 0 {
        ToolTip("当前窗口: " taskbarWindows[currentIndex].title " (索引:" currentIndex ", 句柄:" activeHwnd ")")
        SetTimer () => ToolTip(), -debugTipDuration
    }

    if currentIndex = 0 {
        nextIndex := (direction > 0) ? 1 : taskbarWindows.Length
    } else {
        nextIndex := currentIndex + direction

        if nextIndex > taskbarWindows.Length
            nextIndex := 1
        else if nextIndex < 1
            nextIndex := taskbarWindows.Length
    }

    if !taskbarWindows.Has(nextIndex) {
        if showDebugTooltips {
            ToolTip("无法找到下一个窗口")
            SetTimer () => ToolTip(), -tipDuration
        }
        return
    }

    nextHwnd := taskbarWindows[nextIndex].hwnd

    if (nextHwnd = activeHwnd) {
        if showDebugTooltips {
            ToolTip("下一个窗口就是当前窗口，跳过激活")
            SetTimer () => ToolTip(), -tipDuration
        }
        return
    }

    if showDebugTooltips {
        fromTitle := currentIndex > 0 ? taskbarWindows[currentIndex].title : "未知窗口"
        toTitle := taskbarWindows[nextIndex].title
        fromHwnd := currentIndex > 0 ? taskbarWindows[currentIndex].hwnd : 0
        toHwnd := taskbarWindows[nextIndex].hwnd

        switchInfo := "从窗口 " currentIndex " 切换到 " nextIndex "`n"
        switchInfo .= "从: " fromTitle " (句柄:" fromHwnd ")`n"
        switchInfo .= "到: " toTitle " (句柄:" toHwnd ")`n"
        switchInfo .= "方向: " (direction > 0 ? "正向" : "反向")

        ToolTip(switchInfo)
        SetTimer () => ToolTip(), -debugTipDuration
    }

    WinActivate("ahk_id " nextHwnd)

    Sleep(30)

    if (WinGetMinMax("ahk_id " nextHwnd) = 1) {
        MinimizeOtherMaximizedWindows(nextHwnd, taskbarWindows)
    }
}

MinimizeOtherMaximizedWindows(activeHwnd, taskbarWindows) {
    global showDebugTooltips

    minimizedCount := 0

    for _, win in taskbarWindows {
        if (win.hwnd = activeHwnd)
            continue

        if (WinGetMinMax("ahk_id " win.hwnd) = 1) {
            WinMinimize("ahk_id " win.hwnd)
            minimizedCount++
        }
    }

    if (showDebugTooltips && minimizedCount > 0) {
        ToolTip("已最小化 " minimizedCount " 个其他最大化窗口")
        SetTimer () => ToolTip(), -debugTipDuration
    }
}

GetWindowUnderCursor() {
    try {
        MouseGetPos(&xpos, &ypos, &hwnd)

        if (!hwnd || !WinExist("ahk_id " hwnd)) {
            activeHwnd := WinGetID("A")
            return activeHwnd
        }

        class := WinGetClass("ahk_id " hwnd)
        pid := WinGetPID("ahk_id " hwnd)
        processPath := ProcessGetPath(pid)
        SplitPath(processPath, &processName)

        if (class = "Shell_TrayWnd" || class = "Shell_SecondaryTrayWnd") {
            if (showDebugTooltips) {
                ToolTip("光标在任务栏上，不执行最小化操作")
                SetTimer () => ToolTip(), -2000
            }
            return -1
        }

        if (class = "Progman" || class = "WorkerW") {
            if (showDebugTooltips) {
                title := WinGetTitle("ahk_id " hwnd)
                ToolTip("检测到真正的桌面窗口: " title "`n类: " class)
                SetTimer () => ToolTip(), -2000
            }

            return 0
        }

        if (showDebugTooltips) {
            title := WinGetTitle("ahk_id " hwnd)
            class := WinGetClass("ahk_id " hwnd)
            ToolTip("光标下窗口: " title "`n类: " class "`n句柄: " hwnd)
            SetTimer () => ToolTip(), -2000
        }

        return hwnd
    } catch as e {
        try {
            activeHwnd := WinGetID("A")
            return activeHwnd
        } catch {
            return 0
        }
    }
}

SortByPID(arr) {
    global showDebugTooltips

    n := arr.Length
    Loop n - 1 {
        i := A_Index
        Loop n - i {
            j := A_Index

            if (arr[j].pid > arr[j+1].pid) {
                temp := arr[j]
                arr[j] := arr[j+1]
                arr[j+1] := temp
            }
            else if (arr[j].pid = arr[j+1].pid) {
                try {
                    if (arr[j].title > arr[j+1].title) {
                        temp := arr[j]
                        arr[j] := arr[j+1]
                        arr[j+1] := temp
                    }
                } catch {
                    if (arr[j].hwnd > arr[j+1].hwnd) {
                        temp := arr[j]
                        arr[j] := arr[j+1]
                        arr[j+1] := temp
                    }
                }
            }
        }
    }

    if (showDebugTooltips) {
        debugText := "排序后的窗口列表 (按PID和标题):`n"
        for i, win in arr {
            debugText .= i ": " win.title " (PID:" win.pid ", 句柄:" win.hwnd ")`n"
            if (i > 8)
                break
        }
        ToolTip(debugText)
        SetTimer () => ToolTip(), -3000
    }

    return arr
}

#HotIf GetKeyState("CapsLock", "P") && isToolEnabled
WheelDown::
{
    global otherKeyPressed := true

    if GetKeyState("LAlt", "P") {
        global mouseSpeedValue
        mouseSpeedValue := Max(mouseSpeedValue - 1, 1)
        ShowTooltip("鼠标速度已调整为: " mouseSpeedValue)
    } else {
        SwitchTaskbarWindow(1)

        if (showDebugTooltips) {
            ShowTooltip("CapsLock+WheelDown: 正向切换窗口")
        }
    }
}

WheelUp::
{
    global otherKeyPressed := true

    if GetKeyState("LAlt", "P") {
        global mouseSpeedValue
        mouseSpeedValue := Min(mouseSpeedValue + 1, 20)
        ShowTooltip("鼠标速度已调整为: " mouseSpeedValue)
    } else {
        SwitchTaskbarWindow(-1)

        if (showDebugTooltips) {
            ShowTooltip("CapsLock+WheelUp: 反向切换窗口")
        }
    }
}
#HotIf

XButton1::
{
    global otherKeyPressed := true
    SwitchTaskbarWindow(1)

    if (showDebugTooltips) {
        ShowTooltip("XButton1: 正向切换窗口")
    }
}

XButton2::
{
    global otherKeyPressed := true
    SwitchTaskbarWindow(-1)

    if (showDebugTooltips) {
        ShowTooltip("XButton2: 反向切换窗口")
    }
}

!Escape::SwitchTaskbarWindow(1)
!+Escape::SwitchTaskbarWindow(-1)
