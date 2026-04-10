; =====================================================================
; CapsLock++ 窗口裁切模块
; 包含：窗口裁切、区域选择、阴影禁用、裁切区域移动/调整/拖动功能
; 使用 Ctrl+Shift+X 裁切光标下的窗口，通过鼠标拖拽选择保留区域，并自动禁用窗口阴影
; 使用 Ctrl+Shift+Z 恢复窗口原始状态
; =====================================================================

; 常量定义
WS_EX_LAYERED := 0x80000
WS_EX_TRANSPARENT := 0x20
WS_EX_TOOLWINDOW := 0x80
WS_EX_DLGMODALFRAME := 0x1
WS_EX_TOPMOST := 0x8
LWA_ALPHA := 0x2
LWA_COLORKEY := 0x1

; 热键：裁切窗口
^+x::StartClipWindow()

; 热键：恢复窗口 - 如果正在选择区域，则取消选择
^+z::
{
    if (isSelecting) {
        CancelSelection()
        ShowTooltip("已取消选择")
    } else {
        RestoreWindow()
    }
}

#HotIf IsActiveWindowClipped()
; 控制裁切区域移动的热键
^WheelDown:: MoveClipRegion("down")
^WheelUp:: MoveClipRegion("up")
^+WheelDown:: MoveClipRegion("right")
^+WheelUp:: MoveClipRegion("left")
; 添加新的热键 - 拖动裁切过的窗口
^+LButton:: StartDragClippedWindow()
^+LButton Up:: StopDragClippedWindow()
; 添加新的热键 - 调整裁剪区域大小
^!WheelUp:: ResizeClipRegion("heightIncrease")    ; Ctrl+Alt+滚轮上 - 增加高度
^!WheelDown:: ResizeClipRegion("heightDecrease")  ; Ctrl+Alt+滚轮下 - 减少高度
^+!WheelUp:: ResizeClipRegion("widthIncrease")    ; Ctrl+Shift+Alt+滚轮上 - 增加宽度
^+!WheelDown:: ResizeClipRegion("widthDecrease")  ; Ctrl+Shift+Alt+滚轮下 - 减少宽度
#HotIf

