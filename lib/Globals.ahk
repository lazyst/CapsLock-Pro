; =====================================================================
; CapsLock++ 全局变量声明
; =====================================================================

; 检查值是否为字符串类型（AHK v2 兼容）
IsString(value) {
    return Type(value) = "String"
}

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

; 调试开关（已废弃，使用 Logger 模块）
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

; 鼠标控制全局变量
global mouseModeEnabled := false
global mouseMoveTimer := 0
global mouseSpeed := 5
global mouseWheelTimer := 0
global mouseWheelDirection := ""

; 符号跳转全局变量
global isSeekingSymbol := false
global interruptCheckTimer := 0
global initialCapsLockReleased := false

; 窗口置顶全局变量
global pinnedWindows := []
global lastFullscreenWarningTime := 0
global lastFullscreenWarningHwnd := 0
global fullscreenWarningTimeout := 1000

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
global newNoteBtn := ""
global viewToggleBtn := ""

; 快捷菜单全局变量
global currentMenuGui := 0
global currentMenuGroup := 0
global checkActiveTimerId := 0
global forceKeepMenu := false
global configHelperGui := ""
global MenuSettings := {
    FontName: "Segoe UI",
    FontSize: 10,
    AnimationEnabled: true,
    CornerRadius: 12,
    Background: "0xFFFFFF",
    Text: "0x1A1A1A",
    Border: "0xE0E0E0",
    TitleBg: "0xF5F5F5",
    TitleText: "0x1A1A1A",
    HoverBg: "0xE8E8E8",
    ButtonBg: "0xFFFFFF",
    ButtonHover: "0xF0F0F0",
    Accent: "0x0078D4"
}

ApplyMenuTheme(darkMode) {
    global MenuSettings
    if darkMode {
        MenuSettings.Background := "0x2D2D2D"
        MenuSettings.Text := "0xE0E0E0"
        MenuSettings.Border := "0x404040"
        MenuSettings.TitleBg := "0x1E1E1E"
        MenuSettings.TitleText := "0xE0E0E0"
        MenuSettings.HoverBg := "0x3D3D3D"
        MenuSettings.ButtonBg := "0x383838"
        MenuSettings.ButtonHover := "0x4D4D4D"
        MenuSettings.Accent := "0x4FC3F7"
    } else {
        MenuSettings.Background := "0xFFFFFF"
        MenuSettings.Text := "0x1A1A1A"
        MenuSettings.Border := "0xE0E0E0"
        MenuSettings.TitleBg := "0xF5F5F5"
        MenuSettings.TitleText := "0x1A1A1A"
        MenuSettings.HoverBg := "0xE8E8E8"
        MenuSettings.ButtonBg := "0xFFFFFF"
        MenuSettings.ButtonHover := "0xF0F0F0"
        MenuSettings.Accent := "0x0078D4"
    }
}

global menuGroupNum := 0
global enableGroup := []
global groupName := []
global groupCount := []
global MenuGroups := Map()

; 文本编辑全局变量
global lastSpaceTime := 0
global pendingOperation := false
global doubleClickThreshold := 500
global hasExecutedSingleClick := false

; 剪贴板保存变量
global ClipboardSaved_Independent := ""

; INI 配置文件路径
global iniFile := A_ScriptDir "\CapsLock++.ini"

; 配置文件路径

; 初始化黑名单进程名称缓存
for path in blacklist {
    SplitPath(path, &processName)
    blacklistProcessNames.Push(processName)
}
