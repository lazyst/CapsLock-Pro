; =====================================================================
; CapsLock++ 鼠标控制模块
; 包含：鼠标移动、点击、速度调整、热键映射
; 全局变量在 lib/Globals.ahk 中声明
; 工具函数在 lib/Utils.ahk 中声明
; =====================================================================

; =====================================================================
; 初始化
; =====================================================================

InitCapsLockPlusModule() {
    try {
        RegRead(&mouseOriginalSpeed, "HKCU\Control Panel\Mouse", "MouseSensitivity")
    } catch {
        mouseOriginalSpeed := 10
    }
}

; =====================================================================
; 鼠标速度临时调整功能
; =====================================================================

AdjustMouseSpeed() {
    global mouseSpeedValue, mouseOriginalSpeed

    try {
        RegRead(&mouseOriginalSpeed, "HKCU\Control Panel\Mouse", "MouseSensitivity")
    } catch {
        mouseOriginalSpeed := 10
    }

    try {
        speedToSet := Integer(mouseSpeedValue)

        RegWrite(speedToSet, "REG_SZ", "HKCU\Control Panel\Mouse", "MouseSensitivity")

        DllCall("SystemParametersInfo", "UInt", 0x71, "UInt", 0, "UInt", speedToSet, "UInt", 0)
    } catch as e {
        ShowTooltip("设置鼠标速度失败: " e.Message)
    }

    KeyWait("LAlt")

    try {
        originalSpeed := Integer(mouseOriginalSpeed)

        RegWrite(originalSpeed, "REG_SZ", "HKCU\Control Panel\Mouse", "MouseSensitivity")

        DllCall("SystemParametersInfo", "UInt", 0x71, "UInt", 0, "UInt", originalSpeed, "UInt", 0)
    } catch as e {
        ShowTooltip("恢复鼠标速度失败: " e.Message)
    }
}

; =====================================================================
; 鼠标移动函数
; =====================================================================

MouseMoveRelative(x, y) {
    static mouseSpeed := 1
    global mousePrecisionMode, mousePrecisionFactor

    mouseSpeed += 0.3

    if (mouseSpeed > 6)
        mouseSpeed := 6

    moveX := x * mouseSpeed
    moveY := y * mouseSpeed

    if (mousePrecisionMode) {
        moveX := moveX * mousePrecisionFactor
        moveY := moveY * mousePrecisionFactor
    }

    MouseMove(moveX, moveY, 0, "R")
}

ResetMouseSpeed() {
    static mouseSpeed := 1
    mouseSpeed := 1
}

CalculateMovementVector() {
    global mouseKeysPressed

    moveX := 0
    moveY := 0

    if (mouseKeysPressed.Has("Up") && mouseKeysPressed["Up"])
        moveY -= 7
    if (mouseKeysPressed.Has("Down") && mouseKeysPressed["Down"])
        moveY += 7
    if (mouseKeysPressed.Has("Left") && mouseKeysPressed["Left"])
        moveX -= 7
    if (mouseKeysPressed.Has("Right") && mouseKeysPressed["Right"])
        moveX += 7

    return {x: moveX, y: moveY}
}

StartContinuousMouseMovement() {
    global mouseMovementActive, mouseMovementTimer

    if (mouseMovementActive)
        return

    mouseMovementActive := true

    mouseMovementTimer := SetTimer(ContinuousMouseMove, 16)
}

StopContinuousMouseMovement() {
    global mouseMovementActive, mouseMovementTimer, mouseKeysPressed

    if (!mouseMovementActive)
        return

    if (mouseMovementTimer)
        SetTimer(mouseMovementTimer, 0)

    mouseMovementActive := false
    mouseMovementTimer := 0

    ResetMouseSpeed()
}

ContinuousMouseMove() {
    global mouseKeysPressed

    movement := CalculateMovementVector()

    if (movement.x == 0 && movement.y == 0) {
        StopContinuousMouseMovement()
        return
    }

    MouseMoveRelative(movement.x, movement.y)
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
; 鼠标控制热键 - 方向键移动
; =====================================================================

CapsLock & Up::
{
    global otherKeyPressed := true
    global mousePrecisionMode := GetKeyState("LAlt", "P")
    global mouseKeysPressed

    mouseKeysPressed["Up"] := true

    StartContinuousMouseMovement()
}

CapsLock & Up Up::
{
    global mouseKeysPressed
    mouseKeysPressed["Up"] := false
}

CapsLock & Down::
{
    global otherKeyPressed := true
    global mousePrecisionMode := GetKeyState("LAlt", "P")
    global mouseKeysPressed

    mouseKeysPressed["Down"] := true

    StartContinuousMouseMovement()
}

CapsLock & Down Up::
{
    global mouseKeysPressed
    mouseKeysPressed["Down"] := false
}

CapsLock & Left::
{
    global otherKeyPressed := true
    global mousePrecisionMode := GetKeyState("LAlt", "P")
    global mouseKeysPressed

    mouseKeysPressed["Left"] := true

    StartContinuousMouseMovement()
}

CapsLock & Left Up::
{
    global mouseKeysPressed
    mouseKeysPressed["Left"] := false
}

CapsLock & Right::
{
    global otherKeyPressed := true
    global mousePrecisionMode := GetKeyState("LAlt", "P")
    global mouseKeysPressed

    mouseKeysPressed["Right"] := true

    StartContinuousMouseMovement()
}

CapsLock & Right Up::
{
    global mouseKeysPressed
    mouseKeysPressed["Right"] := false
}

; =====================================================================
; 精确移动模式切换
; =====================================================================

!CapsLock::
{
    global otherKeyPressed := true
    global mousePrecisionMode := !mousePrecisionMode
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
; 鼠标速度调整热键
; =====================================================================

CapsLock & LAlt::
{
    global otherKeyPressed := true

    AdjustMouseSpeed()
}