; 开始裁切窗口过程
StartClipWindow() {
    global isSelecting, targetWindow, winOffsetX, winOffsetY
    
    ; 清除所有可能存在的ToolTip，避免干扰
    ClearAllToolTips()
    
    ; 获取鼠标下的窗口句柄
    MouseGetPos(&mouseX, &mouseY, &hWnd)
    
    if (!hWnd) {
        ;ShowTooltip("未检测到窗口")
        return
    }
    
    ; 获取窗口信息进行黑名单检查
    winTitle := WinGetTitle("ahk_id " hWnd)
    className := WinGetClass("ahk_id " hWnd)
    processName := WinGetProcessName("ahk_id " hWnd)
    processPath := WinGetProcessPath("ahk_id " hWnd)
    
    ; 硬编码排除特定窗口
    ; 排除桌面/Program Manager
    if (className == "Progman" && winTitle == "Program Manager" && processName == "explorer.exe") {
        ShowTooltip("无法裁剪桌面窗口")
        return
    }
    
    ; 排除任务栏
    if (className == "Shell_TrayWnd" && processName == "explorer.exe") {
        ShowTooltip("无法裁剪任务栏")
        return
    }
    
    ; 排除文件资源管理器
    if (className == "CabinetWClass" && processName == "explorer.exe") {
        ShowTooltip("无法裁剪资源管理器")
        return
    }
    
    ; 排除QQ悬浮栏
    if ((processName == "QQ.exe" || processName == "QQScLauncher.exe" || processName == "QQProtect.exe") && InStr(winTitle, "QQ")) {
        ShowTooltip("无法裁剪QQ悬浮栏")
        return
    }
    
    ; 排除VueMinder日历窗口
    if (InStr(className, "WindowsForms10.Window.8.app.0.1a0e24_r10_ad1") && 
        (processName == "VueMinder.exe" || InStr(processPath, "VueMinder.exe"))) {
        ShowTooltip("无法裁剪VueMinder窗口")
        return
    }
    
    ; 排除QuinkNote的SwitchPlug插件
    if (InStr(className, "HwndWrapper[SwitchPlug.exe") || 
        InStr(processPath, "QuinkNote\plugins\switchPlug\bin\SwitchPlug.exe")) {
        ShowTooltip("无法裁剪SwitchPlug窗口")
        return
    }

    ; 排除fences的folder portal
    if (className == "ExplorerBrowserOwner" && processName == "explorer.exe") {
        ShowTooltip("无法裁剪folder portal")
        return
    }

    if (className == "TaskManagerWindow" && processName == "Taskmgr.exe"){
        ShowTooltip("无法裁剪任务管理器")
        return
    }
    
    ; 检查是否已经在选择中
    if (isSelecting) {
        ;ShowTooltip("已经在选择区域中，请完成当前操作")
        return
    }
    
    ; 检查窗口是否已被处理，如果是则先恢复
    if (windowStates.Has(hWnd)) {
        RestoreWindow(hWnd)
    }

    ; 排除OneCommander
    if (InStr(className, "HwndWrapper[OneCommander.exe") || processName == "OneCommander.exe") {
        ShowTooltip("无法裁剪OneCommander窗口")
        return
    }
    
    ; 获取窗口位置和大小
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " hWnd)
    
    ; 保存窗口原始状态 - 包括更多属性以支持阴影禁用
    SaveWindowState(hWnd)
    
    ; 确保窗口有分层样式
    if (!(WinGetExStyle(hWnd) & WS_EX_LAYERED)) {
        WinSetExStyle("+0x80000", "ahk_id " hWnd)
    }
    
    ; 记录目标窗口和偏移量
    targetWindow := hWnd
    winOffsetX := winX
    winOffsetY := winY
    
    ; 设置状态为选择中
    isSelecting := true
    
    ; 设置等待裁剪的光标样式
    SetWaitCursor()
    
    ; 创建临时热键来监听鼠标事件 (只在选择模式下有效)
    Hotkey("*LButton", HandleLeftButtonDown, "On")
    Hotkey("Escape", CancelSelection, "On")
}

; 创建选择框
CreateSelectionBox() {
    global selectionBox
    
    ; 如果已存在选择框，先销毁
    if (selectionBox && WinExist("ahk_id " . selectionBox)) {
        Gui(selectionBox . ":Destroy")
    }
    
    ; 直接创建一个新的窗口而不保存对象
    selectionBox := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20")
    
    ; 设置窗口颜色和透明度 - 使用黑色以保持一致性
    selectionBox.BackColor := "000000"
    WinSetTransparent(100, selectionBox)
    
    ; 先显示在屏幕左上角以确保窗口创建成功 - 使用NA参数避免激活窗口
    selectionBox.Show("x0 y0 w5 h5 NA")
    
    ; 设置置顶和透明点击穿透属性
    WinSetExStyle("+0x8 +0x20", "ahk_id " . selectionBox.Hwnd) ; WS_EX_TOPMOST | WS_EX_TRANSPARENT
    
    return selectionBox.Hwnd
}

; 更新选择框位置
UpdateSelectionBox(x, y, w, h) {
    global selectionBox
    
    ; 立即捕获有效性判断结果，避免在判断和使用之间状态变化
    validSelection := selectionBox && WinExist("ahk_id " . selectionBox)
    if (!validSelection) {
        return false
    }
    
    ; 确保最小尺寸
    w := Max(w, 5)
    h := Max(h, 5)
    
    ; 使用更安全的错误处理方式更新窗口
    success := false
    try {
        ; 直接使用修改后的静态调用，避免引用问题
        hwnd := selectionBox + 0  ; 确保是数字
        if (hwnd) {
            WinMove(x, y, w, h, "ahk_id " . hwnd)
            success := true
        }
    }
    
    return success
}

; 初始化鼠标追踪系统
InitMouseTracking() {
    global trackingTimer
    
    ; 停止任何现有的追踪计时器
    if (trackingTimer) {
        SetTimer(trackingTimer, 0)
    }
    
    ; 设置高频率计时器来追踪鼠标 - 修复This引用
    trackingTimer := TrackMouseMovement
    SetTimer(trackingTimer, 16)  ; 约60FPS的刷新率
    
    ; 也同时设置消息钩子作为备份机制
    OnMessage(0x0200, MouseMove)  ; WM_MOUSEMOVE
}

