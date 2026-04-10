; =====================================================================
; CapsLock++ 标签页切换模块
; 使用中键+滚轮在应用程序内切换标签页
; =====================================================================

#HotIf GetKeyState("MButton", "P")
WheelDown::
{
    global otherKeyPressed := true

    SendInput("^{Tab}")
}

WheelUp::
{
    global otherKeyPressed := true

    SendInput("^+{Tab}")
}
#HotIf
