# CapsLock++ 更新日志

所有项目的重要更改都将记录在此文件中。

## \[v1.4.0\] - 2026-05-22

### 🔧 代码质量改进

- **拆分光标定位模块**: 将 `Utils.ahk` 中约 340 行的 `GetCaretPosition()` / `GetCaretPosEx()` 函数族提取为独立的 `lib/CaretPos.ahk`
  - `Utils.ahk` 从 556 行缩减至 204 行（-63%），职责更清晰
  - 新增 `lib/CaretPos.ahk` 专管光标位置获取（GUI Thread Info / MSAA / UIA / Hook 四种策略）

- **符号跳转模块重构 (`SymbolJump.ahk`)**:
  - 消除向前/向后搜索之间约 150 行重复代码，统一为 `_SearchInDirection(dir)` 函数
  - `Sleep(10)` 手动剪贴板轮询全部替换为 `ClipWait()`，减少 CPU 占用
  - 提取 `_ScanLine`、`_ReadLineContent`、`_CheckBoundary`、`_ClipWait` 等 6 个独立函数
  - 文件从 423 行缩减至 355 行（-17%）

- **清除死代码**: 删除 `Globals.ahk` 中 3 行无引用的全局变量（`settingsConfigPath`、`configMenusPath`、`settings`）

- **集中全局变量声明**: 将 `newNoteBtn`、`viewToggleBtn`、`configHelperGui` 3 个缺失的变量声明统一至 `Globals.ahk`

## \[v1.3.0\] - 2026-05-23

### ✨ 移除功能

- **动作系统移除**: 移除了 `ActionEngine.ahk` 和 `ActionEditor.ahk` 整个动作管理子系统
  - 菜单项动作简化为纯字符串格式，不再支持结构化动作对象
  - 配置助手移除"动作管理"Tab 及相关构建/编辑/转换函数
  - 菜单项动作可直接输入原始命令，无需 `RunCommand()` 前缀
  - 向后兼容：旧格式 `RunCommand("...")`/`SendInput("...")`/`ActivateOrRun("...")` 仍可执行
- **网站管理模块移除**: 移除了 `WebsiteLogin()` 及相关网站配置功能
  - 删除 `lib/WebsiteManage.ahk` 整个模块
  - 清理 `CapsLock++.ini` 中的 `[CommonWebsites]` 配置节
  - 清理菜单组3（原"网站"组）的菜单项

### 🐛 修复

- **修复缺失的源码文件**: 创建了 5 个之前缺失的存根模块，使源代码可正常运行：
  - `lib/core/Logger.ahk` — 日志系统
  - `lib/core/ConfigManager.ahk` — 配置管理器（从 INI 读写）
  - `lib/core/ActionEngine.ahk` — 动作执行引擎（后续已移除）
  - `lib/ui/MenuUI.ahk` — 菜单 UI
  - `lib/ui/ActionEditor.ahk` — 动作编辑器（后续已移除）
- **修复括号不匹配**: 删除代码后 `ConfigHelper.ahk` 中 `GetActionSummary` 和 `ConvertToOldActionString` 函数遗留的括号问题
- **修复缺失变量**: 添加 `iniFile` 全局变量定义
- **修复参数错误**: `MenuUI.ahk` 中 `MakeMenuItemHandler` 传递给 `ExecuteMenuItem` 的参数数量错误

## \[v1.2.0\] - 2025-10-28

### ✨ 移除功能

- **微信悄悄话功能移除**: 由于微信大版本更新, 悄悄话功能已不再适用, 且窗口裁切已覆盖该功能, 因此移除

### ✨ 调整功能

- **标签页切换调整**: 右键+滚轮操作中右键可能与某些自带右键菜单的软件冲突, 而强行安装钩子会导致恶性bug, 因此调整为滚轮按下+滚动

## \[v1.1.1\] - 2025-08-13

### ✨ 新增功能

- **双引号输入优化**: 新增 `CapsLock+` 发送双引号 `"` 功能，避免频繁在 CapsLock 与 Shift 间切换

## \[v1.1\] - 2024-12-19

### ✨ 新增功能

- **括号输入优化**: 新增 `CapsLock+[` 发送 `{` 功能，避免频繁在 CapsLock 与 Shift 间切换
- **括号输入优化**: 新增 `CapsLock+]` 发送 `}` 功能，避免频繁在 CapsLock 与 Shift 间切换
- **智能菜单系统**: 优化 `CapsLock+9/0` 逻辑
  - 当第9组菜单为空时，`CapsLock+9` 发送左括号 `(`
  - 当第10组菜单为空时，`CapsLock+0` 发送右括号 `)`
  - 当菜单非空时，正常显示菜单功能

### 🔧 技术改进

- 新增 `IsMenuGroupEmpty()` 函数用于检查菜单组是否为空
- 改进了菜单系统的逻辑判断机制

### 🎯 设计目标

这些更新的主要目的是减少用户在编程和文本编辑时频繁在 CapsLock 和 Shift 键之间切换的需求，提升输入效率。

## \[v1.01\] - 2024-12-19

### 🐛 修复

- **窗口操作错误处理**: 添加了完善的窗口操作错误处理机制
- 修复了在没有激活窗口时可能出现的 "target window not found" 错误
- 为以下函数添加了 try-catch 错误处理：
  - `IsActiveWindowClipped()`
  - `StartDragClippedWindow()`
  - `ShowClipInfo()`
  - `MoveClipRegion()`
  - `ResizeClipRegion()`

### 🔧 技术改进

- 所有窗口相关操作现在会优雅处理错误情况
- 错误处理采用静默模式，不影响用户体验

## \[v1.0\] - 初始版本

### 🚀 主要功能

- **CapsLock 重映射**: 单击发送 Esc，长按激活功能模式
- **vim 风格导航**: hjkl 方向键、单词跳转、行首行尾导航
- **应用启动菜单**: 10组可自定义的应用快速启动菜单
- **窗口管理**: 虚拟桌面、窗口移动、大小调整
- **文本处理**: 选择、复制、粘贴、搜索、翻译
- **鼠标控制**: 精确移动、点击、滚轮操作
- **系统功能**: 音量控制、亮度调整、电源管理
- **特殊功能**: 放大镜、文件重命名、窗口裁剪等

------------------------------------------------------------------------

## 版本说明

- **主版本号**: 重大功能更新或架构变更
- **次版本号**: 新功能添加
- **修订版本号**: 错误修复和小的改进

更多详细信息请参阅 [README.md](README.md)