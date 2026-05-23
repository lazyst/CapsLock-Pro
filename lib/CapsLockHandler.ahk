; =====================================================================
; CapsLock++ CapsLock 处理模块
; 包含：全局变量初始化、托盘图标/菜单、CapsLock 热键处理、
;       状态检查、调试切换、退出清理
; =====================================================================

SetCustomTrayIcon() {
    iconPath := A_ScriptDir . "\Icon\CapsLock++.ico"

    if (FileExist(iconPath)) {
        TraySetIcon(iconPath)
        A_IconTip := "CapsLock++"
    } else {
        ToolTip("未找到自定义图标文件: " . iconPath)
        SetTimer () => ToolTip(), -3000
    }
}

CustomizeTrayMenu() {
    trayMenu := A_TrayMenu
    trayMenu.Delete()
    trayMenu.Add("退出", (*) => ExitApp())
}

InitializeApp() {
    SetCapsLockState("AlwaysOff")

    SetTimer(CheckCapsLockState, 2000)

    SetCustomTrayIcon()

    CustomizeTrayMenu()

    ToolTip("任务栏应用切换工具已启动`n使用Alt+鼠标滚轮切换窗口")
    SetTimer () => ToolTip(), -3000
}

CheckCapsLockState() {
    global capsLockManuallyEnabled, isToolEnabled

    if (!isToolEnabled)
        return

    if !GetKeyState("CapsLock", "T")
        return

    if !capsLockManuallyEnabled {
        SetCapsLockState("AlwaysOff")
    }
}

SetCapsLockState("AlwaysOff")

^!i::ToggleDebugTooltips()

~CapsLock::
{
    global capsLockIsDown, capsLockPressTime, otherKeyPressed, capsLockManuallyEnabled
    global isToolEnabled, capsLockEscPressed

    if (!capsLockIsDown) {
        capsLockIsDown := true
        capsLockPressTime := A_TickCount
        otherKeyPressed := false
        capsLockEscPressed := GetKeyState("Escape", "P")
    }

    if (isToolEnabled && !capsLockManuallyEnabled)
        SetCapsLockState("AlwaysOff")
}

~CapsLock Up::
{
    global capsLockIsDown, capsLockPressTime, otherKeyPressed, capsLockManuallyEnabled
    global isToolEnabled, capsLockEscPressed, showDebugTooltips

    if (capsLockIsDown) {
        pressDuration := A_TickCount - capsLockPressTime

        capsLockIsDown := false

        if (!isToolEnabled) {
            if (capsLockEscPressed && pressDuration >= 300) {
                isToolEnabled := true
                ShowTooltipNearMouse("CapsLock++ 已启用")
            } else if (!capsLockEscPressed && pressDuration < 300) {
                otherKeyPressed := true
                if GetKeyState("CapsLock", "T") {
                    SetCapsLockState("AlwaysOff")
                    capsLockManuallyEnabled := false
                } else {
                    SetCapsLockState("AlwaysOn")
                    capsLockManuallyEnabled := true
                }
            }

            capsLockEscPressed := false
            otherKeyPressed := false
            return
        }

        if (!capsLockManuallyEnabled)
            SetCapsLockState("AlwaysOff")

        if (capsLockEscPressed && !otherKeyPressed) {
            isToolEnabled := false
            ShowTooltipNearMouse("CapsLock++ 已禁用")
            capsLockEscPressed := false
            otherKeyPressed := false
            return
        }

        if (!otherKeyPressed && pressDuration < 300 && !capsLockEscPressed) {
            SendInput("{Esc}")
        }

        capsLockEscPressed := false
        otherKeyPressed := false
    }
}

~Escape::
{
    global capsLockIsDown, capsLockEscPressed

    if (capsLockIsDown) {
        capsLockEscPressed := true
    }
}

^CapsLock::
{
    global capsLockManuallyEnabled, otherKeyPressed

    otherKeyPressed := true

    if GetKeyState("CapsLock", "T") {
        SetCapsLockState("AlwaysOff")
        capsLockManuallyEnabled := false
        state := "关闭"
    } else {
        SetCapsLockState("AlwaysOn")
        capsLockManuallyEnabled := true
        state := "开启"
    }

    ToolTip("大写锁定: " state)
    SetTimer () => ToolTip(), -1000
}

OnExit((*) => SetCapsLockState("AlwaysOff"))
