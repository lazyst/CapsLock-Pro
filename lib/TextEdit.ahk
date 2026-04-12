; =====================================================================
; CapsLock++ 文本编辑增强模块
; 包含：光标移动、文本选择、删除操作、热键映射
; 全局变量在 lib/Globals.ahk 中声明
; 工具函数在 lib/Utils.ahk 中声明
; =====================================================================

; =====================================================================
; 光标移动函数
; =====================================================================

MoveLeft(repeat := 1) {
    Loop repeat
        Send("{Left}")
}

MoveRight(repeat := 1) {
    Loop repeat
        Send("{Right}")
}

MoveUp(repeat := 1) {
    Loop repeat
        Send("{Up}")
}

MoveDown(repeat := 1) {
    Loop repeat
        Send("{Down}")
}

MoveWordLeft(repeat := 1) {
    Loop repeat
        Send("^{Left}")
}

MoveWordRight(repeat := 1) {
    Loop repeat
        Send("^{Right}")
}

MoveHome() {
    Send("{Home}")
}

MoveEnd() {
    Send("{End}")
}

MoveToPageBeginning() {
    Send("^{Home}")
}

MoveToPageEnd() {
    Send("^{End}")
}

; =====================================================================
; 文本选择函数
; =====================================================================

SelectLeft(repeat := 1) {
    Loop repeat
        Send("+{Left}")
}

SelectRight(repeat := 1) {
    Loop repeat
        Send("+{Right}")
}

SelectUp(repeat := 1) {
    Loop repeat
        Send("+{Up}")
}

SelectDown(repeat := 1) {
    Loop repeat
        Send("+{Down}")
}

SelectWordLeft(repeat := 1) {
    Loop repeat
        Send("^+{Left}")
}

SelectWordRight(repeat := 1) {
    Loop repeat
        Send("^+{Right}")
}

SelectHome() {
    Send("+{Home}")
}

SelectEnd() {
    Send("+{End}")
}

SelectToPageBeginning() {
    Send("^+{Home}")
}

SelectToPageEnd() {
    Send("^+{End}")
}

SelectCurrentWord() {
    Send("^{left}+^{right}")
}

SelectCurrentLine() {
    Send("{Home}+{End}")
}

; =====================================================================
; 异步选中单词处理
; =====================================================================

SelectWordTimer()
{
    global pendingOperation, hasExecutedSingleClick

    if (!pendingOperation)
        return

    BlockInput("On")

    originalClip := ClipboardAll()
    A_Clipboard := ""
    Send("^c")
    hasSelection := ClipWait(0.05, 0)
    selectedText := A_Clipboard
    A_Clipboard := originalClip
    originalClip := ""

    if (hasSelection && selectedText != "") {
        pendingOperation := false
        hasExecutedSingleClick := true

        BlockInput("Off")
        return
    }

    if (pendingOperation) {
        SelectCurrentWord()
        pendingOperation := false
        hasExecutedSingleClick := true
    }

    BlockInput("Off")
}

; =====================================================================
; 文本删除函数
; =====================================================================

DeleteLeft(repeat := 1) {
    Loop repeat
        Send("{Backspace}")
}

DeleteRight(repeat := 1) {
    Loop repeat
        Send("{Delete}")
}

DeleteWord() {
    Send("^+{Left}{Delete}")
}

ForwardDeleteWord() {
    Send("^+{Right}{Delete}")
}

DeleteLine() {
    Send("{Home}+{End}{Delete}")
}

DeleteToLineBeginning() {
    Send("+{Home}{Delete}")
}

DeleteToLineEnd() {
    Send("+{End}{Delete}")
}

DeleteToPageBeginning() {
    Send("^+{Home}{Delete}")
}

DeleteToPageEnd() {
    Send("^+{End}{Delete}")
}

DeleteAll() {
    Send("^a{Delete}")
}

EnterWherever() {
    Send("{End}{Enter}")
}

IndexWherever(){
    Send("{Home}{Enter}{Up}")
}

; =====================================================================
; 热键映射 - 光标移动
; =====================================================================

#HotIf GetKeyState("CapsLock", "P") && isToolEnabled
a::
{
    global otherKeyPressed := true

    if (GetKeyState("Alt", "P")) {
        MoveToPageBeginning()
    } else {
        MoveWordLeft()
    }
}

