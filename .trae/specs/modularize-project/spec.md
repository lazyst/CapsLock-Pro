# CapsLock++ 工程化拆分 Spec

## Why
当前 `CapsLock++.ahk` 是一个约 7800 行的单文件，包含了初始化、CapsLock 处理、窗口切换、文本编辑增强、跳转模式、鼠标控制、符号跳转、窗口置顶、速记功能、快捷菜单、窗口裁切等十几个独立功能模块。单文件导致维护困难、代码定位慢、多人协作冲突频繁，需要按功能模块进行工程化拆分。

## What Changes
- 将 `CapsLock++.ahk` 按功能模块拆分为多个独立 `.ahk` 文件，存放在 `lib/` 目录下
- 主入口文件 `CapsLock++.ahk` 只保留初始化逻辑和 `#Include` 指令
- 提取公共工具函数到 `lib/Utils.ahk`
- 提取全局变量声明到 `lib/Globals.ahk`
- 每个功能模块文件自包含其所需的全局变量声明和函数定义
- **BREAKING**: 文件结构从单文件变为多文件，所有 `#Include` 路径需正确

## Impact
- Affected code: `CapsLock++.ahk`（主入口文件将被大幅精简）
- 新增文件: `lib/` 目录下约 12 个模块文件
- 不影响: `配置助手.ahk`、`窗口信息收集工具.ahk`、`CapsLock++.ini`、`Icon/` 目录

## 目标项目架构

```
CapsLock-Pro/
├── CapsLock++.ahk          # 主入口（初始化 + #Include）
├── lib/
│   ├── Globals.ahk         # 全局变量声明与初始化
│   ├── Utils.ahk           # 公共工具函数（ShowTooltip, HasVal, StrHash 等）
│   ├── CapsLockHandler.ahk # CapsLock 键行为处理（按下/释放/状态管理）
│   ├── WindowSwitch.ahk    # 窗口切换功能（任务栏窗口切换、排序）
│   ├── TabSwitch.ahk       # 标签页切换功能
│   ├── TextEdit.ahk        # 文本编辑增强（光标移动、选择、删除）
│   ├── JumpMode.ahk        # 自定义跳转功能（状态机、InputHook、光标位置获取）
│   ├── MouseControl.ahk    # 鼠标控制（移动、点击、滚轮、速度调整）
│   ├── SymbolJump.ahk      # 符号跳转功能（配对符号搜索）
│   ├── WindowPin.ahk       # 窗口置顶功能（全屏检测、置顶切换）
│   ├── Workspace.ahk       # 工作区管理（窗口最小化/恢复、左键重命名）
│   ├── QuickNote.ahk       # 速记功能（GUI、文件读写、目标配置）
│   ├── MenuSystem.ahk      # 快捷菜单系统（INI 配置读取、GUI 创建、动作执行）
│   ├── ProcessManage.ahk   # 进程管理功能（启用/终止进程）
│   ├── WebsiteManage.ahk   # 网站管理功能（浏览器打开、网站选择 GUI）
│   └── WindowClip.ahk      # 窗口裁切工具（区域选择、阴影禁用、拖动）
├── 配置助手.ahk
├── 窗口信息收集工具.ahk
├── CapsLock++.ini
├── Icon/
│   ├── CapsLock++.ico
│   └── QuickNote.ico
└── .gitignore
```

## 模块划分详情

### lib/Globals.ahk
所有跨模块共享的全局变量集中声明，包括：
- CapsLock 状态变量（capsLockManuallyEnabled, capsLockIsDown, otherKeyPressed 等）
- 工具启用状态（isToolEnabled）
- 提示时长配置（tipDuration, debugTipDuration, longTipDuration）
- 调试开关（showDebugTooltips）
- 窗口切换配置（useTaskbarOrder）
- 黑名单配置（blacklist, blacklistClasses, blacklistProcessNames）
- 鼠标速度变量（mouseSpeedValue, mouseOriginalSpeed）

### lib/Utils.ahk
公共工具函数，无状态依赖：
- ShowTooltip(text, duration)
- ShowTooltipNearMouse(text, duration)
- ToolTipClear()
- FormatNumber(num)
- ToggleDebugTooltips()
- ShowDebugTooltip(text, duration)
- HasVal(arr, val)
- StrHash(str)
- ShowKeyPressDebug(keyName, source)
- GetProcessPriority(processName)
- IsTaskbarWindow(hwnd)
- ReadIniValueUTF8(filePath, section, key, defaultValue)
- UrlEncode(str)

