# Tasks

- [x] Task 1: 添加鼠标模式全局变量
  - [x] 在 `lib/Globals.ahk` 中添加 `mouseModeEnabled := false` 变量
  - [x] 添加注释说明变量用途

- [x] Task 2: 实现鼠标模式核心函数
  - [x] 在 `lib/MouseControl.ahk` 中添加 `EnterMouseMode()` 函数
  - [x] 在 `lib/MouseControl.ahk` 中添加 `ExitMouseMode()` 函数
  - [x] 添加清晰的分隔注释 `; === 鼠标模式 ===`

- [x] Task 3: 修改 TextEdit.ahk 中的 space 热键
  - [x] 移除原有的 space 热键定义（选择单词/行功能）
  - [x] 在 `lib/MouseControl.ahk` 中添加 `CapsLock+空格` 热键调用 `EnterMouseMode()`

- [x] Task 4: 实现鼠标模式下的移动控制热键
  - [x] 使用 `#HotIf mouseModeEnabled` 条件块
  - [x] 添加 `e` 键：调用 `MouseMoveRelative(0, -7)` 向上移动
  - [x] 添加 `d` 键：调用 `MouseMoveRelative(0, 7)` 向下移动
  - [x] 添加 `s` 键：调用 `MouseMoveRelative(-7, 0)` 向左移动
  - [x] 添加 `f` 键：调用 `MouseMoveRelative(7, 0)` 向右移动

- [x] Task 5: 实现鼠标模式下的点击控制热键
  - [x] 添加 `w` 键：调用 `Click("Left")` 左键点击
  - [x] 添加 `r` 键：调用 `Click("Right")` 右键点击

- [x] Task 6: 实现鼠标模式下的滚轮控制热键
  - [x] 添加 `j` 键：调用 `Click("WheelDown")` 滚轮向下
  - [x] 添加 `k` 键：调用 `Click("WheelUp")` 滚轮向上
  - [x] 添加 `h` 键：调用 `Click("WheelLeft")` 滚轮向左
  - [x] 添加 `l` 键：调用 `Click("WheelRight")` 滚轮向右

- [x] Task 7: 实现鼠标模式退出热键
  - [x] 在 `#HotIf mouseModeEnabled` 条件块中添加 `Esc` 键调用 `ExitMouseMode()`
  - [x] 在 `#HotIf mouseModeEnabled` 条件块中添加 `CapsLock` 键调用 `ExitMouseMode()`

- [x] Task 8: 更新 README 文档
  - [x] 在"鼠标模拟功能"章节添加鼠标模式说明
  - [x] 列出所有鼠标模式快捷键

# Task Dependencies
- Task 1 必须先完成
- Task 2 依赖 Task 1
- Task 3 依赖 Task 2
- Task 4, 5, 6, 7 依赖 Task 2，可并行执行
- Task 8 依赖所有其他任务完成