; 停止鼠标追踪
StopMouseTracking() {
    global trackingTimer
    
    ; 停止追踪计时器
    if (trackingTimer) {
        SetTimer(trackingTimer, 0)
        trackingTimer := 0
    }
    
    ; 移除消息钩子
    OnMessage(0x0200, MouseMove, 0)
}

; 计时器调用的鼠标追踪函数
TrackMouseMovement(*) {
    global isSelecting, targetWindow, selectionBox, startX, startY, endX, endY, lastTrackX, lastTrackY
    
    if (!isSelecting)
        return
    
    ; 获取鼠标位置
    CoordMode("Mouse", "Screen")
    MouseGetPos(&screenX, &screenY)
    
    ; 如果位置与上次相同，不需要更新
    if (screenX = lastTrackX && screenY = lastTrackY)
        return
    
    ; 更新最后追踪位置
    lastTrackX := screenX
    lastTrackY := screenY
    
    ; 获取目标窗口位置
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . targetWindow)
    
    ; 更新结束坐标（相对于窗口）
    endX := screenX - winX
    endY := screenY - winY
    
    ; 计算选择框位置（确保正确的上左到右下顺序）
    left := Min(startX, endX)
    top := Min(startY, endY)
    width := Abs(endX - startX)
    height := Abs(endY - startY)
    
    ; 转换回屏幕坐标
    screenLeft := winX + left
    screenTop := winY + top
    
    ; 更新选择框
    if (!UpdateSelectionBox(screenLeft, screenTop, width, height)) {
        ; 如果更新失败，尝试重新创建选择框
        selectionBox := CreateSelectionBox()
        UpdateSelectionBox(screenLeft, screenTop, width, height)
    }
}

; 处理鼠标左键按下
HandleLeftButtonDown(*) {
    global isSelecting, targetWindow, startX, startY, selectionBox, lastTrackX, lastTrackY
    
    if (!isSelecting)
        return
    
    ; 关闭左键监听，以免冲突
    Hotkey("*LButton", "Off")
    
    ; 获取鼠标相对于屏幕的坐标
    CoordMode("Mouse", "Screen")
    MouseGetPos(&screenX, &screenY)
    
    ; 记录起始位置用于追踪比较
    lastTrackX := screenX
    lastTrackY := screenY
    
    ; 获取目标窗口的位置
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . targetWindow)
    
    ; 计算鼠标相对于窗口的位置
    startX := screenX - winX
    startY := screenY - winY
    
    ; 设置全局十字光标
    SetCursorCross()
    
    ; 创建选择框
    selectionBox := CreateSelectionBox()
    
    ; 立即更新选择框到起始位置
    UpdateSelectionBox(screenX, screenY, 5, 5)
    
    ; 初始化持续追踪系统
    InitMouseTracking()
    
    ; 设置左键释放监听
    Hotkey("*LButton up", HandleLeftButtonUp, "On")
}

