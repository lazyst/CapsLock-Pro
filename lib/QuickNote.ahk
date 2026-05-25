; =====================================================================
; CapsLock++ 速记与杂项热键模块
; 包含：速记功能、放大镜、空置键、配置助手、双引号、括号等
; =====================================================================

; 放大镜功能(调用win11原生放大镜)
#HotIf GetKeyState("CapsLock", "P") && isToolEnabled
Tab::
{
    global otherKeyPressed := true

    if (WinExist("ahk_class MagUIClass")) {
        WinClose("ahk_class MagUIClass")
        ShowTooltipNearMouse("放大镜已关闭")
    } else {
        Send("#=")
        ShowTooltipNearMouse("放大镜已开启")

        SetTimer(MinimizeMagnifierWindow, -1000)
    }
}
#HotIf

MinimizeMagnifierWindow() {
    if (WinExist("ahk_class MagUIClass")) {
        WinMinimize("ahk_class MagUIClass")
        ShowTooltipNearMouse("放大镜控制窗口已最小化")
    }
}

#HotIf GetKeyState("CapsLock", "P") && isToolEnabled

-::
{
    global otherKeyPressed := true

    Send("")
}

=::
{
    global otherKeyPressed := true

    Send("")
}

\::
{
    global otherKeyPressed := true
    ShowConfigHelper()
}

