* [x] lib/ 目录已创建，包含 16 个模块文件

* [x] lib/Globals.ahk 包含所有跨模块共享的全局变量声明，无重复声明

* [x] lib/Utils.ahk 包含所有公共工具函数，函数签名与原始一致

* [x] lib/CapsLockHandler.ahk 包含 CapsLock 键行为处理和初始化逻辑

* [x] lib/WindowSwitch.ahk 包含窗口切换功能和相关热键

* [x] lib/TabSwitch.ahk 包含标签页切换热键

* [x] lib/TextEdit.ahk 包含文本编辑增强函数和 CapsLock+字母键热键

* [x] lib/JumpMode.ahk 包含跳转模式状态机和 InputHook 处理

* [x] lib/MouseControl.ahk 包含鼠标控制函数和方向键热键

* [x] lib/SymbolJump.ahk 包含符号跳转功能和 CapsLock+p 热键

* [x] lib/WindowPin.ahk 包含窗口置顶功能和全屏检测

* [x] lib/Workspace.ahk 包含工作区管理和鼠标按键增强

* [x] lib/QuickNote.ahk 包含速记功能 GUI 和文件操作

* [x] lib/MenuSystem.ahk 包含快捷菜单系统、INI 配置读取和动作执行

* [x] lib/ProcessManage.ahk 包含进程管理 GUI 和操作

* [x] lib/WebsiteManage.ahk 包含网站管理 GUI 和浏览器操作

* [x] lib/WindowClip.ahk 包含窗口裁切工具完整功能

* [x] CapsLock++.ahk 主入口仅包含 #Requires、#SingleInstance、#Include 和初始化调用

* [x] \#Include 加载顺序正确：Globals → Utils → 功能模块

* [x] 脚本可正常运行，无语法错误

* [x] CapsLock 短按发送 Esc 功能正常

* [x] CapsLock+滚轮窗口切换功能正常

* [x] CapsLock+字母键文本编辑功能正常

* [x] CapsLock+方向键鼠标控制功能正常

* [x] CapsLock+数字键快捷菜单功能正常

* [x] CapsLock+n 速记功能正常

* [x] Ctrl+Shift+X 窗口裁切功能正常

* [x] Ctrl+CapsLock 大小写切换功能正常

* [x] 所有热键上下文（#HotIf）在各模块中正确工作

