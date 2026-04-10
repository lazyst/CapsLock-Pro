# 将配置助手合并到主项目

## 背景
当前配置助手（`配置助手.ahk`）是一个独立的 AHK 脚本，主脚本通过 `CapsLock+\` 热键以独立进程方式启动它。这导致编译时需要编译两个文件（`CapsLock++.exe` 和 `配置助手.exe`），增加了维护和分发成本。

## 方案
将配置助手的功能合并到主项目中，作为 `lib/ConfigHelper.ahk` 模块。合并后，`CapsLock+\` 热键直接调用 `ShowConfigHelper()` 函数，不再启动独立进程。

## 实施步骤

### Step 1: 创建 `lib/ConfigHelper.ahk`
从 `配置助手.ahk` 提取所有代码，做以下调整：

1. **删除重复函数**：
   - `ReadIniValueUTF8()` — 已在 `lib/Utils.ahk` 中存在，直接复用
   - `ShowTooltip()` — 已在 `lib/Utils.ahk` 中存在，直接复用

2. **保留并迁移的函数**（约 970 行）：
   - `EscapeIniValue()` — INI 值转义，配置助手专用，放入本模块
   - `ShowConfigHelper()` — 主入口函数
   - `BuildMenuPage()` / `BuildNotePage()` / `BuildProcessPage()` / `BuildWebsitePage()` — 四个 Tab 页构建函数
   - 所有菜单组操作函数：`MenuGroupFocus`, `MenuEditGroup`, `MenuToggleGroup`, `MenuGroupMoveUp/Down`
   - 所有菜单项操作函数：`MenuAddItem`, `MenuEditItem`, `MenuDelItem`, `MenuMoveItemUp/Down` 及相关回调
   - 动作类型检测函数：`DetectActionType`, `ExtractRunCommandParams`, `ExtractActivateOrRunParams`
   - 速记目标操作函数：`NoteAdd`, `NoteEdit`, `NoteDel`
   - 进程管理操作函数：`StartProcAdd`, `TermProcAdd`, `GUIStartAdd`, `GUITermAdd` 及相关回调
   - 网站管理操作函数：`WebsiteAdd`
   - 通用 ListView 操作函数：`LVMove`, `LVSelectAll`, `LVDeleteSelected`, `LVDeleteOne`
   - 配置加载/保存函数：`ConfigReload`, `ConfigSave`
   - 文件浏览函数：`BrowseFileProc`

3. **全局变量处理**：
   - `iniFile` — 改为使用 `A_ScriptDir "\CapsLock++.ini"`，在函数内通过 `global iniFile` 引用，或在 Globals.ahk 中声明
   - `currentMenuGroup` — 已在 Globals.ahk 中声明
   - 各种 GUI 控件全局变量（`noteLV`, `menuGroupLV`, `menuItemLV` 等）— 保留为模块级全局变量

4. **移除独立脚本标记**：
   - 删除 `#Requires AutoHotkey v2.0`
   - 删除 `#SingleInstance Force`
   - 删除末尾的 `ShowConfigHelper()` 调用（由热键触发）

5. **移除 `ExitApp()` 调用**：
   - 原配置助手中 `cfgGui.OnEvent("Close", (*) => ExitApp())` 需改为关闭 GUI 窗口即可（`cfgGui.Destroy()`），因为现在是在主脚本内运行，不能退出整个脚本

### Step 2: 修改 `lib/QuickNote.ahk`
将 `CapsLock+\` 热键从启动独立进程改为直接调用 `ShowConfigHelper()`：

```ahk
; 修改前
\::
{
    global otherKeyPressed := true
    if (A_IsCompiled) {
        Run(A_ScriptDir "\配置助手.exe")
    } else {
        Run('"' A_AhkPath '" "' A_ScriptDir '\配置助手.ahk"')
    }
}

; 修改后
\::
{
    global otherKeyPressed := true
    ShowConfigHelper()
}
```

### Step 3: 在 `lib/Globals.ahk` 中添加配置助手需要的全局变量
添加 `iniFile` 全局变量声明。

### Step 4: 在主入口文件 `CapsLock++.ahk` 中添加 `#Include lib\ConfigHelper.ahk`

### Step 5: 删除 `配置助手.ahk` 文件

### Step 6: 验证
- 运行脚本，确认无语法错误
- 按 `CapsLock+\` 打开配置助手 GUI
- 测试配置加载、编辑、保存功能
- 确认保存后主脚本能检测到 `.reload_signal` 并自动重载

## 注意事项
- 配置助手保存配置后会创建 `.reload_signal` 文件，主脚本的 `CheckReloadSignal()` 函数（在 `MenuSystem.ahk` 中）会检测此信号并重载配置。合并后此机制保持不变。
- 配置助手的 GUI 控件全局变量（如 `noteLV`, `menuGroupLV` 等）仅在配置助手内部使用，不需要放入 `Globals.ahk`，保留在 `ConfigHelper.ahk` 模块内即可。
