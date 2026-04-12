; =====================================================================
; CapsLock++ 全局变量声明
; =====================================================================

; CapsLock 状态监控相关变量
global capsLockManuallyEnabled := false
global capsLockKeyPressed := false
global capsLockPressTime := 0
global capsLockReleaseTime := 0
global otherKeyPressed := false
global capsLockIsDown := false
global capsLockEscPressed := false

; 工具启用状态
global isToolEnabled := true

; 提示信息显示时间（毫秒）
global tipDuration := 2000
global debugTipDuration := 3000
global longTipDuration := 5000

; 调试开关
global showDebugTooltips := false

; 窗口切换配置
global useTaskbarOrder := false
global includeMultipleInstances := true

; 首次运行标志
global isFirstRun := true

; 黑名单设置
global blacklist := []
global blacklistClasses := []
global blacklistProcessNames := []

; 跳转模式全局变量
global jumpMode := ""
global jumpActive := false
global jumpBuffer := ""
global jumpPosition := {x: 0, y: 0}
global g_inputHook := {}
global isWordJump := false

; 鼠标控制全局变量
global mouseModeEnabled := false
global mouseMoveTimer := 0
global mouseSpeed := Integer(IniRead(A_ScriptDir "\CapsLock++.ini", "MouseMode", "Speed", "5"))

; 符号跳转全局变量
global isSeekingSymbol := false
global interruptCheckTimer := 0
global initialCapsLockReleased := false

; 窗口置顶全局变量
global pinnedWindows := []
global lastFullscreenWarningTime := 0
global lastFullscreenWarningHwnd := 0
global fullscreenWarningTimeout := 1000

; 工作区管理全局变量
global minimizedWindows := []
global lastWorkspaceCleanupTime := 0
global workspaceCleanupMode := "minimize"

; 速记功能全局变量
global noteConfig := {
    defaultDir: A_ScriptDir . "\速记\"
}
global noteTargets := Map()
global noteViewMode := false
global noteSearchText := ""
global noteListView := {}
global currentEditingFile := ""
global noteEdit := ""
global noteGui := ""
global statusBar := ""
global searchEdit := ""
global searchLabel := ""
global deleteBtn := ""

; 快捷菜单全局变量
global currentMenuGui := 0
global currentMenuGroup := 0
global checkActiveTimerId := 0
global forceKeepMenu := false
global MenuSettings := {
    DarkMode: IniRead(A_ScriptDir "\CapsLock++.ini", "MenuGroupsColourMode", "DarkMode", "true") = "true",
    FontName: "Segoe UI",
    FontSize: 10,
    DarkColors: {
        Background: "0x202020",
        Text: "0xFFFFFF",
        Border: "0x505050",
        TitleBg: "0x303030",
        TitleText: "0xFFFFFF"
    },
    LightColors: {
        Background: "0xF0F0F0",
        Text: "0x000000",
        Border: "0xD0D0D0",
        TitleBg: "0xFFFFFF",
        TitleText: "0x000000"
    }
}
global menuGroupNum := 0
global enableGroup := []
global groupName := []
global groupCount := []
global MenuGroups := Map()

; 窗口裁切全局变量
global windowStates := Map()
global closedShadows := Map()
global isSelecting := false
global targetWindow := 0
global selectionBox := 0
global startX := 0, startY := 0
global endX := 0, endY := 0
global winOffsetX := 0, winOffsetY := 0
global trackingTimer := 0
global lastTrackX := 0, lastTrackY := 0
global isDragging := false
global dragHwnd := 0
global offsetX := 0, offsetY := 0

; 文本编辑全局变量
global lastSpaceTime := 0
global pendingOperation := false
global doubleClickThreshold := 500
global hasExecutedSingleClick := false

; 剪贴板保存变量
global ClipboardSaved_Independent := ""

; 配置文件路径
global iniFile := A_ScriptDir "\CapsLock++.ini"

; 初始化黑名单进程名称缓存
for path in blacklist {
    SplitPath(path, &processName)
    blacklistProcessNames.Push(processName)
}
