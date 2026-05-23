; =====================================================================
; CapsLock++ 屏幕底部滚轮调音量
; 鼠标在屏幕底部时，滚动滚轮调整系统音量
; 跟随 CapsLock++ 全局启用/禁用 (isToolEnabled)
; =====================================================================

IsMouseAtScreenBottom() {
    CoordMode("Mouse", "Screen")
    MouseGetPos(, &mouseY)
    return (A_ScreenHeight - mouseY <= 5)
}

#HotIf isToolEnabled && IsMouseAtScreenBottom()
WheelUp::Send("{Volume_Up 1}")
WheelDown::Send("{Volume_Down 1}")
#HotIf