; 处理鼠标左键释放
HandleLeftButtonUp(*) {
    global isSelecting, targetWindow, startX, startY, endX, endY
    
    if (!isSelecting)
        return
    
    ; 停止鼠标追踪
    StopMouseTracking()
    
    ; 获取最终鼠标位置
    CoordMode("Mouse", "Screen")
    MouseGetPos(&screenX, &screenY)
    
    ; 转换为相对于窗口的坐标
    WinGetPos(&winX, &winY, , , "ahk_id " targetWindow)
    endX := screenX - winX
    endY := screenY - winY
    
    ; 确保坐标正确（左上到右下）
    NormalizeCoordinates()
    
    ; 计算宽高
    width := endX - startX
    height := endY - startY
    
    ; 检查选择区域是否过小
    if (width < 10 || height < 10) {
        CancelSelection()
        ShowTooltip("选择区域太小，已取消")
        return
    }
    
    ; 验证目标窗口状态在Map中存在
    if (!windowStates.Has(targetWindow)) {
        ; 窗口状态不存在，可能是因为在选择过程中窗口被恢复了
        ; 重新保存窗口状态
        SaveWindowState(targetWindow)
    }
    
    ; 先处理分层样式和阴影（除了微信）
    winExe := windowStates[targetWindow].winExe
    if (winExe != "WeChat.exe") {
        ; 确保窗口有分层样式
        if (!(WinGetExStyle(targetWindow) & WS_EX_LAYERED)) {
            WinSetExStyle("+0x80000", "ahk_id " targetWindow)
        }
        
        ; 禁用阴影 - 在应用裁剪前
        DisableShadowForWindow(targetWindow)
    }
    
    ; 然后应用裁切
    ApplyClipToWindow(targetWindow, startX, startY, width, height)
    
    ; 对于微信，在裁剪后处理阴影
    if (winExe = "WeChat.exe") {
        DisableShadowForWindow(targetWindow)
    }
    
    ; 清理选择相关资源
    CleanupSelection()
    
    ; 恢复正常鼠标指针
    RestoreDefaultCursor()
}

; 设置鼠标十字形样式 - 使用系统光标API实现持久替换
SetCursorCross() {
    ; 加载系统十字光标
    hCross := DllCall("LoadCursor", "Ptr", 0, "Ptr", 32515, "Ptr")  ; IDC_CROSS = 32515
    
    ; 替换所有系统光标为十字光标
    ; 注意：这会替换系统的所有光标类型，但在我们的场景中这是可接受的
    ; 0 = OCR_NORMAL (标准箭头)
    DllCall("SetSystemCursor", "Ptr", DllCall("CopyIcon", "Ptr", hCross, "Ptr"), "UInt", 32512)  ; OCR_NORMAL
    ; 1 = OCR_IBEAM (I-形文本光标)
    DllCall("SetSystemCursor", "Ptr", DllCall("CopyIcon", "Ptr", hCross, "Ptr"), "UInt", 32513)  ; OCR_IBEAM
}

; 恢复默认鼠标样式
RestoreDefaultCursor() {
    ; 恢复所有系统光标为默认值
    DllCall("SystemParametersInfo", "UInt", 0x0057, "UInt", 0, "Ptr", 0, "UInt", 0)  ; SPI_SETCURSORS = 0x0057
}

; 确保坐标顺序正确（左上角到右下角）
NormalizeCoordinates() {
    global startX, startY, endX, endY
    
    ; 如果结束点在起始点的左边，交换X坐标
    if (endX < startX) {
        temp := startX
        startX := endX
        endX := temp
    }
    
    ; 如果结束点在起始点的上边，交换Y坐标
    if (endY < startY) {
        temp := startY
        startY := endY
        endY := temp
    }
}

; 保存窗口状态 - 增强版，支持更多属性
SaveWindowState(hWnd) {
    ; 获取当前窗口样式
    exStyle := WinGetExStyle(hWnd)
    
    ; 获取窗口进程名
    winExe := WinGetProcessName(hWnd)
    
    ; 检查是否已经是分层窗口
    isLayered := (exStyle & WS_EX_LAYERED) != 0
    
    ; 如果是分层窗口，获取当前透明度
    alpha := 255
    if (isLayered) {
        try {
            transparency := WinGetTransparent("ahk_id " hWnd)
            if (transparency != "") {
                alpha := transparency
            }
        }
    }
    
    ; 检查窗口是否为最大化或全屏
    isMaximized := WinGetMinMax("ahk_id " hWnd) = 1
    
    ; 检查窗口是否可能是全屏(通过检测窗口位置和屏幕尺寸)
    MonitorGetWorkArea(, &monLeft, &monTop, &monRight, &monBottom)
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " hWnd)
    isFullscreen := (winX <= monLeft) && (winY <= monTop) && 
                   (winX + winW >= monRight) && (winY + winH >= monBottom)
    
    ; 保存状态 - 包括更多信息以支持阴影禁用
    windowStates[hWnd] := {
        exStyle: exStyle, 
        isLayered: isLayered, 
        alpha: alpha,
        region: "",          ; 原始区域（通常为空）
        winExe: winExe,      ; 进程名，用于特殊处理不同应用
        shadowDisabled: false, ; 标记阴影是否已被禁用
        isMaximized: isMaximized, ; 窗口是否最大化
        isFullscreen: isFullscreen ; 窗口是否可能是全屏
    }
}

