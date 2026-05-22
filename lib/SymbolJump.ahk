; ============================================================================
; SymbolJump.ahk - 符号跳转模块
; ============================================================================
; 实现配对符号跳转功能：当光标位于配对符号旁时，跳转到对应的匹配符号
; 包含：CapsLock+p 热键处理器、SearchInDirection、ReadLineContent、ScanLine、
;        CheckBoundary、ReleaseCapsLock、CheckForInterrupt、
;        isSeekingSymbol 状态下的取消热键
; ============================================================================
; 依赖：
;   lib/Globals.ahk  - isSeekingSymbol, interruptCheckTimer,
;                       initialCapsLockReleased, otherKeyPressed, isToolEnabled
;   lib/CaretPos.ahk - GetCaretPosition()
;   lib/Utils.ahk    - 其他工具函数
; ============================================================================

#HotIf GetKeyState("CapsLock", "P") && isToolEnabled && !isSeekingSymbol
p::
{
    global isSeekingSymbol := true
    global otherKeyPressed := true
    global interruptCheckTimer
    global initialCapsLockReleased := false

    searchStartTime := A_TickCount

    ; 保存当前剪贴板内容
    savedClipboard := ClipboardAll()
    A_Clipboard := ""

    ; 设置中断检查定时器
    interruptCheckTimer := SetTimer(CheckForInterrupt, 20)

    ; 成对符号映射
    SymbolPairs := Map(
        "(", ")", "[", "]", "{", "}", "<", ">",
        "「", "」", "『", "』", "【", "】", "《", "》", "〈", "〉",
        "（", "）", "［", "］", "｛", "｝", "〔", "〕", "〖", "〗",
        "〘", "〙", "〚", "〛", "“", "”", "‘", "’", "‹", "›", "«", "»"
    )

    ReverseSymbolPairs := Map(
        ")", "(", "]", "[", "}", "{", ">", "<",
        "」", "「", "』", "『", "】", "【", "》", "《", "〉", "〈",
        "）", "（", "］", "［", "｝", "｛", "〕", "〔", "〗", "〖",
        "〙", "〘", "〛", "〚", "”", "“", "’", "‘", "›", "‹", "»", "«"
    )

    ; 读取光标右侧字符
    Send("+{Right}")
    Send("^c")
    if !_ClipWait(500) {
        _CleanupAndExit(savedClipboard, "获取字符超时")
        return
    }
    currentChar := A_Clipboard
    A_Clipboard := ""

    ; 检查是否为配对符号
    if (!SymbolPairs.Has(currentChar) && !ReverseSymbolPairs.Has(currentChar)) {
        _CleanupAndExit(savedClipboard, "光标右侧非配对符号")
        Send("{Left}")
        return
    }

    ; 确定搜索方向并执行
    if (SymbolPairs.Has(currentChar)) {
        ; 向前搜索 — 找到配对的闭合符号
        targetChar := SymbolPairs[currentChar]
        Send("{Right}")
        Sleep(30)
        _SearchInDirection("forward", targetChar, currentChar, searchStartTime, savedClipboard)
    } else {
        ; 向后搜索 — 找到配对的开始符号
        targetChar := ReverseSymbolPairs[currentChar]
        _SearchInDirection("backward", targetChar, currentChar, searchStartTime, savedClipboard)
    }
}
#HotIf

; ============================================================================
; _SearchInDirection - 在指定方向搜索匹配符号
; @param dir "forward" 或 "backward"
; ============================================================================
_SearchInDirection(dir, targetChar, currentChar, searchStartTime, savedClipboard) {
    global isSeekingSymbol, interruptCheckTimer

    counter := 1

    ; 三行历史 + 光标位置历史（边界检测用）
    tempLine := ["", "", ""]
    caretPos := [0, 0, 0]

    loop {
        ; 超时检查（10秒）
        if (A_TickCount - searchStartTime > 10000) {
            _CleanupAndExit(savedClipboard, "搜索超时 - 未找到匹配符号")
            return
        }

        ; 中断检查
        if !_CheckInterrupt(savedClipboard)
            return

        ; 记录当前光标位置
        currentCaretPos := GetCaretPosition()

        ; 读取当前行内容（方向相关）
        lineContent := _ReadLineContent(dir)
        if (lineContent = false) {
            _CleanupAndExit(savedClipboard, "获取行内容超时")
            return
        }

        ; 移动位置补偿（方向相关）
        if (dir = "forward") {
            Send("{Left}")
        } else {
            Send("{Right}")
        }
        Sleep(30)

        ; 更新三行历史和光标位置历史
        tempLine[3] := tempLine[2]
        tempLine[2] := tempLine[1]
        tempLine[1] := lineContent

        caretPos[3] := caretPos[2]
        caretPos[2] := caretPos[1]
        caretPos[1] := currentCaretPos

        ; 边界检测 — 连续三次内容和位置未变化说明到文档边界
        if _CheckBoundary(tempLine, caretPos) {
            _CleanupAndExit(savedClipboard, "到达文档边界 - 未找到匹配符号")
            return
        }

        ; 在当前行中扫描符号
        result := _ScanLine(dir, lineContent, targetChar, currentChar, &counter)

        ; ScanLine 中可能触发中断，检查并退出
        if !isSeekingSymbol
            return

        if (result.found) {
            if (interruptCheckTimer)
                SetTimer(interruptCheckTimer, 0)
            A_Clipboard := savedClipboard

            ; 移动到目标位置（方向相关）
            if (dir = "forward") {
                Send("{Right " . result.position . "}")
            } else {
                Send("{Left " . result.position . "}")
            }

            isSeekingSymbol := false
            SetTimer(ReleaseCapsLock, -50)
            return
        }

        ; 移动到下一行（方向相关）
        if (dir = "forward") {
            Send("{End}{Right}")
        } else {
            Send("{Up}{End}")
        }
        Sleep(30)
    }
}