### lib/CapsLockHandler.ahk
CapsLock 键行为核心处理：
- InitializeGlobalVariables()
- SetCustomTrayIcon()
- CustomizeTrayMenu()
- InitializeApp()
- CheckCapsLockState()
- ~CapsLock:: 热键（按下处理）
- ~CapsLock Up:: 热键（释放处理）
- ~Escape:: 热键（Esc 跟踪）
- ^CapsLock:: 热键（手动切换大小写）
- OnExit 处理

### lib/WindowSwitch.ahk
任务栏窗口切换：
- SwitchTaskbarWindow(direction)
- SwitchNormalTaskbarWindow(direction)
- MinimizeOtherMaximizedWindows(activeHwnd, taskbarWindows)
- SortByPID(arr)
- GetWindowUnderCursor()
- CapsLock+WheelDown/WheelUp 热键
- CapsLock+XButton1/XButton2 热键
- Alt+Escape/Alt+Shift+Escape 热键

### lib/TabSwitch.ahk
标签页切换：
- CapsLock+MButton+WheelDown/WheelUp 热键

### lib/TextEdit.ahk
文本编辑增强功能：
- 光标移动函数（MoveLeft/Right/Up/Down, MoveWordLeft/Right, MoveHome/End 等）
- 选择函数（SelectLeft/Right/Up/Down, SelectWordLeft/Right, SelectHome/End 等）
- 删除函数（DeleteLeft/Right, DeleteWord, ForwardDeleteWord, DeleteLine 等）
- EnterWherever(), SelectCurrentWord(), SelectCurrentLine()
- CapsLock+a/s/d/e/f/g/w/r/h/j/k/i/l/u/o/space/,/./BackSpace/m/Enter/RShift/z/y/x/c/v/b/t 热键

### lib/JumpMode.ahk
自定义跳转功能（状态机版本）：
- GetCaretPosition()
- GetCaretPosEx()（含所有子函数：getCaretPosFromGui, getCaretPosFromMSAA, getCaretPosFromUIA 等）
- ActivateJumpMode(mode)
- UpdateJumpTooltip()
- DeactivateJumpMode()
- ExecuteJump()
- StartInputHook() / StopInputHook()
- OnKeyDown / OnChar / OnKeyUp / OnInputEnd
- 跳转模式热键（Escape/Delete/CapsLock/LButton/RButton/MButton/Backspace/Enter/字母键）

### lib/MouseControl.ahk
鼠标控制功能：
- MouseMoveRelative(x, y)
- ResetMouseSpeed()
- CalculateMovementVector()
- StartContinuousMouseMovement() / StopContinuousMouseMovement()
- ContinuousMouseMove()
- MouseLeftDown/Up/RightDown/Up/WheelUp/WheelDown
- AdjustMouseSpeed()
- InitCapsLockPlusModule()
- CapsLock+方向键热键、CapsLock+RAlt/LAlt 热键

### lib/SymbolJump.ahk
符号跳转功能：
- ReleaseCapsLock()
- CheckForInterrupt()
- CapsLock+p 热键（主查找逻辑）
- isSeekingSymbol 相关热键

### lib/WindowPin.ahk
窗口置顶功能：
- IsWindowFullScreen(hwnd)
- ToggleWindowPinned()
- CapsLock+RButton 热键

### lib/Workspace.ahk
工作区管理：
- CleanupWorkspaceHotkey()
- CheckWindowStateChanged()
- MinimizeWorkspaceWindows()
- MinimizeCursorWindowOrOthers()
- RestoreMinimizedWindows()
- PerformClick()
- IsExplorerBrowserOwnerCase()
- LButtonRenamer()
- RenameFileUnderCursor()
- CapsLock+LButton/RButton/#z 热键

### lib/QuickNote.ahk
速记功能：
- GetDesktopPath()
- LoadNoteTargetsFromINI()
- EnsureNoteDirectories()
- ShowQuickNote()
- NoteFileClick()
- SaveToNewFile() / SaveToTargetFile() / SaveToSpecificFile()
- StrRepeat()
- CleanFileNameFromTitle()
- ToggleNoteViewHandler()
- LoadNoteFilesToList()
- NoteSearchHandler()
- DeleteSelectedNote()
- CapsLock+n 热键