; 应用裁切到窗口
ApplyClipToWindow(hWnd, x, y, width, height) {
    try {
        ; 创建矩形区域
        hRgn := DllCall("CreateRectRgn", "Int", x, "Int", y, 
                        "Int", x + width, "Int", y + height, "Ptr")
        
        ; 应用区域到窗口
        if (hRgn) {
            ; 获取窗口当前属性
            winExe := windowStates[hWnd].winExe
            
            ; 应用区域
            DllCall("SetWindowRgn", "Ptr", hWnd, "Ptr", hRgn, "Int", true)
            
            ; 保存使用的区域信息以便恢复
            windowStates[hWnd].region := {x: x, y: y, w: width, h: height}
            
            ; 对于非微信窗口，设置透明度为254
            if (winExe != "WeChat.exe" && windowStates[hWnd].isLayered) {
                DllCall("SetLayeredWindowAttributes", "Ptr", hWnd, "UInt", 0, "UChar", 254, "UInt", LWA_ALPHA)
            }
        } else {
            ShowTooltip("创建区域失败")
        }
    } catch as e {
        ShowTooltip("裁切窗口失败: " e.Message)
    }
}

; 禁用窗口阴影
DisableShadowForWindow(hWnd) {
    ; 如果窗口状态不存在，返回
    if (!windowStates.Has(hWnd)) {
        return
    }
    
    ; 确保winExe属性存在
    if (!windowStates[hWnd].HasOwnProp("winExe")) {
        ; 如果没有winExe属性，获取并设置它
        windowStates[hWnd].winExe := WinGetProcessName(hWnd)
    }
    
    ; 获取窗口进程名
    winExe := windowStates[hWnd].winExe
    winTitle := WinGetTitle(hWnd)
    
    ; 对于微信使用特殊处理
    if (winExe = "WeChat.exe") {
        DisableWeChatShadow(hWnd)
    } else {
        DisableNormalShadow(hWnd)
    }
    
    ; 标记阴影已被禁用
    windowStates[hWnd].shadowDisabled := true
}

; 针对微信的阴影禁用方法
DisableWeChatShadow(hWnd) {
    ; 查找微信阴影窗口
    shadowHwnd := WinExist("ahk_class popupshadow")
    if (!shadowHwnd) {
        return  ; 如果没找到阴影窗口就不处理
    }
    
    ; 获取主窗口位置和大小
    WinGetPos(&mainX, &mainY, &mainW, &mainH, "ahk_id " hWnd)
    
    ; 获取阴影窗口位置和大小
    WinGetPos(&shadowX, &shadowY, &shadowW, &shadowH, "ahk_id " shadowHwnd)
    
    ; 检查位置关系
    isMatch := (shadowX <= mainX - 10) 
            && (shadowY <= mainY - 10)
            && (shadowW >= mainW + 20)
            && (shadowH >= mainH + 20)
            
    if (isMatch) {
        ; 保存阴影窗口信息，用于恢复
        closedShadows[hWnd] := {
            shadowHwnd: shadowHwnd, 
            shadowX: shadowX, 
            shadowY: shadowY, 
            shadowW: shadowW, 
            shadowH: shadowH
        }
        
        ; 关闭阴影窗口
        WinClose("ahk_id " shadowHwnd)
    }
}

