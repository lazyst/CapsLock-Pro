# 移除虚拟桌面功能计划

## 目标

完全移除 CapsLock++ 中的虚拟桌面功能及相关代码。

## 影响范围

| 文件 | 涉及代码量 |
|------|-----------|
| CapsLock++.ahk | ~85 处引用 |
| 配置助手.ahk | 黑名单窗口标签页 |
| CapsLock++.ini | 2 个配置段 |
| README.md | 文档说明 |

## 详细实施步骤

### 步骤 1：CapsLock++.ahk - 移除全局变量声明

**位置：** 第 20-21 行附近

**操作：** 删除以下全局变量
```autohotkey
global virtualEnvEnabled := false
global virtualEnvWindows := []
```

### 步骤 2：CapsLock++.ahk - 移除热键绑定

**位置：** 第 465-478 行

**操作：** 删除或修改 `CapsLock + 中键` 热键
- 删除 `SmartVirtualEnvToggle()` 调用
- 删除 `Alt + 中键` 的 `ClearVirtualEnv()` 调用

### 步骤 3：CapsLock++.ahk - 修改 CleanupWorkspaceHotkey 函数

**位置：** 第 575-640 行

**操作：**
1. 移除 `virtualEnvEnabled` 和 `virtualEnvWindows` 引用
2. 移除 `MinimizeNonVirtualEnvWindows()` 调用
3. 简化为仅执行 `MinimizeCursorWindowOrOthers()`

### 步骤 4：CapsLock++.ahk - 移除虚拟环境相关函数

**操作：** 删除以下函数（约 200 行代码）
- `AddToVirtualEnv(hwnd)`
- `RemoveFromVirtualEnv(hwnd)`
- `ClearVirtualEnv()`
- `SmartVirtualEnvToggle()`
- `CleanupVirtualEnvWindows()`
- `MinimizeNonVirtualEnvWindows()`

### 步骤 5：CapsLock++.ahk - 移除其他代码中的虚拟环境引用

**操作：** 搜索并移除所有包含以下内容的代码：
- `virtualEnvEnabled`
- `virtualEnvWindows`
- `virtualEnvHwnds`
- `blacklistProcessNames`（如仅用于虚拟环境）
- `blacklistClasses`（如仅用于虚拟环境）

### 步骤 6：CapsLock++.ahk - 移除全局变量声明（第 2 处）

**位置：** 第 244-245 行附近

**操作：** 删除
```autohotkey
virtualEnvEnabled := false
virtualEnvWindows := []
```

### 步骤 7：配置助手.ahk - 移除黑名单窗口标签页

**操作：**
1. 从标签页数组中移除"黑名单窗口"
2. 删除 `BuildBlacklistPage()` 函数
3. 删除 `ConfigReload()` 中的黑名单加载逻辑
4. 删除 `ConfigSave()` 中的黑名单保存逻辑

### 步骤 8：CapsLock++.ini - 删除配置段

**操作：** 删除以下配置段
```ini
[blacklist_virtual_env]

[blacklist_classes_virtual_env]
```

### 步骤 9：README.md - 删除文档说明

**操作：**
1. 删除"虚拟桌面"相关功能说明
2. 删除黑名单配置说明

## 代码清理检查清单

- [ ] `virtualEnvEnabled` 相关代码
- [ ] `virtualEnvWindows` 相关代码
- [ ] `blacklistProcessNames` 相关代码（如果仅用于虚拟环境）
- [ ] `blacklistClasses` 相关代码（如果仅用于虚拟环境）
- [ ] `AddToVirtualEnv` 函数
- [ ] `RemoveFromVirtualEnv` 函数
- [ ] `ClearVirtualEnv` 函数
- [ ] `SmartVirtualEnvToggle` 函数
- [ ] `CleanupVirtualEnvWindows` 函数
- [ ] `MinimizeNonVirtualEnvWindows` 函数
- [ ] 黑名单窗口标签页 UI
- [ ] 黑名单配置加载/保存

## 风险评估

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| 误删仍在使用的变量 | 中 | 先搜索确认，再分步删除 |
| 影响其他功能 | 低 | 保留 blacklist 相关变量（可能有其他用途） |
| 配置助手标签页索引变化 | 低 | 移除后调整索引 |

## 预期结果

- CapsLock++.ahk 减少约 250 行代码
- 配置助手减少约 80 行代码
- 移除"黑名单窗口"标签页
- 保留工作区清理的基础功能（简化版）