'::
{
    global otherKeyPressed := true

    SendText("`"")
}

[::
{
    global otherKeyPressed := true

    SendText("{")
}

]::
{
    global otherKeyPressed := true

    SendText("}")
}

q::
{
    global otherKeyPressed := true

    QuickSearch()
}

t::
{
    global otherKeyPressed := true

    ShowTranslateWindow()
}

SC029::
{
    global otherKeyPressed := true

    ShowHelpPanel()
}
#HotIf

;=====================================================================
; 速记功能
;=====================================================================

GetDesktopPath() {
    try {
        desktopPath := EnvGet("USERPROFILE") . "\Desktop\"
        if (FileExist(desktopPath))
            return desktopPath
    } catch {
    }

    try {
        desktopPath := A_Desktop . "\"
        if (FileExist(desktopPath))
            return desktopPath
    } catch {
    }

    return "C:\Users\" . A_UserName . "\Desktop\"
}

LoadNoteTargetsFromINI() {
    global noteTargets, iniFile

    noteTargets := Map()

    i := 1
    loop {
        try {
            keyword := ReadIniValueUTF8(iniFile, "noteTargets", "note" i "1", "")
            if (keyword = "")
                break
            path := ReadIniValueUTF8(iniFile, "noteTargets", "note" i "2", "")

            if (keyword != "" && path != "") {
                if (!RegExMatch(path, "^[A-Za-z]:\\")) {
                    path := GetDesktopPath() . path
                }

                noteTargets[keyword] := path
            }
            i++
        } catch Error {
            break
        }
    }

    if (noteTargets.Count = 0) {
        noteTargets := Map(
            "论文", A_ScriptDir . "\速记\论文灵感.txt",
            "日记", A_ScriptDir . "\速记\日记.txt",
            "工作", A_ScriptDir . "\速记\工作.txt",
            "想法", A_ScriptDir . "\速记\想法.txt"
        )
    }
}

EnsureNoteDirectories() {
    global noteConfig, noteTargets

    noteDir := A_ScriptDir . "\速记\"
    if (!FileExist(noteDir)) {
        try {
            DirCreate(noteDir)
        } catch as e {
            ToolTip("创建速记主目录失败: " . e.Message)
            SetTimer () => ToolTip(), -3000
            return false
        }
    }

    if (!FileExist(noteConfig.defaultDir)) {
        try {
            DirCreate(noteConfig.defaultDir)
        } catch as e {
            ToolTip("创建速记默认目录失败: " . e.Message)
            SetTimer () => ToolTip(), -3000
            return false
        }
    }

    for targetName, filePath in noteTargets {
        SplitPath(filePath, , &fileDir)

        if (fileDir && !FileExist(fileDir)) {
            try {
                DirCreate(fileDir)
            } catch as e {
                ToolTip("创建目标文件目录失败: " . e.Message)
                SetTimer () => ToolTip(), -3000
            }
        }
    }

    return true
}

LoadNoteTargetsFromINI()

EnsureNoteDirectories()

#HotIf GetKeyState("CapsLock", "P") && isToolEnabled
n::
{
    global otherKeyPressed := true

    ShowQuickNote()
}

NoteFileClick(*) {
    global noteEdit, noteViewMode, currentEditingFile, statusBar, noteListView, searchEdit, searchLabel, noteGui,
        newNoteBtn

    selectedRow := noteListView.GetNext()
    if (!selectedRow)
        return

    filePath := noteListView.GetText(selectedRow, 4)

    if (!filePath)
        return

    if (FileExist(filePath)) {
        try {
            content := FileRead(filePath, "UTF-8")
        } catch {
            content := FileRead(filePath)
        }

        noteEdit.Value := content

        currentEditingFile := filePath

        noteViewMode := false
        noteEdit.Opt("-ReadOnly")
        noteEdit.Visible := true
        noteListView.Visible := false
        searchEdit.Visible := false
        searchLabel.Visible := false
        deleteBtn.Visible := false
        newNoteBtn.Visible := true
        viewToggleBtn.Text := "查看速记"

        statusBar.SetText("提示: 正在编辑 | Ctrl+S保存 | 新建速记按钮可写新内容")

        noteGui.Show()
        WinWaitActive("速记")
        ControlFocus("Edit1", "速记")
    }
}

ShowQuickNote() {
    static isNoteGuiOpen := false

    if (isNoteGuiOpen)
        return

    isNoteGuiOpen := true

    global noteGui := Gui("+AlwaysOnTop +Resize", "速记")

    iconPath := A_ScriptDir . "\Icon\QuickNote.ico"
    if (FileExist(iconPath)) {
        hIcon := DllCall("LoadImage", "Ptr", 0, "Str", iconPath, "UInt", 1, "Int", 0, "Int", 0, "UInt", 0x10, "Ptr")
        if (hIcon) {
            DllCall("SendMessage", "Ptr", noteGui.Hwnd, "UInt", 0x80, "Ptr", 1, "Ptr", hIcon)
            DllCall("SendMessage", "Ptr", noteGui.Hwnd, "UInt", 0x80, "Ptr", 0, "Ptr", hIcon)
        }
    }

    global noteEdit := noteGui.Add("Edit", "x10 y40 r10 w500 WantTab +VScroll", "## ")

    global statusBar := noteGui.Add("StatusBar", "", "提示: 输入标题或删除## | 最后一行使用==目标==指定保存位置 | Ctrl+S保存")

    global viewToggleBtn := noteGui.Add("Button", "x10 y10 w80 h25", "查看速记")
    global searchLabel := noteGui.Add("Text", "x+10 y15 w50", "搜索:")
    global searchEdit := noteGui.Add("Edit", "x+5 y10 w150 h25 vNoteSearch +Hidden", "")

    global noteListView := noteGui.Add("ListView", "x10 y40 w480 h200 +ReadOnly +AltSubmit +Hidden", ["文件名", "修改时间",
        "目标", "路径"])
    noteListView.OnEvent("DoubleClick", NoteFileClick)

    buttonBar := noteGui.Add("Text", "w500 h30 Section", "")
    saveBtn := noteGui.Add("Button", "xp y+5 w80 h25 Default", "保存")
    global newNoteBtn := noteGui.Add("Button", "x+10 yp w80 h25", "新建速记")
    cancelBtn := noteGui.Add("Button", "x+10 yp w80 h25", "取消")
    global deleteBtn := noteGui.Add("Button", "x+10 yp w80 h25 +Hidden", "删除选中")
    deleteBtn.OnEvent("Click", DeleteSelectedNote)

    saveBtn.OnEvent("Click", SaveNoteHandler)
    newNoteBtn.OnEvent("Click", NewNoteHandler)
    cancelBtn.OnEvent("Click", CloseNoteGui)
    viewToggleBtn.OnEvent("Click", ToggleNoteViewHandler)
    searchEdit.OnEvent("Change", NoteSearchHandler)

    noteGui.OnEvent("Close", CloseNoteGui)
    noteGui.OnEvent("Escape", CloseNoteGui)

    CloseNoteGui(*) {
        global currentEditingFile
        isNoteGuiOpen := false
        currentEditingFile := ""
        noteGui.Destroy()
    }

    GuiResize(thisGui, minMax, width, height) {
        if (minMax = -1)
            return

        noteEdit.Move(10, 40, width - 20, height - 110)
        noteListView.Move(10, 40, width - 20, height - 110)

        buttonBar.Move(10, height - 60, width - 20)
        saveBtn.Move(10, height - 55)
        newNoteBtn.Move(100, height - 55)
        cancelBtn.Move(190, height - 55)
        deleteBtn.Move(280, height - 55)
    }

    noteGui.OnEvent("Size", GuiResize)

    noteGui.Show("w500 h400")
    WinWaitActive("速记")
    ControlFocus("Edit1", "速记")

    SendInput("{End}")

    HotIfWinActive("速记")
    Hotkey("^s", (*) => SaveNoteHandler())
    HotIf()

    NewNoteHandler(*) {
        global currentEditingFile
        currentEditingFile := ""
        noteEdit.Value := "## "
        statusBar.SetText("提示: 输入标题或删除## | 最后一行使用==目标==指定保存位置 | Ctrl+S保存")
        ControlFocus(noteEdit)
    }

    SaveNoteHandler(*) {
        global currentEditingFile

        content := noteEdit.Value

        if (content = "") {
            MsgBox("笔记内容为空，未保存", "速记", "Icon!")
            return
        }

        if (currentEditingFile != "" && FileExist(currentEditingFile)) {
            try {
                timeStamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
                content := RegExReplace(content, "^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]", "[" . timeStamp . "]", , 1
                )

                FileDelete(currentEditingFile)
                FileAppend(content, currentEditingFile)

                ToolTip("已保存到「" . currentEditingFile . "」")
                SetTimer () => ToolTip(), -2000

                ControlFocus(noteEdit)
                return
            } catch as e {
                MsgBox("保存失败: " . e.Message, "速记", "Icon!")
                return
            }
        }

        currentEditingFile := ""

        lines := StrSplit(content, "`n")
        title := ""
        targetName := ""
        targetFile := ""

        if (lines.Length > 0 && RegExMatch(lines[1], "^##\s+(.+)$", &match)) {
            titleText := Trim(match[1])
            if (titleText != "")
                title := titleText
        }

        if (lines.Length > 0) {
            lastLine := lines[lines.Length]
            if (RegExMatch(lastLine, "^==\s*(.+?)\s*==$", &match)) {
                targetName := Trim(match[1])
                lines.Pop()

                if (noteTargets.Has(targetName)) {
                    targetFile := noteTargets[targetName]
                } else {
                    potentialFile := noteConfig.defaultDir . targetName . ".txt"
                    if (FileExist(potentialFile)) {
                        targetFile := potentialFile
                    }
                }
            }
        }

        if (lines.Length > 0 && RegExMatch(lines[1], "^##\s*$")) {
            lines.RemoveAt(1)
        }

        savedPath := ""
        if (targetFile && FileExist(targetFile)) {
            savedPath := SaveToSpecificFile(targetFile, lines, title, targetName)
        } else if (targetName && noteTargets.Has(targetName)) {
            savedPath := SaveToTargetFile(targetName, lines, title)
        } else {
            savedPath := SaveToNewFile(lines, title)
        }

        if (savedPath && FileExist(savedPath)) {
            currentEditingFile := savedPath
            try {
                fileContent := FileRead(savedPath, "UTF-8")
            } catch {
                fileContent := FileRead(savedPath)
            }
            noteEdit.Value := fileContent
            statusBar.SetText("提示: 正在编辑 | Ctrl+S保存 | 新建速记按钮可写新内容")
        }
        ControlFocus(noteEdit)
    }
}

SaveToNewFile(lines, title) {
    try {
        if (title) {
            cleanTitle := CleanFileNameFromTitle(title)
            fileName := cleanTitle . ".txt"
        } else {
            fileName := FormatTime(, "yyyyMMdd_HHmmss") . ".txt"
        }

        filePath := noteConfig.defaultDir . fileName

        content := ""
        timeStamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")

        fileExists := FileExist(filePath)

        if (fileExists && title) {
            content := "`n`n`n"

            hasNewTitle := false
            newTitle := ""
            if (lines.Length > 0 && RegExMatch(lines[1], "^##\s+(.+)$", &match)) {
                titleText := Trim(match[1])
                if (titleText != "") {
                    hasNewTitle := true
                    newTitle := lines[1]
                }
            }

            if (hasNewTitle) {
                content .= "[" . timeStamp . "]`n"
                content .= newTitle . "`n`n"
            } else {
                content .= "[" . timeStamp . "]`n`n"
            }

            for i, line in lines {
                if (i = 1 && hasNewTitle) {
                    continue
                }
                content .= line . "`n"
            }

            FileAppend(content, filePath)

            ToolTip("已追加到「" . filePath . "」")
        } else {
            if (title) {
                hasTitle := false
                if (lines.Length > 0 && RegExMatch(lines[1], "^##\s+(.+)$", &match)) {
                    titleText := Trim(match[1])
                    if (titleText != "") {
                        hasTitle := true
                    }
                }

                if (hasTitle) {
                    for i, line in lines {
                        if (i = 1) {
                            content .= "[" . timeStamp . "]`n"
                            content .= line . "`n`n"
                        } else {
                            content .= line . "`n"
                        }
                    }
                } else {
                    content .= "[" . timeStamp . "]`n"
                    content .= "## " . title . "`n`n"

                    for i, line in lines {
                        content .= line . "`n"
                    }
                }
            } else {
                content .= "[" . timeStamp . "]`n`n"

                for i, line in lines {
                    content .= line . "`n"
                }
            }

            FileAppend(content, filePath)

            ToolTip("已保存到「" . filePath . "」")
        }

        SetTimer () => ToolTip(), -2000
        return filePath
    } catch as e {
        MsgBox("保存失败: " . e.Message, "速记", "Icon!")
        return ""
    }
}

SaveToTargetFile(targetName, lines, title) {
    try {
        filePath := noteTargets[targetName]

        content := "`n`n`n"
        timeStamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")

        if (title) {
            content .= "[" . timeStamp . "]`n"
            content .= "## " . title . "`n`n"
        } else {
            content .= "[" . timeStamp . "]`n`n"
        }

        for i, line in lines {
            if (i = 1 && title && RegExMatch(line, "^##\s+")) {
                continue
            }
            content .= line . "`n"
        }

        FileAppend(content, filePath)

        ToolTip("已保存到「" . targetName . "」")
        SetTimer () => ToolTip(), -2000
        return filePath
    } catch as e {
        MsgBox("保存失败: " . e.Message, "速记", "Icon!")
        return ""
    }
}

StrRepeat(str, count) {
    result := ""
    loop count {
        result .= str
    }
    return result
}

ToggleNoteViewHandler(*) {
    global noteViewMode, noteEdit, noteListView, searchEdit, searchLabel, statusBar, currentEditingFile, deleteBtn,
        noteGui, viewToggleBtn, newNoteBtn

    noteViewMode := !noteViewMode

    if (noteViewMode) {
        noteEdit.Opt("+ReadOnly")
        noteEdit.Value := ""
        noteEdit.Visible := false
        noteListView.Visible := true
        searchEdit.Visible := true
        searchLabel.Visible := true
        deleteBtn.Visible := true
        newNoteBtn.Visible := false
        viewToggleBtn.Text := "编辑速记"
        LoadNoteFilesToList()

        statusBar.SetText("提示: 双击文件加载 | 选择后点击删除选中")
    } else {
        noteEdit.Opt("-ReadOnly")
        noteEdit.Value := "## "
        noteEdit.Visible := true
        noteListView.Visible := false
        searchEdit.Visible := false
        searchLabel.Visible := false
        deleteBtn.Visible := false
        newNoteBtn.Visible := true
        viewToggleBtn.Text := "查看速记"
        currentEditingFile := ""

        statusBar.SetText("提示: 输入标题或删除## | 最后一行使用==目标==指定保存位置 | Ctrl+S保存")

        SendInput("{End}")
    }
}

LoadNoteFilesToList(filter := "") {
    global noteListView, noteTargets, noteConfig

    noteListView.Delete()

    noteDir := noteConfig.defaultDir

    noteFiles := []

    for targetName, filePath in noteTargets {
        if (FileExist(filePath)) {
            SplitPath(filePath, &fileName)

            if (filter = "" || InStr(fileName, filter) || InStr(targetName, filter)) {
                noteFiles.Push({
                    name: fileName,
                    path: filePath,
                    target: targetName
                })
            }
        }
    }

    loop files noteDir . "*.txt" {
        isInTargets := false
        for _, noteFile in noteFiles {
            if (noteFile.path = A_LoopFilePath)
                isInTargets := true
        }

        if (!isInTargets) {
            SplitPath(A_LoopFilePath, &fileName)

            if (filter = "" || InStr(fileName, filter)) {
                noteFiles.Push({
                    name: fileName,
                    path: A_LoopFilePath,
                    target: "默认"
                })
            }
        }
    }

    loop noteFiles.Length - 1 {
        swapped := false
        loop noteFiles.Length - A_Index {
            if (FileGetTime(noteFiles[A_Index].path, "M") < FileGetTime(noteFiles[A_Index + 1].path, "M")) {
                temp := noteFiles[A_Index]
                noteFiles[A_Index] := noteFiles[A_Index + 1]
                noteFiles[A_Index + 1] := temp
                swapped := true
            }
        }
        if (!swapped)
            break
    }

    for _, noteFile in noteFiles {
        modTime := FileGetTime(noteFile.path, "M")
        modTimeStr := FormatTime(modTime, "yyyy-MM-dd HH:mm")

        noteListView.Add("", noteFile.name, modTimeStr, noteFile.target, noteFile.path)
    }

    noteListView.ModifyCol(1, 220)
    noteListView.ModifyCol(2, 140)
    noteListView.ModifyCol(3, 80)
    noteListView.ModifyCol(4, 0)
}

NoteSearchHandler(*) {
    global noteSearchText, searchEdit
    noteSearchText := searchEdit.Value
    LoadNoteFilesToList(noteSearchText)
}

DeleteSelectedNote(*) {
    global noteListView

    selectedRow := noteListView.GetNext()
    if (!selectedRow) {
        MsgBox("请先选择一个速记文件", "删除速记", "Icon!")
        return
    }

    filePath := noteListView.GetText(selectedRow, 4)
    fileName := noteListView.GetText(selectedRow, 1)

    if (!filePath) {
        return
    }

    try {
        FileDelete(filePath)
        LoadNoteFilesToList()
        ToolTip("已删除「" . fileName . "」")
        SetTimer () => ToolTip(), -2000
    } catch as e {
        MsgBox("删除失败: " . e.Message, "错误", "Icon!")
    }
}

CleanFileNameFromTitle(title) {
    title := RegExReplace(title, "\\", "「反斜杠」")
    title := RegExReplace(title, "/", "「斜杠」")
    title := RegExReplace(title, ":", "「冒号」")
    title := RegExReplace(title, "\*", "「星号」")
    title := RegExReplace(title, "\?", "「问号」")
    title := RegExReplace(title, "`"", "「引号」")
    title := RegExReplace(title, "<", "「小于」")
    title := RegExReplace(title, ">", "「大于」")
    title := RegExReplace(title, "\|", "「竖线」")
    return title
}

SaveToSpecificFile(filePath, lines, title, displayName) {
    try {
        content := "`n`n`n"
        timeStamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")

        if (title) {
            content .= "[" . timeStamp . "]`n"
            content .= "## " . title . "`n`n"
        } else {
            content .= "[" . timeStamp . "]`n`n"
        }

        for i, line in lines {
            if (i = 1 && title && RegExMatch(line, "^##\s+")) {
                continue
            }
            content .= line . "`n"
        }

        FileAppend(content, filePath)

        if (displayName) {
            ToolTip("已保存到「" . displayName . "」")
        } else {
            SplitPath(filePath, &fileName)
            ToolTip("已保存到「" . fileName . "」")
        }
        SetTimer () => ToolTip(), -2000
        return filePath
    } catch as e {
        MsgBox("保存失败: " . e.Message, "速记", "Icon!")
        return ""
    }
}

; =====================================================================
; QuickSearch — CapsLock+Q 智能搜索
; 选中文本 → URL编码后Bing搜索 / 打开URL / 打开路径
; =====================================================================
QuickSearch() {
    ; 保存剪贴板
    savedClipboard := ClipboardAll()
    A_Clipboard := ""

    ; 复制选中内容
    Send("^c")
    if (!ClipWait(0.3, 0)) {
        A_Clipboard := savedClipboard
        return
    }

    selectedText := Trim(A_Clipboard)
    A_Clipboard := savedClipboard

    if (selectedText = "")
        return

    ; 是 URL → 浏览器打开
    if (RegExMatch(selectedText, "i)^https?://")) {
        Run(selectedText)
        ShowTooltipNearMouse("打开链接: " selectedText)
        return
    }

    ; 是绝对路径 → 资源管理器打开
    if (RegExMatch(selectedText, "i)^[A-Za-z]:\\")) {
        if (FileExist(selectedText) || DirExist(selectedText)) {
            Run("explorer.exe `"" selectedText "`"")
            ShowTooltipNearMouse("打开路径: " selectedText)
            return
        }
    }

    ; 其余 → Bing 搜索
    encoded := _UriEncode(selectedText)
    Run("https://www.bing.com/search?q=" . encoded)
    ShowTooltipNearMouse("Bing 搜索: " selectedText)
}

; =====================================================================
; _UriEncode — 简单 URL 编码 (保留 A-Z a-z 0-9 - _ . ~)
; =====================================================================
_UriEncode(str) {
    encoded := ""
    loop parse, str {
        char := A_LoopField
        code := Ord(char)
        if ((code >= 0x30 && code <= 0x39)
            || (code >= 0x41 && code <= 0x5A)
            || (code >= 0x61 && code <= 0x7A)
            || code = 0x2D || code = 0x2E || code = 0x5F || code = 0x7E) {
            encoded .= char
        } else if (code <= 0x7F) {
            encoded .= "%" . Format("{:02X}", code)
        } else if (code <= 0x7FF) {
            encoded .= "%" . Format("{:02X}", 0xC0 | (code >> 6))
            encoded .= "%" . Format("{:02X}", 0x80 | (code & 0x3F))
        } else {
            encoded .= "%" . Format("{:02X}", 0xE0 | (code >> 12))
            encoded .= "%" . Format("{:02X}", 0x80 | ((code >> 6) & 0x3F))
            encoded .= "%" . Format("{:02X}", 0x80 | (code & 0x3F))
        }
    }
    return encoded
}