; 针对普通窗口的阴影禁用方法
DisableNormalShadow(hWnd) {
    ; 尝试多种DWM属性来禁用阴影
    ; DWMWA_NCRENDERING_POLICY = 2
    value := Buffer(4, 0)
    NumPut("Int", 1, value)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hWnd, "Int", 2, "Ptr", value, "Int", 4)
    
    ; DWMWA_EXCLUDED_FROM_PEEK = 12
    NumPut("Int", 1, value)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hWnd, "Int", 12, "Ptr", value, "Int", 4)
    
    ; 检查特定应用的特殊处理
    winExe := windowStates[hWnd].winExe
    
    ; 对于特定应用添加额外样式
    if (winExe = "Typora.exe") {
        ; 对于Typora，添加额外的样式
        newStyle := WinGetExStyle(hWnd) | WS_EX_DLGMODALFRAME
        DllCall("SetWindowLong", "Ptr", hWnd, "Int", -20, "Int", newStyle)
    }
    
    ; 设置透明度为254（几乎完全不透明）- 这有助于去除阴影
    if (windowStates[hWnd].isLayered) {
        DllCall("SetLayeredWindowAttributes", "Ptr", hWnd, "UInt", 0, "UChar", 254, "UInt", LWA_ALPHA)
    }
    
    ; 强制重绘窗口
    DllCall("SetWindowPos", "Ptr", hWnd, "Ptr", 0, "Int", 0, "Int", 0, 
           "Int", 0, "Int", 0, "UInt", 0x0027) ; SWP_NOSIZE | SWP_NOMOVE | SWP_NOZORDER | SWP_FRAMECHANGED
}

; 取消选择
CancelSelection(*) {
    global isSelecting
    
    if (!isSelecting)
        return
    
    CleanupSelection()
    ShowTooltip("已取消选择")
}

; 清理选择相关资源
CleanupSelection() {
    global isSelecting, selectionBox, trackingTimer
    
    ; 停止鼠标追踪
    StopMouseTracking()
    
    ; 关闭临时热键
    Hotkey("*LButton", "Off")
    Hotkey("*LButton up", HandleLeftButtonUp, "Off")  ; 修改为包含回调函数名称
    Hotkey("Escape", "Off")
    
    ; 销毁选择框 - 修复销毁方法
    if (selectionBox && WinExist("ahk_id " . selectionBox)) {
        try {
            WinClose("ahk_id " . selectionBox)
        } catch {
            ; 忽略错误
        }
        selectionBox := 0
    }
    
    ; 清除工具提示
    ToolTip("")
    
    ; 恢复默认鼠标
    RestoreDefaultCursor()
    
    ; 重置状态
    isSelecting := false
}

; 恢复窗口函数 - 增强版，同时恢复阴影
RestoreWindow(hWnd := 0) {
    global windowStates, closedShadows
    
    ; 如果未提供窗口句柄，获取鼠标下的窗口
    if (!hWnd) {
        MouseGetPos(, , &hWnd)
        
        if (!hWnd) {
            ShowTooltip("未检测到窗口")
            return
        }
    }
    
    winTitle := WinGetTitle(hWnd)
    
    ; 检查是否有保存的窗口状态
    if (!windowStates.Has(hWnd)) {
        ShowTooltip("未找到窗口原始状态: " winTitle)
        return
    }
    
    ; 获取保存的状态
    state := windowStates[hWnd]
    
    ; 清除窗口区域设置（恢复完整窗口）
    DllCall("SetWindowRgn", "Ptr", hWnd, "Ptr", 0, "Int", true)
    
    ; 如果阴影被禁用了，恢复阴影
    if (state.shadowDisabled) {
        RestoreShadowForWindow(hWnd)
    }
    
    ; 如果原始窗口不是分层窗口，则移除分层样式
    if (!state.isLayered) {
        WinSetExStyle("-0x80000", "ahk_id " hWnd)
    } else if (state.alpha != 255) {
        ; 恢复原来的透明度
        WinSetTransparent(state.alpha, "ahk_id " hWnd)
    }
    
    ; 从Map中移除
    windowStates.Delete(hWnd)
    
    ;ShowTooltip("已恢复窗口: " winTitle)
}

