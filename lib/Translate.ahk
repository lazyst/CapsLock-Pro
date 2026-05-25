; =====================================================================
; CapsLock++ 翻译助手
; CapsLock+T 以 Edge 新窗口打开翻译页面（独立窗口，登录态隔离）
; =====================================================================

ShowTranslateWindow() {
    global otherKeyPressed

    otherKeyPressed := true

    url := "https://chat.baidu.com/?enter_type=chat_url"

    ; 关闭已有的翻译窗口（避免重复打开）
    if (WinExist("ahk_exe msedge.exe")) {
        allWindows := WinGetList("ahk_exe msedge.exe")
        for hwnd in allWindows {
            title := WinGetTitle("ahk_id " hwnd)
            if (InStr(title, "百度AI"))
                WinClose("ahk_id " hwnd)
        }
    }

    ; 使用独立临时目录隔离登录态，每次全新会话
    tempDir := A_Temp "\CapsLock_Translate"
    try DirDelete(tempDir, 1)
    DirCreate(tempDir)

    winW := 1400
    winH := 920
    posX := A_ScreenWidth//2 - winW//2
    posY := A_ScreenHeight//2 - winH//2

    ; 记录启动前已有的 Edge 窗口，以便识别新窗口
    existingHwnds := Map()
    try {
        for hwnd in WinGetList("ahk_exe msedge.exe")
            existingHwnds[hwnd] := true
    }

    Run('msedge.exe'
        . ' --window-position=' posX ',' posY
        . ' --window-size=' winW ',' winH
        . ' --new-window "' url '"'
        . ' --user-data-dir="' tempDir '"'
        . ' --no-first-run --no-default-browser-check'
        . ' --disable-sync --disable-signin-promo')

    ; 等待新窗口出现后强制居中
    try {
        loop 30 {
            Sleep(300)
            for hwnd in WinGetList("ahk_exe msedge.exe") {
                if (!existingHwnds.Has(hwnd)) {
                    Sleep(600)
                    WinMove(posX, posY, winW, winH, "ahk_id " hwnd)
                    Sleep(400)
                    WinMove(posX, posY, winW, winH, "ahk_id " hwnd)
                    return
                }
            }
        }
    }
}
