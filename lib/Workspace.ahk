; =====================================================================
; CapsLock++ 工作区管理模块
; 包含：文件重命名等功能
; =====================================================================

#HotIf GetKeyState("CapsLock", "P") && isToolEnabled

RButton::
{
    global otherKeyPressed := true
    ToggleWindowPinned()
}

LButton::
{
    global otherKeyPressed := true
    local IsRename := false
    
    try {
        activeWin := WinGetID("A")
        activeWinClass := WinGetClass("ahk_id " activeWin)
    } catch {
        activeWin := 0
        activeWinClass := ""
    }
    
    try {
        MouseGetPos(, , &mouseWin)
        mouseWinClass := WinGetClass("ahk_id " mouseWin)
    } catch {
        mouseWin := 0
        mouseWinClass := ""
    }
    
    needActivate := IsExplorerBrowserOwnerCase(activeWinClass, mouseWinClass)
    
    if (needActivate) {
        WinActivate("ahk_id " mouseWin)
        SetTimer(PerformClick, -40)
        return
    }
    
    Click("Left")
    
    SetTimer (LButtonRenamer), -20
}
#HotIf

PerformClick() {
    Click("Left")
    SetTimer(LButtonRenamer, -20)
}

IsExplorerBrowserOwnerCase(activeWinClass, mouseWinClass) {
    if ((activeWinClass = "ExplorerBrowserOwner" && mouseWinClass != "ExplorerBrowserOwner") ||
        (activeWinClass != "ExplorerBrowserOwner" && mouseWinClass = "ExplorerBrowserOwner")) {
        return true
    }
    return false
}

LButtonRenamer(){
    MouseGetPos(, , &mouseWin)
    if (mouseWin) {
        activeClass := WinGetClass("ahk_id " mouseWin)
    } else {
        activeClass := ""
    }
    
    if (activeClass = "CabinetWClass" || activeClass = "ExploreWClass" || 
        activeClass = "Progman" || activeClass = "WorkerW" || activeClass = "ExplorerBrowserOwner") {
        Send("{F2}")
    }
}

RenameFileUnderCursor() {
    Send("{F2}")
}