; 恢复窗口阴影
RestoreShadowForWindow(hWnd) {
    ; 检查是否是微信窗口且有关闭的阴影窗口
    if (closedShadows.Has(hWnd)) {
        ; 从映射中删除条目，微信重新激活后会自动创建阴影
        closedShadows.Delete(hWnd)
        return
    }
    
    ; 普通窗口阴影恢复
    ; 还原DWM渲染策略
    value := Buffer(4, 0)
    NumPut("Int", 0, value) ; DWMNCRP_USEWINDOWSTYLE = 0
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hWnd, "Int", 2, "Ptr", value, "Int", 4)
    
    ; 还原DWMWA_EXCLUDED_FROM_PEEK
    NumPut("Int", 0, value)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hWnd, "Int", 12, "Ptr", value, "Int", 4)
    
    ; 检查是否需要恢复特定的窗口样式
    if (windowStates[hWnd].HasOwnProp("exStyle")) {
        ; 还原窗口扩展样式
        DllCall("SetWindowLong", "Ptr", hWnd, "Int", -20, "Int", windowStates[hWnd].exStyle)
    }
    
    ; 强制重绘窗口
    DllCall("SetWindowPos", "Ptr", hWnd, "Ptr", 0, "Int", 0, "Int", 0, 
           "Int", 0, "Int", 0, "UInt", 0x0027) ; SWP_NOSIZE | SWP_NOMOVE | SWP_NOZORDER | SWP_FRAMECHANGED
}

; 设置等待裁剪的光标样式 - 使用手型光标表示可以进行选择
SetWaitCursor() {
    ; 加载手型光标
    hHand := DllCall("LoadCursor", "Ptr", 0, "Ptr", 32649, "Ptr")  ; IDC_HAND = 32649
    
    ; 替换标准箭头光标为手型光标
    DllCall("SetSystemCursor", "Ptr", DllCall("CopyIcon", "Ptr", hHand, "Ptr"), "UInt", 32512)  ; OCR_NORMAL
}

; 检查当前活动窗口是否被裁剪的函数
IsActiveWindowClipped() {
    try {
        ; 获取当前活动窗口的句柄
        activeHwnd := WinGetID("A")
        
        ; 检查窗口是否在裁剪窗口列表中且确实有区域信息
        if (windowStates.Has(activeHwnd) && windowStates[activeHwnd].HasOwnProp("region")) {
            ; 确认region不为空并且有有效的尺寸
            region := windowStates[activeHwnd].region
            if (IsObject(region) && region.HasOwnProp("w") && region.HasOwnProp("h") && 
                region.w > 0 && region.h > 0) {
                return true
            }
        }
        
        return false
    } catch {
        ; 如果获取窗口信息失败（比如没有激活窗口），返回 false
        return false
    }
}

; 显示当前裁剪窗口信息的函数
ShowClipInfo() {
    try {
        activeHwnd := WinGetID("A")
        
        if (windowStates.Has(activeHwnd) && windowStates[activeHwnd].HasOwnProp("region")) {
            region := windowStates[activeHwnd].region
            winTitle := WinGetTitle(activeHwnd)
            
            infoText := "窗口: " winTitle "`n"
            infoText .= "裁剪区域: x=" region.x ", y=" region.y ", w=" region.w ", h=" region.h
            
            ShowTooltip(infoText, 3000)
        }
    } catch {
        ; 如果获取窗口信息失败，静默忽略
        return
    }
}

; 裁切区域移动函数 - 添加边界限制
MoveClipRegion(direction, step := 50) {
    try {
        activeHwnd := WinGetID("A")
        
        ; 确保窗口是已裁剪的
        if (!windowStates.Has(activeHwnd) || !windowStates[activeHwnd].HasOwnProp("region")) {
            return
        }
        
        ; 获取当前裁切区域
        region := windowStates[activeHwnd].region
        x := region.x
        y := region.y
        w := region.w
        h := region.h
        
        ; 获取窗口尺寸用于边界检查
        WinGetPos(, , &winWidth, &winHeight, "ahk_id " activeHwnd)
        
        ; 根据方向移动裁切区域，同时检查边界
        switch direction {
            case "up":
                y := Max(0, y - step)
            case "down":
                ; 确保裁切区域的底部不超出窗口
                y := Min(y + step, winHeight - h)
            case "left":
                x := Max(0, x - step)
            case "right":
                ; 确保裁切区域的右侧不超出窗口
                x := Min(x + step, winWidth - w)
        }
        
        ; 应用新的裁切区域
        ApplyClipToWindow(activeHwnd, x, y, w, h)
        
        /*
        ; 显示更新后的裁切区域信息
        infoText := "窗口: " WinGetTitle(activeHwnd) "`n"
        infoText .= "裁剪区域: x=" x ", y=" y ", w=" w ", h=" h "`n"
        infoText .= "窗口尺寸: " winWidth "x" winHeight
        ShowTooltip(infoText, 1000)
        */
    } catch {
        ; 如果获取窗口信息失败，静默忽略
        return
    }
}

