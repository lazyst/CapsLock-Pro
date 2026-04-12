; ============================================================================
; SymbolJump.ahk - 符号跳转模块
; ============================================================================
; 实现配对符号跳转功能：当光标位于配对符号旁时，跳转到对应的匹配符号
; 包含：CapsLock+p 热键处理器、ReleaseCapsLock、CheckForInterrupt、
;        isSeekingSymbol 状态下的取消热键
; ============================================================================
; 依赖：
;   lib/Globals.ahk  - isSeekingSymbol, interruptCheckTimer,
;                       initialCapsLockReleased, otherKeyPressed, isToolEnabled
;   lib/Utils.ahk    - 工具函数, GetCaretPosition()
; ============================================================================

#HotIf GetKeyState("CapsLock", "P") && isToolEnabled && !isSeekingSymbol
p::
{
    ; 标记为按下了其他键并启动搜索状态
    global isSeekingSymbol := true
    global otherKeyPressed := true
    global interruptCheckTimer
    global initialCapsLockReleased := false  ; 初始设为false，等待释放
    
    ; 搜索超时计时
    searchStartTime := A_TickCount
    
    ; 保存当前剪贴板内容
    savedClipboard := ClipboardAll()
    A_Clipboard := ""
    
    ; 设置初始检查定时器 - 每20ms检查状态
    interruptCheckTimer := SetTimer(CheckForInterrupt, 20)
    
    ; 定义成对符号映射
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
    
    ; 初始化变量
    targetChar := ""
    currentChar := ""
    tempChar := ""
    tempLine_1 := ""
    tempLine_2 := ""
    tempLine_3 := ""  ; 添加第三行记录
    counter := 0
    cursortargetpos := 0

    ; 添加光标位置跟踪变量
    caretPos_1 := {x: 0, y: 0}
    caretPos_2 := {x: 0, y: 0}
    caretPos_3 := {x: 0, y: 0}
    
    ; 获取当前光标位置右侧的字符 - 使用SetTimer代替Sleep
    Send("+{Right}")
    Send("^c")
    startTime := A_TickCount
    
    ; 等待剪贴板内容 - 使用轮询替代Sleep
    while (A_Clipboard = "" && A_TickCount - startTime < 500) {
        if (!isSeekingSymbol) {
            ; 已取消
            if (interruptCheckTimer)
                SetTimer(interruptCheckTimer, 0)
            A_Clipboard := savedClipboard
            SetTimer(ReleaseCapsLock, -50)
            ToolTip("符号跳转已取消")
            SetTimer(() => ToolTip(), -1000)
            return
        }
        Sleep(10)
    }
    
    ; 超时检查
    if (A_Clipboard = "") {
        if (interruptCheckTimer)
            SetTimer(interruptCheckTimer, 0)
        A_Clipboard := savedClipboard
        ToolTip("获取字符超时")
        SetTimer(() => ToolTip(), -1500)
        isSeekingSymbol := false
        return
    }
    
    currentChar := A_Clipboard
    A_Clipboard := ""
    
    ; 检查字符是否是配对符号
    if (!SymbolPairs.Has(currentChar) && !ReverseSymbolPairs.Has(currentChar)) {
        if (interruptCheckTimer)
            SetTimer(interruptCheckTimer, 0)
        ToolTip("光标右侧非配对符号")
        SetTimer(() => ToolTip(), -1500)
        A_Clipboard := savedClipboard
        Send("{Left}")
        isSeekingSymbol := false
        return
    }
    
    ; 向前搜索
    if (SymbolPairs.Has(currentChar)) {
        targetChar := SymbolPairs[currentChar]
        counter := 1
        
        ; 移动到字符右侧
        Send("{Right}")
        Sleep(30)  ; 极短的延迟
        
        ; 开始搜索循环
        loop {
            ; 超时检查
            if (A_TickCount - searchStartTime > 10000) {  ; 10秒超时
                if (interruptCheckTimer)
                    SetTimer(interruptCheckTimer, 0)
                A_Clipboard := savedClipboard
                ToolTip("搜索超时 - 未找到匹配符号")
                SetTimer(() => ToolTip(), -1500)
                isSeekingSymbol := false
                return
            }
            
            ; 取消检查
            if (!isSeekingSymbol) {
                if (interruptCheckTimer)
                    SetTimer(interruptCheckTimer, 0)
                A_Clipboard := savedClipboard
                SetTimer(ReleaseCapsLock, -50)
                ToolTip("符号跳转已取消")
                SetTimer(() => ToolTip(), -1000)
                return
            }
            
            ; 获取当前光标位置
            currentCaretPos := GetCaretPosition()
            
            ; 获取当前光标位置到行尾
            A_Clipboard := ""
            Send("+{End}+{Right}")
            Send("^c")
            
            ; 等待剪贴板内容
            startTime := A_TickCount
            while (A_Clipboard = "" && A_TickCount - startTime < 500) {
                if (!isSeekingSymbol) {
                    if (interruptCheckTimer)
                        SetTimer(interruptCheckTimer, 0)
                    A_Clipboard := savedClipboard
                    SetTimer(ReleaseCapsLock, -50)
                    ToolTip("符号跳转已取消")
                    SetTimer(() => ToolTip(), -1000)
                    return
                }
                Sleep(10)
            }
            
            ; 超时检查
            if (A_Clipboard = "") {
                if (interruptCheckTimer)
                    SetTimer(interruptCheckTimer, 0)
                A_Clipboard := savedClipboard
                ToolTip("获取行内容超时")
                SetTimer(() => ToolTip(), -1500)
                isSeekingSymbol := false
                return
            }
            
            Send("{Left}")
            Sleep(30)
            
            ; 更新三行历史和光标位置历史
            tempLine_3 := tempLine_2
            tempLine_2 := tempLine_1
            tempLine_1 := A_Clipboard
            
            caretPos_3 := caretPos_2
            caretPos_2 := caretPos_1
            caretPos_1 := currentCaretPos
            
            ; 改进的边界检测 - 双重检查内容和光标位置
            if (tempLine_1 = tempLine_3 && tempLine_1 != "" && 
                caretPos_1 && caretPos_3 &&  ; 确保光标位置有效
                caretPos_1.x = caretPos_3.x && caretPos_1.y = caretPos_3.y) {
                
                if (interruptCheckTimer)
                    SetTimer(interruptCheckTimer, 0)
                A_Clipboard := savedClipboard
                ToolTip("到达文档边界 - 未找到匹配符号")
                SetTimer(() => ToolTip(), -1500)
                isSeekingSymbol := false
                return
            }
            
            ; 在当前行中搜索
            loop parse, tempLine_1 {
                tempChar := A_LoopField
                
                ; 取消检查
                if (!isSeekingSymbol) {
                    if (interruptCheckTimer)
                        SetTimer(interruptCheckTimer, 0)
                    A_Clipboard := savedClipboard
                    SetTimer(ReleaseCapsLock, -50)
                    ToolTip("符号跳转已取消")
                    SetTimer(() => ToolTip(), -1000)
                    return
                }
                
                if (tempChar = targetChar) {
                    counter--
                    if (counter = 0) {
                        if (interruptCheckTimer)
                            SetTimer(interruptCheckTimer, 0)
                        cursortargetpos := A_Index - 1
                        A_Clipboard := savedClipboard
                        Send("{Right " . cursortargetpos . "}")
                        ; ToolTip("找到匹配符号")
                        ; SetTimer(() => ToolTip(), -1000)
                        isSeekingSymbol := false
                        SetTimer(ReleaseCapsLock, -50)
                        return
                    }
                } else if (tempChar = currentChar) {
                    counter++
                }
            }
            
            ; 移动到下一行
            Send("{End}{Right}")
            Sleep(30)
        }
    }
    ; 向后搜索
    else if (ReverseSymbolPairs.Has(currentChar)) {
        targetChar := ReverseSymbolPairs[currentChar]
        counter := 1
        
        ; 开始搜索循环
        loop {
            ; 超时检查
            if (A_TickCount - searchStartTime > 10000) {  ; 10秒超时
                if (interruptCheckTimer)
                    SetTimer(interruptCheckTimer, 0)
                A_Clipboard := savedClipboard
                ToolTip("搜索超时 - 未找到匹配符号")
                SetTimer(() => ToolTip(), -1500)
                isSeekingSymbol := false
                return
            }
            
            ; 取消检查
            if (!isSeekingSymbol) {
                if (interruptCheckTimer)
                    SetTimer(interruptCheckTimer, 0)
                A_Clipboard := savedClipboard
                SetTimer(ReleaseCapsLock, -50)
                ToolTip("符号跳转已取消")
                SetTimer(() => ToolTip(), -1000)
                return
            }
            
            ; 获取当前光标位置
            currentCaretPos := GetCaretPosition()
            
            ; 获取当前光标位置到行首
            A_Clipboard := ""
            Send("+{Home}+{Left}")
            Send("^c")
            
            ; 等待剪贴板内容
            startTime := A_TickCount
            while (A_Clipboard = "" && A_TickCount - startTime < 500) {
                if (!isSeekingSymbol) {
                    if (interruptCheckTimer)
                        SetTimer(interruptCheckTimer, 0)
                    A_Clipboard := savedClipboard
                    SetTimer(ReleaseCapsLock, -50)
                    ToolTip("符号跳转已取消")
                    SetTimer(() => ToolTip(), -1000)
                    return
                }
                Sleep(10)
            }
            
            ; 超时检查
            if (A_Clipboard = "") {
                if (interruptCheckTimer)
                    SetTimer(interruptCheckTimer, 0)
                A_Clipboard := savedClipboard
                ToolTip("获取行内容超时")
                SetTimer(() => ToolTip(), -1500)
                isSeekingSymbol := false
                return
            }
            
            Send("{Right}")
            Sleep(30)
            
            ; 更新三行历史和光标位置历史
            tempLine_3 := tempLine_2
            tempLine_2 := tempLine_1
            tempLine_1 := A_Clipboard
            
            caretPos_3 := caretPos_2
            caretPos_2 := caretPos_1
            caretPos_1 := currentCaretPos
            
            ; 改进的边界检测 - 双重检查内容和光标位置
            if (tempLine_1 = tempLine_3 && tempLine_1 != "" && 
                caretPos_1 && caretPos_3 &&  ; 确保光标位置有效
                caretPos_1.x = caretPos_3.x && caretPos_1.y = caretPos_3.y) {
                
                if (interruptCheckTimer)
                    SetTimer(interruptCheckTimer, 0)
                A_Clipboard := savedClipboard
                ToolTip("到达文档边界 - 未找到匹配符号")
                SetTimer(() => ToolTip(), -1500)
                isSeekingSymbol := false
                return
            }
            
            ; 在当前行中从右向左搜索
            lineLength := StrLen(tempLine_1)
            loop lineLength {
                position := lineLength - A_Index + 1
                tempChar := SubStr(tempLine_1, position, 1)
                
                ; 取消检查
                if (!isSeekingSymbol) {
                    if (interruptCheckTimer)
                        SetTimer(interruptCheckTimer, 0)
                    A_Clipboard := savedClipboard
                    SetTimer(ReleaseCapsLock, -50)
                    ToolTip("符号跳转已取消")
                    SetTimer(() => ToolTip(), -1000)
                    return
                }
                
                if (tempChar = targetChar) {
                    counter--
                    if (counter = 0) {
                        if (interruptCheckTimer)
                            SetTimer(interruptCheckTimer, 0)
                        cursortargetpos := A_Index - 1
                        A_Clipboard := savedClipboard
                        Send("{Left " . cursortargetpos . "}")
                        ; ToolTip("找到匹配符号")
                        ; SetTimer(() => ToolTip(), -1000)
                        isSeekingSymbol := false
                        SetTimer(ReleaseCapsLock, -50)
                        return
                    }
                } else if (tempChar = currentChar) {
                    counter++
                }
            }
            
            ; 移动到上一行
            Send("{Up}{End}")
            Sleep(30)
        }
    }
    
    ; 理论上不应该到这里
    if (interruptCheckTimer)
        SetTimer(interruptCheckTimer, 0)
    A_Clipboard := savedClipboard
    isSeekingSymbol := false
    ToolTip("搜索结束但未找到匹配符号")
    SetTimer(() => ToolTip(), -1500)
}
#HotIf

ReleaseCapsLock() {
    SendInput "{CapsLock Up}"
}

CheckForInterrupt() {
    global isSeekingSymbol, initialCapsLockReleased
    
    ; 首先检查Escape - 这个随时可以中断
    if (GetKeyState("Escape", "P")) {
        isSeekingSymbol := false
        return
    }
    
    ; 然后检查CapsLock - 使用两阶段逻辑
    capsLockCurrentState := GetKeyState("CapsLock", "P")
    
    ; 阶段1: 检测CapsLock释放
    if (!initialCapsLockReleased && !capsLockCurrentState) {
        initialCapsLockReleased := true  ; 标记CapsLock已释放
        return
    }
    
    ; 阶段2: 检测在释放后的再次按下
    if (initialCapsLockReleased && capsLockCurrentState) {
        isSeekingSymbol := false  ; 触发中断
        return
    }
}

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
