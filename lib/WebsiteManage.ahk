; =====================================================================
; CapsLock++ 网站管理模块
; 包含：网站登录、默认网站打开、网站选择GUI、批量网站操作等功能
; =====================================================================

WebsiteLogin(url := "") {
    CloseMenu()
    if (url != "") {
        browser := ReadIniValueUTF8(A_ScriptDir "\CapsLock++.ini", "CommonWebsites", "browser", "edge")
        OpenOneWebsite(url, browser)
        return
    }
    if (GetKeyState("Alt", "P")) {
        ShowWebsiteSelectionGUI()
    } else {
        OpenDefaultWebsite()
    }
}

OpenDefaultWebsite() {
    site := ReadIniValueUTF8(A_ScriptDir "\CapsLock++.ini", "CommonWebsites", "default_site", "")

    if (site = "") {
        site := ReadIniValueUTF8(A_ScriptDir "\CapsLock++.ini", "Credentials", "site", "")
    }

    if (site = "") {
        ShowTooltip("错误: 无法从INI文件读取网站配置")
        return
    }

    browser := ReadIniValueUTF8(A_ScriptDir "\CapsLock++.ini", "CommonWebsites", "browser", "edge")

    OpenOneWebsite(site, browser)
}

OpenOneWebsite(url, browser := "edge") {
    if (!InStr(url, "://")) {
        url := "https://" . url
    }

    switch browser {
        case "edge", "msedge":
            Run("msedge.exe " . url)
        case "chrome":
            Run("chrome.exe " . url)
        case "firefox":
            Run("firefox.exe " . url)
        default:
            Run(url)
    }
}

ShowWebsiteSelectionGUI() {
    try CloseMenu()

    websiteList := []

    i := 1
    Loop {
        siteKey := "site" . i
        urlKey := "url" . i

        siteName := ReadIniValueUTF8(A_ScriptDir "\CapsLock++.ini", "CommonWebsites", siteKey, "")
        if (siteName = "")
            break

        siteUrl := ReadIniValueUTF8(A_ScriptDir "\CapsLock++.ini", "CommonWebsites", urlKey, "")
        if (siteUrl = "")
            continue

        if (!InStr(siteUrl, "://")) {
            siteUrl := "https://" . siteUrl
        }

        websiteList.Push({name: siteName, url: siteUrl, checked: false})

        i++
    }

    if (websiteList.Length = 0) {
        ShowTooltip("错误: 无法从INI文件读取网站列表，请先配置[CommonWebsites]部分")
        return
    }

    browser := ReadIniValueUTF8(A_ScriptDir "\CapsLock++.ini", "CommonWebsites", "browser", "edge")

    websiteGui := Gui("+AlwaysOnTop +ToolWindow")
    websiteGui.Title := "选择要打开的网站"

    listView := websiteGui.Add("ListView", "x10 y10 w500 h300 Checked", ["网站名称", "网址"])

    for _, site in websiteList {
        row := listView.Add(site.checked ? "Check" : "", site.name, site.url)
    }

    listView.ModifyCol(1, 150)
    listView.ModifyCol(2, "Auto")

    btnSelectAll := websiteGui.Add("Button", "x10 y320 w90 h30", "全选")
    btnSelectAll.OnEvent("Click", (*) => SelectAllItems(listView, true))

    btnSelectNone := websiteGui.Add("Button", "x110 y320 w90 h30", "全不选")
    btnSelectNone.OnEvent("Click", (*) => SelectAllItems(listView, false))

    btnInvert := websiteGui.Add("Button", "x210 y320 w90 h30", "反选")
    btnInvert.OnEvent("Click", (*) => InvertSelection(listView))

    btnOk := websiteGui.Add("Button", "x310 y320 w200 h30", "打开选中网站")
    btnOk.OnEvent("Click", (*) => WebsiteSelection(listView, websiteList, browser, websiteGui))

    btnBack := websiteGui.Add("Button", "x10 y360 w240 h30", "← 返回")
    btnBack.OnEvent("Click", BackToMainMenu)

    btnCancel := websiteGui.Add("Button", "x260 y360 w250 h30", "取消")
    btnCancel.OnEvent("Click", (*) => websiteGui.Destroy())

    listView.OnEvent("DoubleClick", (*) => WebsiteSingleItem(listView, websiteList, browser, websiteGui))

    websiteGui.OnEvent("Escape", (*) => websiteGui.Destroy())
    websiteGui.OnEvent("Close", (*) => websiteGui.Destroy())

    websiteGui.Show("w520 h400")
    listView.Focus()

    SelectAllItems(listView, false)
}

WebsiteSelection(listView, websiteList, browser, gui) {
    selectedItems := []
    row := 0

    Loop {
        row := listView.GetNext(row, "Checked")
        if (!row)
            break
        selectedItems.Push(websiteList[row])
    }

    gui.Destroy()

    if (selectedItems.Length > 0) {
        for _, item in selectedItems {
            OpenOneWebsite(item.url, browser)
            Sleep(200)
        }
    } else {
        ShowTooltip("未选择任何网站")
    }
}

WebsiteSingleItem(listView, websiteList, browser, gui) {
    row := listView.GetNext(0, "Focused")
    if (row) {
        site := websiteList[row]

        gui.Destroy()

        OpenOneWebsite(site.url, browser)
    }
}