; 调整裁剪区域大小
ResizeClipRegion(action, step := 20) {
    try {
        activeHwnd := WinGetID("A")
        
        ; 确保窗口是已裁剪的
        if (!windowStates.Has(activeHwnd) || !windowStates[activeHwnd].HasOwnProp("region")) {
            return
        }
        
        ; 获取当前裁切区域
        region := windowStates[activeHwnd].region
        x := region.x
        y := region.y
        w := region.w
        h := region.h
        
        ; 获取窗口尺寸用于边界检查
        WinGetPos(, , &winWidth, &winHeight, "ahk_id " activeHwnd)
        
        ; 根据操作调整裁剪区域大小
        switch action {
            case "widthIncrease":
                ; 确保不超出窗口右边界
                w := Min(w + step, winWidth - x)
            case "widthDecrease":
                ; 确保宽度不小于最小值
                w := Max(w - step, 20)
            case "heightIncrease":
                ; 确保不超出窗口底部边界
                h := Min(h + step, winHeight - y)
            case "heightDecrease":
                ; 确保高度不小于最小值
                h := Max(h - step, 20)
        }
        
        ; 应用新的裁切区域
        ApplyClipToWindow(activeHwnd, x, y, w, h)
        
        ; 显示调整后的区域信息
        infoText := "裁剪区域: " w "×" h
        ShowTooltip(infoText, 1000)
    } catch {
        ; 如果获取窗口信息失败，静默忽略
        return
    }
}

; 开始拖动裁切窗口 - 改进版
StartDragClippedWindow() {
    global isDragging, dragHwnd, startX, startY, offsetX, offsetY
    
    try {
        ; 获取当前活动窗口
        activeHwnd := WinGetID("A")
        
        ; 确保是被裁切的窗口
        if (!IsActiveWindowClipped())
            return
        
        ; 获取鼠标初始位置
        CoordMode("Mouse", "Screen")
        MouseGetPos(&startX, &startY)
        
        ; 获取窗口初始位置
        WinGetPos(&winX, &winY, , , "ahk_id " activeHwnd)
        
        ; 计算鼠标相对于窗口左上角的偏移量
        offsetX := startX - winX
        offsetY := startY - winY
        
        ; 设置状态
        isDragging := true
        dragHwnd := activeHwnd
        
        ; 使用SetTimer来实现窗口拖动
        SetTimer(DragWindowTimer, 6)
    } catch {
        ; 如果获取窗口信息失败（比如没有激活窗口），静默忽略
        return
    }
}

; 停止拖动裁切窗口
StopDragClippedWindow() {
    global isDragging, dragHwnd
    
    ; 停止计时器
    SetTimer(DragWindowTimer, 0)
    
    ; 重置状态
    isDragging := false
    dragHwnd := 0
    
    ; 清除提示
    ;ToolTip("")
}

; 拖动窗口的计时器函数 - 改进版
DragWindowTimer() {
    global isDragging, dragHwnd, offsetX, offsetY
    
    ; 如果没有在拖动，或者窗口不存在，停止计时器
    if (!isDragging || !WinExist("ahk_id " dragHwnd)) {
        SetTimer(DragWindowTimer, 0)
        isDragging := false
        return
    }
    
    ; 获取当前鼠标位置
    CoordMode("Mouse", "Screen")
    MouseGetPos(&currentX, &currentY)
    
    ; 计算新窗口位置 - 考虑鼠标在窗口内的偏移量
    newX := currentX - offsetX
    newY := currentY - offsetY
    
    ; 移动窗口到新位置
    WinMove(newX, newY, , , "ahk_id " dragHwnd)
}
