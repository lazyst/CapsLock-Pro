; =====================================================================
; CapsLock++ 鼠标控制模块
; 包含：鼠标模式入口/退出、鼠标点击、滚轮控制
; 全局变量在 lib/Globals.ahk 中声明
; 工具函数在 lib/Utils.ahk 中声明
; =====================================================================

; =====================================================================
; 鼠标移动函数
; =====================================================================

MouseMoveRelative(x, y) {
    static mouseSpeed := 1

    mouseSpeed += 0.3

    if (mouseSpeed > 6)
        mouseSpeed := 6

    moveX := x * mouseSpeed
    moveY := y * mouseSpeed

    MouseMove(moveX, moveY, 0, "R")
}

; =====================================================================
; 鼠标按键函数
; =====================================================================

MouseLeftDown() {
    Click("Left Down")
}

MouseLeftUp() {
    Click("Left Up")
}

MouseRightDown() {
    Click("Right Down")
}

MouseRightUp() {
    Click("Right Up")
}

MouseWheelUp(repeat := 1) {
    Loop repeat
        Click("WheelUp")
}

MouseWheelDown(repeat := 1) {
    Loop repeat
        Click("WheelDown")
}

; =====================================================================
; 鼠标点击热键
; =====================================================================

CapsLock & RAlt::
{
    global otherKeyPressed := true

    MouseLeftDown()
}

CapsLock & RAlt Up::
{
    MouseLeftUp()
}

CapsLock & RCtrl::
{
    global otherKeyPressed := true

    MouseRightDown()
}

CapsLock & RWin::
{
    global otherKeyPressed := true

    MouseRightDown()
}

CapsLock & RCtrl Up::
{
    MouseRightUp()
}

CapsLock & RWin Up::
{
    MouseRightUp()
}

; =====================================================================
; 鼠标滚轮热键
; =====================================================================

CapsLock & PgUp::
{
    global otherKeyPressed := true

    MouseWheelUp(3)
}

CapsLock & PgDn::
{
    global otherKeyPressed := true

    MouseWheelDown(3)
}

; =====================================================================
; 鼠标模式
; =====================================================================

EnterMouseMode() {
    global mouseModeEnabled, otherKeyPressed

    mouseModeEnabled := true
    otherKeyPressed := true
    ShowTooltipNearMouse("鼠标模式已启用")
}

ExitMouseMode() {
    global mouseModeEnabled

    mouseModeEnabled := false
    ShowTooltipNearMouse("鼠标模式已关闭")
}
; =====================================================================
; 鼠标模式入口热键
; =====================================================================

#HotIf GetKeyState("CapsLock", "P") && isToolEnabled
space::
{
    EnterMouseMode()
}
#HotIf
; =====================================================================
; 鼠标模式热键
; =====================================================================

#HotIf mouseModeEnabled

CapsLock & space::
{
    ExitMouseMode()
}

e::
{
    MouseMoveRelative(0, -7)
}

d::
{
    MouseMoveRelative(0, 7)
}
s::
{
    MouseMoveRelative(-7, 0)
}
f::
{
    MouseMoveRelative(7, 0)
}
w::
{
    Click("Left")
}
r::
{
    Click("Right")
}
j::
{
    Click("WheelDown")
}
k::
{
    Click("WheelUp")
}
h::
{
    Click("WheelLeft")
}
l::
{
    Click("WheelRight")
}
Esc::
{
    ExitMouseMode()
}
#HotIf
