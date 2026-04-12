; =====================================================================
; CapsLock++ 鼠标控制模块
; 包含：鼠标模式入口/退出、鼠标移动、点击、滚轮控制
; 全局变量在 lib/Globals.ahk 中声明
; 工具函数在 lib/Utils.ahk 中声明
; =====================================================================

; =====================================================================
; 鼠标移动函数
; =====================================================================

StartMouseMove() {
    global mouseMoveTimer

    if (mouseMoveTimer = 0) {
        SetTimer(MouseMoveLoop, 10)
        mouseMoveTimer := 1
    }
}

StopMouseMove() {
    global mouseMoveTimer

    if (mouseMoveTimer != 0) {
        if GetKeyState("e", "P") || GetKeyState("d", "P") || GetKeyState("s", "P") || GetKeyState("f", "P")
            return

        SetTimer(MouseMoveLoop, 0)
        mouseMoveTimer := 0
    }
}

MouseMoveLoop() {
    global mouseSpeed

    dx := 0
    dy := 0

    if GetKeyState("e", "P")
        dy -= 1
    if GetKeyState("d", "P")
        dy += 1
    if GetKeyState("s", "P")
        dx -= 1
    if GetKeyState("f", "P")
        dx += 1

    if (dx != 0 || dy != 0) {
        if (dx != 0 && dy != 0) {
            length := Sqrt(dx * dx + dy * dy)
            dx := dx / length
            dy := dy / length
        }

        MouseMove(dx * mouseSpeed, dy * mouseSpeed, 0, "R")
    }
}

; =====================================================================
; 速度调节函数
; =====================================================================

AdjustMouseSpeed(delta) {
    global mouseSpeed

    mouseSpeed += delta

    if (mouseSpeed < 1)
        mouseSpeed := 1
    if (mouseSpeed > 20)
        mouseSpeed := 20

    SaveMouseSpeed()
    ShowTooltipNearMouse("鼠标速度: " . mouseSpeed)
}

SaveMouseSpeed() {
    global mouseSpeed, iniFile

    IniWrite(mouseSpeed, iniFile, "MouseMode", "Speed")
}

; =====================================================================
; 鼠标滚轮函数
; =====================================================================

StartMouseWheel(direction) {
    global mouseWheelTimer, mouseWheelDirection

    mouseWheelDirection := direction
    if (mouseWheelTimer = 0) {
        SetTimer(MouseWheelLoop, 50)
        mouseWheelTimer := 1
    }
}

StopMouseWheel() {
    global mouseWheelTimer

    if (mouseWheelTimer != 0) {
        if GetKeyState("j", "P") || GetKeyState("k", "P") || GetKeyState("h", "P") || GetKeyState("l", "P")
            return

        SetTimer(MouseWheelLoop, 0)
        mouseWheelTimer := 0
    }
}

MouseWheelLoop() {
    global mouseWheelDirection

    Click(mouseWheelDirection)
}

; =====================================================================
; 鼠标模式
; =====================================================================

EnterMouseMode() {
    global mouseModeEnabled, otherKeyPressed, mouseSpeed

    mouseModeEnabled := true
    otherKeyPressed := true
    ShowTooltipNearMouse("鼠标模式已启用 (速度: " . mouseSpeed . ")")
}

ExitMouseMode() {
    global mouseModeEnabled, otherKeyPressed

    mouseModeEnabled := false
    otherKeyPressed := true
    StopMouseMove()
    StopMouseWheel()
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
    StartMouseMove()
}

e Up::
{
    StopMouseMove()
}

d::
{
    StartMouseMove()
}

d Up::
{
    StopMouseMove()
}

s::
{
    StartMouseMove()
}

s Up::
{
    StopMouseMove()
}

f::
{
    StartMouseMove()
}

f Up::
{
    StopMouseMove()
}

q::
{
    AdjustMouseSpeed(1)
}

a::
{
    AdjustMouseSpeed(-1)
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
    StartMouseWheel("WheelDown")
}

j Up::
{
    StopMouseWheel()
}

k::
{
    StartMouseWheel("WheelUp")
}

k Up::
{
    StopMouseWheel()
}

h::
{
    StartMouseWheel("WheelLeft")
}

h Up::
{
    StopMouseWheel()
}

l::
{
    StartMouseWheel("WheelRight")
}

l Up::
{
    StopMouseWheel()
}

Esc::
{
    ExitMouseMode()
}

#HotIf