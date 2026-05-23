; =====================================================================
; CapsLock++ 帮助面板
; 包含：热键速查表 GUI — 展示所有热键及其功能
; 热键：CapsLock + `
; =====================================================================

global helpPanelGui := 0
global helpPanelTimerActive := false

; ---------------------------------------------------------------------
; 热键数据 — 按分类组织
; ---------------------------------------------------------------------
BuildHelpText() {
    categories := [
        {
            name: "基本功能",
            items: [
                {key: "CapsLock (单击, <0.3s)", desc: "发送 Esc"},
                {key: "CapsLock (长按, >=0.3s)", desc: "犹豫操作，无动作"},
                {key: "CapsLock + Esc", desc: "禁用 / 启用 CapsLock++"},
                {key: "Ctrl + CapsLock", desc: "手动切换大写锁定状态"},
                {key: "Ctrl + Alt + I", desc: "显示调试信息"}
            ]
        },
        {
            name: "光标移动",
            items: [
                {key: "CapsLock + E", desc: "上移一行"},
                {key: "CapsLock + D", desc: "下移一行"},
                {key: "CapsLock + S", desc: "左移一个字符"},
                {key: "CapsLock + F", desc: "右移一个字符"},
                {key: "CapsLock + A", desc: "左移一个单词"},
                {key: "CapsLock + G", desc: "右移一个单词"},
                {key: "CapsLock + W", desc: "移动到行首"},
                {key: "CapsLock + R", desc: "移动到行尾"},
                {key: "CapsLock + Alt + A", desc: "移动到文件开头"},
                {key: "CapsLock + Alt + G", desc: "移动到文件末尾"}
            ]
        },
        {
            name: "文本选择",
            items: [
                {key: "CapsLock + H", desc: "向左选择一个单词"},
                {key: "CapsLock + `;", desc: "向右选择一个单词"},
                {key: "CapsLock + J", desc: "向左选择一个字符"},
                {key: "CapsLock + L", desc: "向右选择一个字符"},
                {key: "CapsLock + I", desc: "向上选择一行"},
                {key: "CapsLock + K", desc: "向下选择一行"},
                {key: "CapsLock + U", desc: "选择到行首"},
                {key: "CapsLock + O", desc: "选择到行尾"},
                {key: "CapsLock + Alt + H", desc: "选择到文件开头"},
                {key: "CapsLock + Alt + `;", desc: "选择到文件末尾"}
            ]
        },
        {
            name: "删除操作",
            items: [
                {key: "CapsLock + ,", desc: "向左删除一个字符 (Backspace)"},
                {key: "CapsLock + .", desc: "向右删除一个字符 (Delete)"},
                {key: "CapsLock + M", desc: "删除到行首"},
                {key: "CapsLock + /", desc: "删除到行尾"},
                {key: "CapsLock + Backspace", desc: "删除整行"},
                {key: "CapsLock + Alt + M", desc: "删除到文件开头"},
                {key: "CapsLock + Alt + /", desc: "删除到文件末尾"}
            ]
        },
        {
            name: "编辑操作",
            items: [
                {key: "CapsLock + Z", desc: "撤销"},
                {key: "CapsLock + Y", desc: "重做"},
                {key: "CapsLock + X", desc: "剪切 (独立剪切板)"},
                {key: "CapsLock + C", desc: "复制 (独立剪切板)"},
                {key: "CapsLock + V", desc: "粘贴 (独立剪切板)"},
                {key: "CapsLock + B", desc: "任务视图 (Win+Tab)"},
                {key: "CapsLock + Enter", desc: "行尾插入换行"},
                {key: "CapsLock + RShift", desc: "行首上方插入空行"},
                {key: "CapsLock + [", desc: "输入左花括号 { "},
                {key: "CapsLock + ]", desc: "输入右花括号 } "},
                {key: "CapsLock + '", desc: '输入双引号 " '},
                {key: "CapsLock + 9 (空组)", desc: "输入左圆括号 ( "},
                {key: "CapsLock + 0 (空组)", desc: "输入右圆括号 ) "}
            ]
        },
        {
            name: "窗口管理",
            items: [
                {key: "CapsLock + 右键", desc: "置顶 / 取消置顶窗口"},
                {key: "CapsLock + 左键", desc: "文件重命名 (资源管理器)"},
                {key: "屏幕底部滚轮", desc: "鼠标在底部5px → 调音量"}
            ]
        },
        {
            name: "鼠标模式 (CapsLock+Space 进入)",
            items: [
                {key: "E / D / S / F", desc: "上 / 下 / 左 / 右 移动光标"},
                {key: "Q / A", desc: "提高 / 降低移动速度"},
                {key: "W", desc: "鼠标左键点击"},
                {key: "R", desc: "鼠标右键点击"},
                {key: "J / K", desc: "向下 / 向上 滚轮"},
                {key: "H / L", desc: "向左 / 向右 水平滚轮"},
                {key: "Esc / CapsLock+Space", desc: "退出鼠标模式"}
            ]
        },
        {
            name: "快捷菜单",
            items: [
                {key: "CapsLock + 1 ~ 0", desc: "打开菜单组 1 ~ 10"},
                {key: "菜单内 1 ~ 0", desc: "执行对应菜单项"},
                {key: "菜单内 Esc / 关闭按钮", desc: "关闭菜单"},
                {key: "菜单外点击", desc: "自动关闭菜单"}
            ]
        },
        {
            name: "实用工具",
            items: [
                {key: "CapsLock + Q", desc: "搜索选中文本 / 打开URL / 打开路径"},
                {key: "CapsLock + Tab", desc: "放大镜 开/关"},
                {key: "CapsLock + N", desc: "打开速记窗口"},
                {key: "CapsLock + P", desc: "符号跳转 (配对括号等)"},
                {key: "CapsLock + \", desc: "配置助手"},
                {key: "CapsLock + ``", desc: "帮助面板 (本窗口)"}
            ]
        }
    ]

    ; 列宽：热键 32 字符 + 2 空格分隔 + 描述
    keyWidth := 32
    sep := "  "
    text := ""

    for cat in categories {
        ; 分类标题行
        title := "  " cat.name "  "
        totalPad := 68 - StrLen(title)
        leftPad := totalPad // 2
        rightPad := totalPad - leftPad
        line := ""
        loop leftPad
            line .= "━"
        line .= title
        loop rightPad
            line .= "━"
        text .= "`r`n" line "`r`n`r`n"

        for item in cat.items {
            paddedKey := item.key
            ; 计算实际显示宽度 (中文字符占 2，ASCII 占 1)
            displayWidth := 0
            loop parse, paddedKey {
                charCode := Ord(A_LoopField)
                if (charCode > 127)
                    displayWidth += 2
                else
                    displayWidth += 1
            }
            ; 补齐到 keyWidth 显示宽度
            needPad := keyWidth - displayWidth
            while needPad > 0 {
                paddedKey .= " "
                needPad--
            }
            text .= "  " paddedKey sep item.desc "`r`n"
        }
    }

    ; 底部提示
    text .= "`r`n" . _RepeatStr("━", 68) . "`r`n"
    text .= "  提示: 按 Esc 或点击外部区域关闭  |  再次按 CapsLock + `` 关闭`r`n"

    return text
}

