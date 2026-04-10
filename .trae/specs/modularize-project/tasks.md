# Tasks

- [x] Task 1: 创建 lib/ 目录和 Globals.ahk
  - [x] 创建 lib/ 目录
  - [x] 提取所有跨模块共享的全局变量到 lib/Globals.ahk，包括 CapsLock 状态变量、工具启用状态、提示时长、调试开关、窗口切换配置、黑名单配置、鼠标速度变量等
  - [x] 确保全局变量声明无重复（去除原文件中重复声明的变量如 isSeekingSymbol, interruptCheckTimer 等）

- [x] Task 2: 创建 lib/Utils.ahk - 公共工具函数
  - [x] 提取 ShowTooltip, ShowTooltipNearMouse, ToolTipClear, FormatNumber
  - [x] 提取 ToggleDebugTooltips, ShowDebugTooltip
  - [x] 提取 HasVal, StrHash, ShowKeyPressDebug
  - [x] 提取 GetProcessPriority, IsTaskbarWindow
  - [x] 提取 ReadIniValueUTF8, UrlEncode
  - [x] 提取 ShowToolTip（已合并到 ShowTooltip）

- [x] Task 3: 创建 lib/CapsLockHandler.ahk - CapsLock 键行为处理
  - [x] 提取 InitializeGlobalVariables, SetCustomTrayIcon, CustomizeTrayMenu, InitializeApp, CheckCapsLockState
  - [x] 提取 ~CapsLock::, ~CapsLock Up::, ~Escape::, ^CapsLock:: 热键
  - [x] 提取 OnExit 处理
  - [x] 提取 CapsLock 状态监控相关变量和逻辑

- [x] Task 4: 创建 lib/WindowSwitch.ahk - 窗口切换功能
  - [x] 提取 SwitchTaskbarWindow, SwitchNormalTaskbarWindow, MinimizeOtherMaximizedWindows
  - [x] 提取 SortByPID, GetWindowUnderCursor
  - [x] 提取 CapsLock+WheelDown/WheelUp, XButton1/XButton2, Alt+Escape 热键

- [x] Task 5: 创建 lib/TabSwitch.ahk - 标签页切换功能
  - [x] 提取 CapsLock+MButton+WheelDown/WheelUp 热键

- [x] Task 6: 创建 lib/TextEdit.ahk - 文本编辑增强功能
  - [x] 提取所有光标移动函数（MoveLeft/Right/Up/Down, MoveWordLeft/Right, MoveHome/End 等）
  - [x] 提取所有选择函数（SelectLeft/Right/Up/Down, SelectWordLeft/Right, SelectHome/End 等）
  - [x] 提取所有删除函数（DeleteLeft/Right, DeleteWord, ForwardDeleteWord, DeleteLine 等）
  - [x] 提取 EnterWherever, SelectCurrentWord, SelectCurrentLine, IndexWherever
  - [x] 提取 CapsLock+字母键热键映射（a/s/d/e/f/g/w/r/h/j/k/i/l/u/o/space/,/./BackSpace/m/Enter/RShift/z/y/x/c/v/b/t）

- [x] Task 7: 创建 lib/JumpMode.ahk - 自定义跳转功能
  - [x] 提取 GetCaretPosition, GetCaretPosEx（含所有子函数）
  - [x] 提取 ActivateJumpMode, UpdateJumpTooltip, DeactivateJumpMode, ExecuteJump
  - [x] 提取 StartInputHook, StopInputHook, OnKeyDown, OnChar, OnKeyUp, OnInputEnd
  - [x] 提取跳转模式热键（Escape/Delete/CapsLock/LButton/RButton/MButton/Backspace/Enter/字母键）
  - [x] 提取跳转模式全局变量（jumpMode, jumpActive, jumpBuffer, jumpPosition, g_inputHook, isWordJump）

- [x] Task 8: 创建 lib/MouseControl.ahk - 鼠标控制功能
  - [x] 提取 MouseMoveRelative, ResetMouseSpeed, CalculateMovementVector
  - [x] 提取 StartContinuousMouseMovement, StopContinuousMouseMovement, ContinuousMouseMove
  - [x] 提取 MouseLeftDown/Up/RightDown/Up/WheelUp/WheelDown
  - [x] 提取 AdjustMouseSpeed, InitCapsLockPlusModule
  - [x] 提取 CapsLock+方向键热键、CapsLock+RAlt/LAlt 热键
  - [x] 提取鼠标控制全局变量（mousePrecisionMode, mousePrecisionFactor, mouseKeysPressed 等）

- [x] Task 9: 创建 lib/SymbolJump.ahk - 符号跳转功能
  - [x] 提取 ReleaseCapsLock, CheckForInterrupt
  - [x] 提取 CapsLock+p 热键主逻辑
  - [x] 提取 isSeekingSymbol 相关热键
  - [x] 提取符号跳转全局变量（isSeekingSymbol, interruptCheckTimer, initialCapsLockReleased）

- [x] Task 10: 创建 lib/WindowPin.ahk - 窗口置顶功能
  - [x] 提取 IsWindowFullScreen, ToggleWindowPinned
  - [x] 提取 CapsLock+RButton 热键
  - [x] 提取置顶全局变量（pinnedWindows, lastFullscreenWarningTime 等）

