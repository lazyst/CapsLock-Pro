# 鼠标模式功能 Spec

## Why
当前 CapsLock+空格 用于选择当前单词/行，但用户希望将其改为进入鼠标模式，以便通过键盘快捷键完全控制鼠标，提高操作效率。

## What Changes
- **BREAKING** `CapsLock+空格` 功能从"选择当前单词/行"改为"进入鼠标模式"
- 新增鼠标模式状态管理
- 新增鼠标模式下的字母键映射

## Impact
- Affected specs: 文本编辑功能、鼠标控制功能
- Affected code: 
  - `lib/Globals.ahk` - 新增鼠标模式状态变量
  - `lib/MouseControl.ahk` - 新增鼠标模式入口/退出函数和热键映射
  - `lib/TextEdit.ahk` - 移除原有 space 热键定义

## Code Structure Design

### 文件组织原则
1. **单一职责**: 鼠标模式相关代码统一放在 `lib/MouseControl.ahk`
2. **复用现有函数**: 鼠标移动、点击、滚轮操作复用 `MouseControl.ahk` 中已有的函数
3. **条件热键**: 使用 `#HotIf mouseModeEnabled` 管理鼠标模式下的热键

### 代码结构
```
lib/Globals.ahk
├── mouseModeEnabled := false    ; 鼠标模式状态

lib/MouseControl.ahk
├── ; === 鼠标模式 ===
├── EnterMouseMode()             ; 进入鼠标模式
├── ExitMouseMode()              ; 退出鼠标模式
├── ToggleMouseMode()            ; 切换鼠标模式
├── ; === 鼠标模式热键 ===
├── #HotIf mouseModeEnabled
│   ├── e/d/s/f                  ; 鼠标移动
│   ├── w/r                      ; 鼠标点击
│   ├── j/k/h/l                  ; 鼠标滚轮
│   └── Esc/CapsLock             ; 退出鼠标模式
└── #HotIf

lib/TextEdit.ahk
├── ; 移除 space 热键定义
```

### 命名规范
- 函数名: `EnterMouseMode`, `ExitMouseMode`, `ToggleMouseMode`
- 变量名: `mouseModeEnabled` (布尔值)
- 注释风格: 与现有代码保持一致，使用 `; === 分隔线 ===` 格式

## ADDED Requirements

### Requirement: 鼠标模式入口
系统应当提供通过 `CapsLock+空格` 进入鼠标模式的功能。

#### Scenario: 进入鼠标模式
- **WHEN** 用户按下 `CapsLock+空格`
- **THEN** 系统进入鼠标模式，显示提示"鼠标模式已启用"

#### Scenario: 退出鼠标模式
- **WHEN** 用户在鼠标模式下按下 `Esc` 或 `CapsLock`
- **THEN** 系统退出鼠标模式，显示提示"鼠标模式已关闭"

### Requirement: 鼠标移动
在鼠标模式下，系统应当提供通过字母键控制鼠标移动的功能。

#### Scenario: 鼠标向上移动
- **WHEN** 用户在鼠标模式下按下 `e` 键
- **THEN** 鼠标指针向上移动

#### Scenario: 鼠标向下移动
- **WHEN** 用户在鼠标模式下按下 `d` 键
- **THEN** 鼠标指针向下移动

#### Scenario: 鼠标向左移动
- **WHEN** 用户在鼠标模式下按下 `s` 键
- **THEN** 鼠标指针向左移动

#### Scenario: 鼠标向右移动
- **WHEN** 用户在鼠标模式下按下 `f` 键
- **THEN** 鼠标指针向右移动

### Requirement: 鼠标点击
在鼠标模式下，系统应当提供通过字母键控制鼠标点击的功能。

#### Scenario: 左键点击
- **WHEN** 用户在鼠标模式下按下 `w` 键
- **THEN** 执行鼠标左键点击

#### Scenario: 右键点击
- **WHEN** 用户在鼠标模式下按下 `r` 键
- **THEN** 执行鼠标右键点击

### Requirement: 鼠标滚轮
在鼠标模式下，系统应当提供通过字母键控制鼠标滚轮的功能。

#### Scenario: 滚轮向下
- **WHEN** 用户在鼠标模式下按下 `j` 键
- **THEN** 鼠标滚轮向下滚动

#### Scenario: 滚轮向上
- **WHEN** 用户在鼠标模式下按下 `k` 键
- **THEN** 鼠标滚轮向上滚动

#### Scenario: 滚轮向左
- **WHEN** 用户在鼠标模式下按下 `h` 键
- **THEN** 鼠标滚轮向左滚动（水平滚动）

#### Scenario: 滚轮向右
- **WHEN** 用户在鼠标模式下按下 `l` 键
- **THEN** 鼠标滚轮向右滚动（水平滚动）

## REMOVED Requirements

### Requirement: 选择当前单词/行
**Reason**: 用户希望将此快捷键改为进入鼠标模式
**Migration**: 原功能可通过其他方式实现（如双击选择单词）