s::
{
    global otherKeyPressed := true

    MoveLeft()
}

d::
{
    global otherKeyPressed := true

    MoveDown()
}

e::
{
    global otherKeyPressed := true

    MoveUp()
}

f::
{
    global otherKeyPressed := true

    MoveRight()
}

g::
{
    global otherKeyPressed := true

    if (GetKeyState("Alt", "P")) {
        MoveToPageEnd()
    } else {
        MoveWordRight()
    }
}

w::
{
    global otherKeyPressed := true

    MoveHome()
}

r::
{
    global otherKeyPressed := true

    MoveEnd()
}
#HotIf

; =====================================================================
; 热键映射 - 文本选择
; =====================================================================

#HotIf GetKeyState("CapsLock", "P") && isToolEnabled
h::
{
    global otherKeyPressed := true

    if (GetKeyState("Alt", "P")) {
        SelectToPageBeginning()
    } else {
        SelectWordLeft()
    }
}

j::
{
    global otherKeyPressed := true

    SelectLeft()
}

k::
{
    global otherKeyPressed := true

    SelectDown()
}

i::
{
    global otherKeyPressed := true

    SelectUp()
}

l::
{
    global otherKeyPressed := true

    SelectRight()
}

`;::
{
    global otherKeyPressed := true

    if (GetKeyState("Alt", "P")) {
        SelectToPageEnd()
    } else {
        SelectWordRight()
    }
}

u::
{
    global otherKeyPressed := true

    SelectHome()
}

o::
{
    global otherKeyPressed := true

    SelectEnd()
}

; =====================================================================
; 热键映射 - 删除操作
; =====================================================================

,::
{
    global otherKeyPressed := true

    DeleteLeft()
}

.::
{
    global otherKeyPressed := true

    DeleteRight()
}

BackSpace::
{
    global otherKeyPressed := true

    DeleteLine()
}

m::
{
    global otherKeyPressed := true

    if (GetKeyState("Alt", "P")) {
        DeleteToPageBeginning()
    } else {
        DeleteToLineBeginning()
    }
}

/::
{
    global otherKeyPressed := true

    if (GetKeyState("Alt", "P")) {
        DeleteToPageEnd()
    } else {
        DeleteToLineEnd()
    }
}

; =====================================================================
; 热键映射 - 特殊操作
; =====================================================================

Enter::
{
    global otherKeyPressed := true

    EnterWherever()
}

RShift::
{
   global otherKeyPressed := true

   IndexWherever()
}

z::
{
    global otherKeyPressed := true

    Send("^z")
}

y::
{
    global otherKeyPressed := true

    Send("^y")
}

x::
{
    global otherKeyPressed := true
    global ClipboardSaved_Independent

    originalClip := ClipboardAll()
    A_Clipboard := ""

    Send("^x")
    if (ClipWait(0.5, 0)) {
        ClipboardSaved_Independent := A_Clipboard
    } else {
        Sleep(50)
        if (A_Clipboard != "") {
            ClipboardSaved_Independent := A_Clipboard
        }
    }

    SetTimer(() => (A_Clipboard := originalClip, originalClip := ""), -100)
}

c::
{
    global otherKeyPressed := true
    global ClipboardSaved_Independent

    originalClip := ClipboardAll()
    A_Clipboard := ""

    Send("^c")
    if (ClipWait(0.5, 0)) {
        ClipboardSaved_Independent := A_Clipboard
    } else {
        Sleep(50)
        if (A_Clipboard != "") {
            ClipboardSaved_Independent := A_Clipboard
        }
    }

    SetTimer(() => (A_Clipboard := originalClip, originalClip := ""), -100)
}

v::
{
    global otherKeyPressed := true
    global ClipboardSaved_Independent

    if (ClipboardSaved_Independent = "") {
        Send("^v")
        return
    }

    originalClip := ClipboardAll()

    A_Clipboard := ""
    ClipWait(0.3, 0)
    A_Clipboard := ClipboardSaved_Independent
    if (!ClipWait(0.3, 0)) {
        ShowTooltipNearMouse("粘贴准备失败")
        A_Clipboard := originalClip
        originalClip := ""
        return
    }

    Send("^v")

    SetTimer(() => (A_Clipboard := originalClip, originalClip := ""), -150)
}

b::
{
    global otherKeyPressed := true

    Send("#{Tab}")
}

#HotIf