; ============================================================================
; _ReadLineContent - 读取当前行的内容
; @param dir "forward" 读取光标到行尾；"backward" 读取光标到行首
; @return 字符串内容，失败返回 false
; ============================================================================
_ReadLineContent(dir) {
    A_Clipboard := ""

    if (dir = "forward") {
        Send("+{End}+{Right}")
    } else {
        Send("+{Home}+{Left}")
    }
    Send("^c")

    if !_ClipWait(500)
        return false

    return A_Clipboard
}

; ============================================================================
; _ScanLine - 在行内容中扫描配对符号
; @param dir "forward" 从左到右；"backward" 从右到左
; @return {found: bool, position: number}
; ============================================================================
_ScanLine(dir, lineContent, targetChar, currentChar, &counter) {

    if (dir = "forward") {
        ; 从左到右扫描
        loop parse, lineContent {
            if !_CheckInterrupt("")
                return {found: false, position: 0}

            if (A_LoopField = targetChar) {
                counter--
                if (counter = 0)
                    return {found: true, position: A_Index - 1}
            } else if (A_LoopField = currentChar) {
                counter++
            }
        }
    } else {
        ; 从右到左扫描
        lineLength := StrLen(lineContent)
        loop lineLength {
            position := lineLength - A_Index + 1
            tempChar := SubStr(lineContent, position, 1)

            if !_CheckInterrupt("")
                return {found: false, position: 0}

            if (tempChar = targetChar) {
                counter--
                if (counter = 0)
                    return {found: true, position: A_Index - 1}
            } else if (tempChar = currentChar) {
                counter++
            }
        }
    }

    return {found: false, position: 0}
}

; ============================================================================
; _CheckBoundary - 检测是否到达文档边界（三帧内容+位置双重检测）
; @param tempLine [line-3, line-2, line-1]
; @param caretPos [pos-3, pos-2, pos-1]
; @return bool true=到达边界
; ============================================================================
_CheckBoundary(tempLine, caretPos) {
    if (tempLine[1] = "" || tempLine[3] = "")
        return false

    if (tempLine[1] != tempLine[3])
        return false

    if !IsObject(caretPos[1]) || !IsObject(caretPos[3])
        return false

    return (caretPos[1].x = caretPos[3].x && caretPos[1].y = caretPos[3].y)
}

; ============================================================================
; _ClipWait - 带中断检查的剪贴板等待
; @param timeoutMs 超时毫秒
; @return true=有内容 false=超时
; ============================================================================
_ClipWait(timeoutMs) {
    if ClipWait(timeoutMs / 1000, 0)
        return true
    return false
}

; ============================================================================
; _CheckInterrupt - 检查是否需要中断搜索
; @return true=继续 false=已中断
; ============================================================================
_CheckInterrupt(savedClipboard) {
    global isSeekingSymbol, interruptCheckTimer

    if (isSeekingSymbol)
        return true

    if (interruptCheckTimer)
        SetTimer(interruptCheckTimer, 0)

    if (savedClipboard != "")
        A_Clipboard := savedClipboard

    SetTimer(ReleaseCapsLock, -50)
    ToolTip("符号跳转已取消")
    SetTimer(() => ToolTip(), -1000)
    return false
}

; ============================================================================
; _CleanupAndExit - 清理状态并退出
; ============================================================================
_CleanupAndExit(savedClipboard, tipText) {
    global isSeekingSymbol, interruptCheckTimer

    if (interruptCheckTimer)
        SetTimer(interruptCheckTimer, 0)

    A_Clipboard := savedClipboard
    isSeekingSymbol := false

    if (tipText != "") {
        ToolTip(tipText)
        SetTimer(() => ToolTip(), -1500)
    }
}

; ============================================================================
; ReleaseCapsLock - 释放CapsLock键
; ============================================================================
ReleaseCapsLock() {
    SendInput "{CapsLock Up}"
}

; ============================================================================
; CheckForInterrupt - 中断检查定时器回调
; 检查 Escape 按键 和 CapsLock 释放后重按
; ============================================================================
CheckForInterrupt() {
    global isSeekingSymbol, initialCapsLockReleased

    if (GetKeyState("Escape", "P")) {
        isSeekingSymbol := false
        return
    }

    capsLockCurrentState := GetKeyState("CapsLock", "P")

    ; 阶段1: 检测 CapsLock 释放
    if (!initialCapsLockReleased && !capsLockCurrentState) {
        initialCapsLockReleased := true
        return
    }

    ; 阶段2: 检测释放后的再次按下
    if (initialCapsLockReleased && capsLockCurrentState) {
        isSeekingSymbol := false
    }
}

; ============================================================================
; 取消热键 — 在搜索状态下随时中断
; ============================================================================
#HotIf isSeekingSymbol
Escape::
{
    global isSeekingSymbol := false
    return
}

CapsLock::
{
    global isSeekingSymbol := false
    return
}
#HotIf
