# 重构计划：内联式自定义命令

## 目标

将自定义命令功能从独立标签页改为菜单项内联配置，移除命令名称引用机制，直接在菜单项中配置命令字符串和工作目录。

## 数据格式变化

**旧格式：**

```ini
[MenuGroup_系统工具]
action1="RunCustomCommand(\"IP Config\")"

[CustomCommands]
cmd1_name="IP Config"
cmd1_command="cmd /k ipconfig /all"
cmd1_workdir=""
```

**新格式：**

```ini
[MenuGroup_系统工具]
action1="RunCommand(\"cmd /k ipconfig /all\", \"\")"
```

## 实施步骤

### 步骤 1：修改 CapsLock++.ahk - 新增 RunCommand 函数

**位置：** 第 8095 行附近（原 RunCustomCommandByName 函数位置）

**操作：**

1. 删除 `RunCustomCommandByName(cmdName)` 函数（第 8095-8117 行）
2. 新增 `RunCommand(cmdStr, workdir)` 函数：

   * 参数 `cmdStr`：要执行的命令字符串

   * 参数 `workdir`：工作目录（可选，默认为桌面）

   * 使用 `Run()` 执行命令

   * 显示执行结果提示

### 步骤 2：修改 CapsLock++.ahk - 更新 action 解析逻辑

**位置：** 第 5546-5549 行

**操作：**

1. 删除 `RunCustomCommand` 的正则匹配逻辑
2. 新增 `RunCommand` 的正则匹配逻辑：

   * 匹配格式：`RunCommand("命令", "工作目录")`

   * 返回调用 `RunCommand()` 的闭包函数

### 步骤 3：修改 配置助手.ahk - 移除自定义命令标签页

**位置：** 第 36 行

**操作：**
将标签页数组从 `["黑名单窗口", "速记路径", "菜单配置", "进程管理", "网站配置", "自定义命令"]` 改为 `["黑名单窗口", "速记路径", "菜单配置", "进程管理", "网站配置"]`

### 步骤 4：修改 配置助手.ahk - 删除标签页6的构建调用

**位置：** 第 48-49 行

**操作：**
删除以下两行：

```autohotkey
tabs.UseTab(6)
BuildCustomCmdPage(cfgGui)
```

### 步骤 5：修改 配置助手.ahk - 删除相关函数

**操作：**
删除以下函数：

* `BuildCustomCmdPage()` (第 755-766 行)

* `CustomCmdAdd()` (第 768-781 行)

* `OnCustomCmdAddSubmit()` (第 783-788 行)

* `CustomCmdEdit()` (第 790-809 行)

* `OnCustomCmdEditSubmit()` (第 811-814 行)

* `GetCustomCmdNames()` (第 314-320 行)

* `CreateNewCustomCmd()` (第 438-450 行)

* `OnCreateNewCmdSubmit()` (第 452-464 行)

### 步骤 6：修改 配置助手.ahk - 更新 DetectActionType 函数

**位置：** 第 322-328 行

**操作：**
将 `RunCustomCommand` 匹配改为 `RunCommand` 匹配

### 步骤 7：修改 配置助手.ahk - 新增 ExtractRunCommandParams 函数

**位置：** 第 340 行后

**操作：**
新增函数解析 `RunCommand("cmd", "workdir")` 格式

### 步骤 8：修改 配置助手.ahk - 删除 ExtractCustomCmdName 函数

**位置：** 第 330-334 行

**操作：**
删除此函数（不再需要）

### 步骤 9：修改 配置助手.ahk - 重构 MenuAddItem 对话框

**位置：** 第 342-394 行

**操作：**

1. 移除命令选择下拉框 `cmdCb` 和"新建命令"按钮
2. 新增命令输入框 `cmdEdit` 和工作目录输入框 `workdirEdit`
3. 修改 `OnActionTypeChange` 函数：

   * 选择"自定义命令"时显示命令/工作目录输入框

   * 自动生成 `RunCommand("...", "...")` 格式的动作
4. 添加输入框变更事件，实时更新生成的动作

### 步骤 10：修改 配置助手.ahk - 重构 MenuEditItem 对话框

**位置：** 第 477-567 行

**操作：**

1. 移除命令选择下拉框和"新建命令"按钮
2. 新增命令输入框和工作目录输入框
3. 编辑时解析现有 `RunCommand(...)` 并填充到输入框
4. 修改事件绑定逻辑

### 步骤 11：修改 配置助手.ahk - 更新 ConfigReload 函数

**位置：** 第 968-982 行

**操作：**
删除 `[CustomCommands]` 段的加载逻辑

### 步骤 12：修改 配置助手.ahk - 更新 ConfigSave 函数

**位置：** 第 1004-1007 行和第 1140-1147 行

**操作：**

1. 从 `managedSections` Map 中移除 `"CustomCommands"`
2. 删除 `[CustomCommands]` 段的保存逻辑

### 步骤 13：修改 配置助手.ahk - 删除全局变量

**操作：**
删除 `global customCmdLV` 相关声明（如果有）

### 步骤 14：清理 CapsLock++.ini

**操作：**
删除 `[CustomCommands]` 段及其所有内容

## UI 变化

**添加菜单项对话框（选择自定义命令时）：**

```
┌─────────────────────────────────────────┐
│  添加菜单项                        [×]  │
├─────────────────────────────────────────┤
│  名称:     [                    ]       │
│  图标:     [                    ]       │
│  图标类型: [emoji ▼]                    │
│  动作类型: [自定义命令 ▼]               │
│  ─────────────────────────────────────  │
│  命令:     [                        ]   │
│  工作目录: [                        ]   │
│            (可选，默认为桌面)            │
│  ─────────────────────────────────────  │
│  生成的动作:                            │
│  RunCommand("", "")                     │
│                                         │
│         [确定]        [取消]            │
└─────────────────────────────────────────┘
```

## 文件修改清单

| 文件             | 修改类型  | 涉及行数   |
| -------------- | ----- | ------ |
| CapsLock++.ahk | 删除+新增 | \~30行  |
| 配置助手.ahk       | 大量修改  | \~200行 |
| CapsLock++.ini | 删除    | \~15行  |

