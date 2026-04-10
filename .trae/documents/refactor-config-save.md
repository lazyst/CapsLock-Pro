# 重构 ConfigHelper "保存配置" 相关代码

## 问题分析

当前 `ConfigSave()` 函数（[ConfigHelper.ahk:842-989](file:///c:/main/APPS/CapsLock-Pro/lib/ConfigHelper.ahk#L842-L989)）存在以下问题：

### 1. 单体函数过长
整个保存逻辑集中在一个约 150 行的函数中，包含 12 个 section 的序列化、文件写入、配置重载等所有逻辑，难以阅读和维护。

### 2. 字符串拼接模式
使用 `s .= ...` 逐步拼接整个 INI 文件内容，效率低且难以追踪每个 section 的边界。

### 3. 缺乏错误处理
文件写入操作（`FileOpen`/`Write`/`Close`）没有 try-catch 保护，写入失败时用户不会收到任何提示。

### 4. 重复模式
每个 section 的写入遵循相同模式（写 section 头 → 遍历数据 → 写键值对），但代码逐个手写，存在大量重复。

### 5. 关注点混合
数据提取（从 GUI 控件读取）、数据转换（格式化为 INI）、I/O 操作（文件写入）和副作用（重载配置）全部混在一起。

### 6. managedSections 硬编码
管理的 section 名称列表在函数内部硬编码，与实际序列化的 section 不自动同步，容易遗漏。

---

## 重构方案

### 核心思路
将 `ConfigSave()` 拆分为 **数据收集层**、**序列化层**、**文件写入层** 三个阶段，每个 section 的序列化逻辑提取为独立函数。

### 步骤

#### 步骤 1：提取各 section 的序列化函数

将每个 section 的序列化逻辑提取为独立函数，统一签名 `SectionName() => String`：

| 函数名 | 负责的 INI Section |
|--------|-------------------|
| `SerializeNoteTargets()` | `[noteTargets]` |
| `SerializeMenuColourMode()` | `[MenuGroupsColourMode]` |
| `SerializeMenuGroupsEnable()` | `[MenuGroupsEnable]` |
| `SerializeMenuGroupNum()` | `[MenuGroupNum]` |
| `SerializeMenuGroupCount()` | `[MenuGroupCount]` |
| `SerializeMenuGroupName()` | `[MenuGroupName]` |
| `SerializeMenuGroupItems(index)` | `[MenuGroups{i}Items]` |
| `SerializeProcessesToStart()` | `[ProcessesToStart]` |
| `SerializeProcessesToTerminate()` | `[ProcessesToTerminate]` |
| `SerializeCommonWebsites()` | `[CommonWebsites]` |
| `SerializeGUIProcessesToStart()` | `[GUIProcessesToStart]` |
| `SerializeGUIProcessesToTerminate()` | `[GUIProcessesToTerminate]` |

每个函数返回该 section 的完整 INI 文本（含 `[section]` 头和末尾空行）。

#### 步骤 2：提取"保留非管理 section"逻辑为独立函数

将当前代码中读取 INI 文件、过滤出非 managedSections 并保留的逻辑提取为：

```ahk
CollectPreservedSections(managedSections) => String
```

#### 步骤 3：提取文件写入逻辑为独立函数

```ahk
WriteIniContent(filePath, content)
```

包含 try-catch 错误处理和用户提示。

#### 步骤 4：重构 ConfigSave 为主控函数

重构后的 `ConfigSave()` 变为简洁的编排函数：

```ahk
ConfigSave() {
    SyncMenuItemLVToArray()

    sections := [
        SerializeNoteTargets(),
        SerializeMenuColourMode(),
        SerializeMenuGroupsEnable(),
        SerializeMenuGroupNum(),
        SerializeMenuGroupCount(),
        SerializeMenuGroupName()
    ]
    loop 10 {
        sections.Push(SerializeMenuGroupItems(A_Index))
    }
    sections.Push(
        SerializeProcessesToStart(),
        SerializeProcessesToTerminate(),
        SerializeCommonWebsites(),
        SerializeGUIProcessesToStart(),
        SerializeGUIProcessesToTerminate()
    )

    managedSections := BuildManagedSectionsMap()
    preserved := CollectPreservedSections(managedSections)
    if (preserved != "")
        sections.Push(preserved)

    content := ""
    for sec in sections {
        content .= sec
    }

    if (!WriteIniContent(iniFile, content))
        return

    ReloadMenuGroups()
    LoadNoteTargetsFromINI()
    ShowTooltip("配置已保存并重新加载")
}
```

#### 步骤 5：提取 managedSections 构建为函数

```ahk
BuildManagedSectionsMap() => Map
```

使 managedSections 列表与实际序列化的 section 自动对应，避免遗漏。

---

## 涉及文件

- `lib/ConfigHelper.ahk` — 唯一需要修改的文件

## 不变的部分

- `ConfigReload()` 函数保持不变（读取逻辑不在本次重构范围）
- `SyncMenuItemLVToArray()` 保持不变
- `EscapeIniValue()` 保持不变
- 所有 GUI 构建和交互函数保持不变
- INI 文件格式和内容不变，重构后输出完全一致