_RepeatStr(str, count) {
    result := ""
    loop count
        result .= str
    return result
}

; ---------------------------------------------------------------------
; ShowHelpPanel — 显示帮助面板
; ---------------------------------------------------------------------
ShowHelpPanel() {
    global helpPanelGui, helpPanelTimerActive, otherKeyPressed

    ; 已打开则关闭 (toggle)
    if (helpPanelGui != 0 && WinExist("ahk_id " helpPanelGui)) {
        CloseHelpPanel()
        return
    }

    otherKeyPressed := true

    helpText := BuildHelpText()

    ; 创建窗口（无标题栏，始终置顶，参考 MenuUI 风格）
    panelGui := Gui("-Caption +AlwaysOnTop +ToolWindow +Owner +E0x02000000")
    panelGui.BackColor := "0xFFFFFF"
    panelGui.SetFont("s10", "Consolas")
    panelGui.OnEvent("Escape", (*) => CloseHelpPanel())
    panelGui.OnEvent("Close", (*) => CloseHelpPanel())

    ; 标题栏
    titleBar := panelGui.Add("Text", "x0 y0 w520 h36 Center +0x200")
    titleBar.SetFont("s12 bold c0x1A1A1A", "Segoe UI")
    titleBar.Value := "CapsLock++ 热键速查"

    ; 可滚动只读编辑框
    panelEdit := panelGui.Add("Edit", "x10 y42 w500 h410 +ReadOnly +VScroll -WantReturn", helpText)

    ; 关闭按钮
    closeBtn := panelGui.Add("Button", "x195 y460 w130 h32 -TabStop", "关闭 (Esc)")
    closeBtn.SetFont("s10 c0x1A1A1A", "Segoe UI")
    closeBtn.OnEvent("Click", (*) => CloseHelpPanel())

    ; 居中显示
    panelWidth := 520
    panelHeight := 500
    panelGui.Show("x" (A_ScreenWidth / 2 - panelWidth / 2)
        . " y" (A_ScreenHeight / 2 - panelHeight / 2)
        . " w" panelWidth " h" panelHeight)
    helpPanelGui := panelGui.Hwnd

    ; 取消 Edit 控件的默认全选
    SendMessage(0x00B1, -1, 0, panelEdit.Hwnd)

    EnableRoundedCorners(helpPanelGui)
    EnableWindowShadow(helpPanelGui)
    FadeInWindow(helpPanelGui)

    ; 点击外部自动关闭
    SetTimer(CheckHelpPanelActive, 50)
    helpPanelTimerActive := true
}

; ---------------------------------------------------------------------
; CheckHelpPanelActive — 检测是否点击了外部
; ---------------------------------------------------------------------
CheckHelpPanelActive() {
    global helpPanelGui, helpPanelTimerActive
    if (!helpPanelGui || !WinExist("ahk_id " helpPanelGui)) {
        SetTimer(CheckHelpPanelActive, 0)
        helpPanelTimerActive := false
        return
    }
    try {
        activeWin := WinGetID("A")
        if (activeWin != helpPanelGui) {
            CloseHelpPanel()
        }
    }
}

; ---------------------------------------------------------------------
; CloseHelpPanel — 关闭帮助面板
; ---------------------------------------------------------------------
CloseHelpPanel() {
    global helpPanelGui, helpPanelTimerActive

    if (helpPanelTimerActive) {
        SetTimer(CheckHelpPanelActive, 0)
        helpPanelTimerActive := false
    }

    try {
        if (helpPanelGui != 0 && WinExist("ahk_id " helpPanelGui)) {
            FadeOutWindow(helpPanelGui)
            WinClose("ahk_id " helpPanelGui)
        }
    } catch {
    }
    helpPanelGui := 0
}