### lib/MenuSystem.ahk
快捷菜单系统：
- MenuSettings 配置
- CheckActiveWindow()
- GetActionFromString()
- CheckReloadSignal()
- ReloadMenuGroups()
- ClearCapsLockAhkWindows()
- IsMenuGroupEmpty()
- ShowMenu()
- GetCharWidthMap() / CalculateTextWidth()
- CreateMenuGUI()
- CloseMenu()
- ExecuteMenuItem()
- ActivateOrRun()
- AdjustVolume() / OpenFolder() / LaunchApp() / OpenWebsite() / ExecuteCommand()
- AddButtonIcon()
- RunCommand()
- CapsLock+数字键热键、菜单内导航热键

### lib/ProcessManage.ahk
进程管理：
- ManageProcess(action)
- ManageProcessWithCtrlCheck(action)
- ShowProcessSelectionGUI()
- ProcessSelection() / ProcessSingleItem()
- SelectAllItems() / InvertSelection()
- BackToMainMenu()

### lib/WebsiteManage.ahk
网站管理：
- WebsiteLogin()
- OpenDefaultWebsite()
- OpenOneWebsite()
- ShowWebsiteSelectionGUI()
- WebsiteSelection() / WebsiteSingleItem()

### lib/WindowClip.ahk
窗口裁切工具：
- StartClipWindow()
- CreateSelectionBox() / UpdateSelectionBox()
- InitMouseTracking() / StopMouseTracking() / TrackMouseMovement()
- HandleLeftButtonDown() / HandleLeftButtonUp()
- SetCursorCross() / RestoreDefaultCursor() / SetWaitCursor()
- NormalizeCoordinates()
- SaveWindowState() / RestoreWindow()
- ApplyClipToWindow()
- DisableShadowForWindow() / DisableWeChatShadow() / DisableNormalShadow()
- RestoreShadowForWindow()
- CancelSelection() / CleanupSelection()
- IsActiveWindowClipped() / ShowClipInfo()
- MoveClipRegion() / ResizeClipRegion()
- StartDragClippedWindow() / StopDragClippedWindow() / DragWindowTimer()
- ClearAllToolTips()
- ^+x / ^+z 热键及裁切状态热键

## ADDED Requirements

### Requirement: 模块化项目结构
系统 SHALL 将所有功能代码按模块拆分到 `lib/` 目录下的独立 `.ahk` 文件中。

#### Scenario: 模块文件创建
- **WHEN** 执行拆分操作
- **THEN** 在 `lib/` 目录下创建上述 16 个模块文件，每个文件包含对应功能的全局变量、函数和热键定义

#### Scenario: 主入口文件精简
- **WHEN** 拆分完成
- **THEN** `CapsLock++.ahk` 仅包含 `#Requires`、`#SingleInstance`、`#Include` 指令和必要的初始化调用

### Requirement: 全局变量统一管理
系统 SHALL 在 `lib/Globals.ahk` 中集中声明所有跨模块共享的全局变量。

#### Scenario: 全局变量初始化
- **WHEN** 脚本启动
- **THEN** 所有全局变量通过 `#Include Globals.ahk` 在最早阶段被声明和初始化

### Requirement: 公共工具函数独立
系统 SHALL 将无状态依赖的公共工具函数提取到 `lib/Utils.ahk`。

#### Scenario: 工具函数复用
- **WHEN** 任何模块需要使用 ShowTooltip、HasVal 等函数
- **THEN** 通过 `#Include Utils.ahk` 获取，无需重复定义

### Requirement: 功能等价性
系统 SHALL 保证拆分后的脚本行为与原始单文件完全一致。

#### Scenario: 功能验证
- **WHEN** 运行拆分后的脚本
- **THEN** 所有热键、功能、提示信息与原始脚本行为完全相同

### Requirement: #Include 顺序正确
系统 SHALL 确保 `#Include` 的顺序满足依赖关系，避免函数未定义错误。

#### Scenario: 依赖顺序
- **WHEN** 主入口文件加载模块
- **THEN** Globals.ahk 和 Utils.ahk 最先加载，其他模块按依赖关系顺序加载

## MODIFIED Requirements

### Requirement: CapsLock++.ahk 主入口
主入口文件从包含全部逻辑的单文件变为仅包含初始化和模块引用的入口文件。

## REMOVED Requirements
（无移除项）