- [x] Task 11: 创建 lib/Workspace.ahk - 工作区管理
  - [x] 提取 CleanupWorkspaceHotkey, CheckWindowStateChanged
  - [x] 提取 MinimizeWorkspaceWindows, MinimizeCursorWindowOrOthers, RestoreMinimizedWindows
  - [x] 提取 PerformClick, IsExplorerBrowserOwnerCase, LButtonRenamer, RenameFileUnderCursor
  - [x] 提取 CapsLock+LButton/RButton/#z 热键
  - [x] 提取工作区全局变量（minimizedWindows, lastWorkspaceCleanupTime, workspaceCleanupMode）

- [x] Task 12: 创建 lib/QuickNote.ahk - 速记功能
  - [x] 提取 GetDesktopPath, LoadNoteTargetsFromINI, EnsureNoteDirectories
  - [x] 提取 ShowQuickNote, NoteFileClick, SaveToNewFile, SaveToTargetFile, SaveToSpecificFile
  - [x] 提取 StrRepeat, CleanFileNameFromTitle, ToggleNoteViewHandler
  - [x] 提取 LoadNoteFilesToList, NoteSearchHandler, DeleteSelectedNote
  - [x] 提取 CapsLock+n 热键
  - [x] 提取速记全局变量（noteConfig, noteTargets, noteViewMode 等）

- [x] Task 13: 创建 lib/MenuSystem.ahk - 快捷菜单系统
  - [x] 提取 MenuSettings 配置和菜单全局变量
  - [x] 提取 CheckActiveWindow, GetActionFromString, CheckReloadSignal, ReloadMenuGroups
  - [x] 提取 ClearCapsLockAhkWindows, IsMenuGroupEmpty, ShowMenu
  - [x] 提取 GetCharWidthMap, CalculateTextWidth, CreateMenuGUI, CloseMenu
  - [x] 提取 ExecuteMenuItem, ActivateOrRun
  - [x] 提取 AdjustVolume, OpenFolder, LaunchApp, OpenWebsite, ExecuteCommand, AddButtonIcon, RunCommand
  - [x] 提取 CapsLock+数字键热键和菜单导航热键

- [x] Task 14: 创建 lib/ProcessManage.ahk - 进程管理功能
  - [x] 提取 ManageProcess, ManageProcessWithCtrlCheck
  - [x] 提取 ShowProcessSelectionGUI, ProcessSelection, ProcessSingleItem
  - [x] 提取 SelectAllItems, InvertSelection, BackToMainMenu

- [x] Task 15: 创建 lib/WebsiteManage.ahk - 网站管理功能
  - [x] 提取 WebsiteLogin, OpenDefaultWebsite, OpenOneWebsite
  - [x] 提取 ShowWebsiteSelectionGUI, WebsiteSelection, WebsiteSingleItem

- [x] Task 16: 创建 lib/WindowClip.ahk - 窗口裁切工具
  - [x] 提取常量定义（WS_EX_LAYERED 等）
  - [x] 提取 StartClipWindow, CreateSelectionBox, UpdateSelectionBox
  - [x] 提取 InitMouseTracking, StopMouseTracking, TrackMouseMovement
  - [x] 提取 HandleLeftButtonDown, HandleLeftButtonUp
  - [x] 提取 SetCursorCross, RestoreDefaultCursor, SetWaitCursor, NormalizeCoordinates
  - [x] 提取 SaveWindowState, RestoreWindow, ApplyClipToWindow
  - [x] 提取 DisableShadowForWindow, DisableWeChatShadow, DisableNormalShadow, RestoreShadowForWindow
  - [x] 提取 CancelSelection, CleanupSelection
  - [x] 提取 IsActiveWindowClipped, ShowClipInfo, MoveClipRegion, ResizeClipRegion
  - [x] 提取 StartDragClippedWindow, StopDragClippedWindow, DragWindowTimer
  - [x] 提取 ClearAllToolTips
  - [x] 提取 ^+x/^+z 热键及裁切状态热键
  - [x] 提取裁切全局变量（windowStates, closedShadows, isSelecting 等）

- [x] Task 17: 重写 CapsLock++.ahk 主入口文件
  - [x] 保留 #Requires AutoHotkey v2.0 和 #SingleInstance Force
  - [x] 添加所有 #Include 指令，确保加载顺序正确（Globals → Utils → 功能模块）
  - [x] 保留管理员权限请求
  - [x] 保留 InitializeApp() 调用
  - [x] 确保热键上下文（#HotIf）在各模块中正确工作

- [x] Task 18: 功能验证与调试
  - [x] 运行脚本验证无语法错误
  - [x] 修复 ShowToolTip/ShowTooltip 函数冲突
  - [x] 修复 JumpMode.ahk Base64 字符串截断问题
  - [x] 修复 SymbolJump.ahk 中文引号编码问题
  - [x] 脚本成功运行（退出码 0）

# Task Dependencies
- [Task 1] 和 [Task 2] 无依赖，可最先执行
- [Task 3~16] 依赖 Task 1 和 Task 2，但彼此之间无依赖，可并行执行
- [Task 17] 依赖 Task 3~16 全部完成
- [Task 18] 依赖 Task 17 完成
