; =====================================================================
; CapsLock++ 跳转模式模块
; 包含：光标位置获取、跳转模式状态机、InputHook处理
; 全局变量在 lib/Globals.ahk 中声明
; 工具函数在 lib/Utils.ahk 中声明
; =====================================================================

GetCaretPosition() {
    static left := 0, top := 0, right := 0, bottom := 0
    
    ; 检查是否有光标
    if GetCaretPosEx(&left, &top, &right, &bottom, true) {
        ; 获取屏幕尺寸用于验证
        MonitorGetWorkArea(, &monitorLeft, &monitorTop, &monitorRight, &monitorBottom)
        
        ; 检查是否为屏幕边缘坐标（可能是伪光标位置）
        isScreenEdge := (Abs(left - monitorRight) < 5 || Abs(bottom - monitorBottom) < 5 || (left < 5 && top < 5))
        
        ; 如果不是屏幕边缘，则认为是有效的光标位置
        if (!isScreenEdge) {
            return {x: left, y: bottom}
        }
    }
    
    ; 获取失败，返回false
    return false
}

GetCaretPosEx(&left?, &top?, &right?, &bottom?, useHook := false) {
    if getCaretPosFromGui(&hwnd := 0)
        return true
    try
        className := WinGetClass(hwnd)
    catch
        className := ""
    if className ~= "^(?:Windows|Microsoft)\.UI\..+"
        funcs := [getCaretPosFromUIA, getCaretPosFromHook, getCaretPosFromMSAA]
    else if className ~= "^HwndWrapper\[PowerShell_ISE\.exe;;[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\]"
        funcs := [getCaretPosFromHook, getCaretPosFromWpfCaret]
    else
        funcs := [getCaretPosFromMSAA, getCaretPosFromUIA, getCaretPosFromHook]
    for fn in funcs {
        if fn == getCaretPosFromHook && !useHook
            continue
        if fn()
            return true
    }
    return false

    getCaretPosFromGui(&hwnd) {
        x64 := A_PtrSize == 8
        guiThreadInfo := Buffer(x64 ? 72 : 48)
        NumPut("uint", guiThreadInfo.Size, guiThreadInfo)
        if DllCall("GetGUIThreadInfo", "uint", 0, "ptr", guiThreadInfo) {
            if hwnd := NumGet(guiThreadInfo, x64 ? 48 : 28, "ptr") {
                getRect(guiThreadInfo.Ptr + (x64 ? 56 : 32), &left, &top, &right, &bottom)
                scaleRect(getWindowScale(hwnd), &left, &top, &right, &bottom)
                clientToScreenRect(hwnd, &left, &top, &right, &bottom)
                return true
            }
            hwnd := NumGet(guiThreadInfo, x64 ? 16 : 12, "ptr")
        }
        return false
    }

    getCaretPosFromMSAA() {
        if !hOleacc := DllCall("LoadLibraryW", "str", "oleacc.dll", "ptr")
            return false
        hOleacc := { Ptr: hOleacc, __Delete: (_) => DllCall("FreeLibrary", "ptr", _) }
        static IID_IAccessible := guidFromString("{618736e0-3c3d-11cf-810c-00aa00389b71}")
        if !DllCall("oleacc\AccessibleObjectFromWindow", "ptr", hwnd, "uint", 0xfffffff8, "ptr", IID_IAccessible, "ptr*", accCaret := ComValue(13, 0), "int") {
            if A_PtrSize == 8 {
                varChild := Buffer(24, 0)
                NumPut("ushort", 3, varChild)
                hr := ComCall(22, accCaret, "int*", &x := 0, "int*", &y := 0, "int*", &w := 0, "int*", &h := 0, "ptr", varChild, "int")
            }
            else {
                hr := ComCall(22, accCaret, "int*", &x := 0, "int*", &y := 0, "int*", &w := 0, "int*", &h := 0, "int64", 3, "int64", 0, "int")
            }
            if !hr {
                pt := x | y << 32
                DllCall("ScreenToClient", "ptr", hwnd, "int64*", &pt)
                left := pt & 0xffffffff
                top := pt >> 32
                right := left + w
                bottom := top + h
                scaleRect(getWindowScale(hwnd), &left, &top, &right, &bottom)
                clientToScreenRect(hwnd, &left, &top, &right, &bottom)
                return true
            }
        }
        return false
    }

    getCaretPosFromUIA() {
        try {
            uia := ComObject("{E22AD333-B25F-460C-83D0-0581107395C9}", "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")
            ComCall(20, uia, "ptr*", cacheRequest := ComValue(13, 0)) ; uia->CreateCacheRequest(&cacheRequest);
            if !cacheRequest.Ptr
                return false
            ComCall(4, cacheRequest, "ptr", 10014) ; cacheRequest->AddPattern(UIA_TextPatternId);
            ComCall(4, cacheRequest, "ptr", 10024) ; cacheRequest->AddPattern(UIA_TextPattern2Id);

            ComCall(12, uia, "ptr", cacheRequest, "ptr*", focusedEle := ComValue(13, 0)) ; uia->GetFocusedElementBuildCache(cacheRequest, &focusedEle);
            if !focusedEle.Ptr
                return false

            static IID_IUIAutomationTextPattern2 := guidFromString("{506a921a-fcc9-409f-b23b-37eb74106872}")
            range := ComValue(13, 0)
            ComCall(15, focusedEle, "int", 10024, "ptr", IID_IUIAutomationTextPattern2, "ptr*", textPattern := ComValue(13, 0)) ; focusedEle->GetCachedPatternAs(UIA_TextPattern2Id, IID_PPV_ARGS(&textPattern));
            if textPattern.Ptr {
                ComCall(10, textPattern, "int*", &isActive := 0, "ptr*", range) ; textPattern->GetCaretRange(&isActive, &range);
                if range.Ptr
                    goto getRangeInfo
            }
            ; If no caret range, get selection range.
            static IID_IUIAutomationTextPattern := guidFromString("{32eba289-3583-42c9-9c59-3b6d9a1e9b6a}")
            ComCall(15, focusedEle, "int", 10014, "ptr", IID_IUIAutomationTextPattern, "ptr*", textPattern) ; focusedEle->GetCachedPatternAs(UIA_TextPatternId, IID_PPV_ARGS(&textPattern));
            if textPattern.Ptr {
                ComCall(5, textPattern, "ptr*", ranges := ComValue(13, 0)) ; textPattern->GetSelection(&ranges);
                if ranges.Ptr {
                    ; Retrieve the last selection range.
                    ComCall(3, ranges, "int*", &len := 0) ; ranges->get_Length(&len);
                    if len > 0 {
                        ComCall(4, ranges, "int", len - 1, "ptr*", range) ; ranges->GetElement(len - 1, &range);
                        if range.Ptr {
                            ; Collapse the range.
                            ComCall(15, range, "int", 0, "ptr", range, "int", 1) ; range->MoveEndpointByRange(TextPatternRangeEndpoint_Start, range, TextPatternRangeEndpoint_End);
                            goto getRangeInfo
                        }
                    }
                }
            }
            return false
getRangeInfo:
            psa := 0
            ; This is a degenerate text range, we have to expand it.
            ComCall(6, range, "int", 0) ; range->ExpandToEnclosingUnit(TextUnit_Character);
            ComCall(10, range, "ptr*", &psa) ; range->GetBoundingRectangles(&psa);
            if psa {
                rects := ComValue(0x2005, psa, 1) ; SafeArray<double>
                if rects.MaxIndex() >= 3 {
                    rects[2] := 0
                    goto end
                }
            }
            ; ExpandToEnclosingUnit by character may be invalid in some control if the range is at the end of the document.
            ; Assume that the range is at the end of the document and not in an empty line, try to expand it by line.
            ComCall(6, range, "int", 3) ; range->ExpandToEnclosingUnit(TextUnit_Line)
            ComCall(10, range, "ptr*", &psa) ; range->GetBoundingRectangles(&psa);
            if psa {
                rects := ComValue(0x2005, psa, 1) ; SafeArray<double>
                if rects.MaxIndex() >= 3 {
                    ; Here rects is {x, y, w, h}, we take the end endpoint as the caret position.
                    rects[0] := rects[0] + rects[2]
                    rects[2] := 0
                    goto end
                }
            }
            return false
end:
            left := Round(rects[0])
            top := Round(rects[1])
            right := left + Round(rects[2])
            bottom := top + Round(rects[3])
            return true
        }
        return false
    }

    getCaretPosFromWpfCaret() {
        try {
            uia := ComObject("{E22AD333-B25F-460C-83D0-0581107395C9}", "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")
            ComCall(8, uia, "ptr*", focusedEle := ComValue(13, 0)) ; uia->GetFocusedElement(&focusedEle);
            if !focusedEle.Ptr
                return false

            ComCall(20, uia, "ptr*", cacheRequest := ComValue(13, 0)) ; uia->CreateCacheRequest(&cacheRequest);
            if !cacheRequest.Ptr
                return false

            ComCall(17, uia, "ptr*", rawViewCondition := ComValue(13, 0)) ; uia->get_RawViewCondition(&rawViewCondition);
            if !rawViewCondition.Ptr
                return false

            ComCall(9, cacheRequest, "ptr", rawViewCondition) ; cacheRequest->put_TreeFilter(rawViewCondition);
            ComCall(3, cacheRequest, "int", 30001) ; cacheRequest->AddProperty(UIA_BoundingRectanglePropertyId);

            var := Buffer(24, 0)
            ref := ComValue(0x400C, var.Ptr)
            ref[] := ComValue(8, "WpfCaret")
            ComCall(23, uia, "int", 30012, "ptr", var, "ptr*", condition := ComValue(13, 0)) ; uia->CreatePropertyCondition(UIA_ClassNamePropertyId, CComVariant(L"WpfCaret"), &classNameCondition);
            if !condition.Ptr
                return false

            ComCall(7, focusedEle, "int", 4, "ptr", condition, "ptr", cacheRequest, "ptr*", wpfCaret := ComValue(13, 0)) ; focusedEle->FindFirstBuildCache(TreeScope_Descendants, condition, cacheRequest, &wpfCaret);
            if !wpfCaret.Ptr
                return false

            ComCall(75, wpfCaret, "ptr", rect := Buffer(16)) ; wpfCaret->get_CachedBoundingRectangle(&rect);
            getRect(rect, &left, &top, &right, &bottom)
            return true
        }
        return false
    }

    getCaretPosFromHook() {
        static WM_GET_CARET_POS := DllCall("RegisterWindowMessageW", "str", "WM_GET_CARET_POS", "uint")
        if !tid := DllCall("GetWindowThreadProcessId", "ptr", hwnd, "ptr*", &pid := 0, "uint")
            return false
        ; Update caret position
        try {
            SendMessage(0x010f, 0, 0, hwnd) ; WM_IME_COMPOSITION
        }
        ; PROCESS_CREATE_THREAD | PROCESS_QUERY_INFORMATION | PROCESS_VM_OPERATION | PROCESS_VM_WRITE | PROCESS_VM_READ
        if !hProcess := DllCall("OpenProcess", "uint", 1082, "int", false, "uint", pid, "ptr")
            return false
        hProcess := { Ptr: hProcess, __Delete: (_) => DllCall("CloseHandle", "ptr", _) }

        isX64 := isX64Process(hProcess)
        if isX64 && A_PtrSize == 4
            return false
        if !moduleBaseMap := getModulesBases(hProcess, ["kernel32.dll", "user32.dll", "combase.dll"])
            return false
        if isX64 {
            static shellcode64 := compile(true)
            shellcode := shellcode64
        }
        else {
            static shellcode32 := compile(false)
            shellcode := shellcode32
        }
        if !mem := DllCall("VirtualAllocEx", "ptr", hProcess, "ptr", 0, "ptr", shellcode.Size, "uint", 0x1000, "uint", 0x40, "ptr")
            return false
        mem := { Ptr: mem, __Delete: (_) => DllCall("VirtualFreeEx", "ptr", hProcess, "ptr", _, "uptr", 0, "uint", 0x8000) }
        link(isX64, shellcode, mem.Ptr, moduleBaseMap["user32.dll"], moduleBaseMap["combase.dll"], hwnd, tid, WM_GET_CARET_POS, &pThreadProc, &pRect)

        if !DllCall("WriteProcessMemory", "ptr", hProcess, "ptr", mem, "ptr", shellcode, "uptr", shellcode.Size, "ptr", 0)
            return false
        DllCall("FlushInstructionCache", "ptr", hProcess, "ptr", mem, "uptr", shellcode.Size)

        if !hThread := DllCall("CreateRemoteThread", "ptr", hProcess, "ptr", 0, "uptr", 0, "ptr", pThreadProc, "ptr", mem, "uint", 0, "uint*", &remoteTid := 0, "ptr")
            return false
        hThread := { Ptr: hThread, __Delete: (_) => DllCall("CloseHandle", "ptr", _) }

        if msgWaitForSingleObject(hThread)
            return false
        if !DllCall("GetExitCodeThread", "ptr", hThread, "uint*", exitCode := 0) || exitCode !== 0
            return false

        rect := Buffer(16)
        if !DllCall("ReadProcessMemory", "ptr", hProcess, "ptr", pRect, "ptr", rect, "uptr", rect.Size, "uptr*", &bytesRead := 0) || bytesRead !== rect.Size
            return false
        getRect(rect, &left, &top, &right, &bottom)
        scaleRect(getWindowScale(hwnd), &left, &top, &right, &bottom)
        return true

        static isX64Process(hProcess) {
            DllCall("IsWow64Process", "ptr", hProcess, "int*", &isWow64 := 0)
            if isWow64
                return false
            if A_PtrSize == 8
                return true
            DllCall("IsWow64Process", "ptr", DllCall("GetCurrentProcess", "ptr"), "int*", &isWow64)
            return isWow64
        }

        static getModulesBases(hProcess, modules) {
            hModules := Buffer(A_PtrSize * 350)
            if !DllCall("K32EnumProcessModulesEx", "ptr", hProcess, "ptr", hModules, "uint", hModules.Size, "uint*", &needed := 0, "uint", 3)
                return
            moduleBaseMap := Map()
            moduleBaseMap.CaseSense := false
            for v in modules
                moduleBaseMap[v] := 0
            cnt := modules.Length
            loop Min(350, needed) {
                hModule := NumGet(hModules, A_PtrSize * (A_Index - 1), "ptr")
                VarSetStrCapacity(&name, 12)
                if DllCall("K32GetModuleBaseNameW", "ptr", hProcess, "ptr", hModule, "str", &name, "uint", 13) {
                    if moduleBaseMap.Has(name) {
                        moduleInfo := Buffer(24)
                        if !DllCall("K32GetModuleInformation", "ptr", hProcess, "ptr", hModule, "ptr", moduleInfo, "uint", moduleInfo.Size)
                            return
                        if !base := NumGet(moduleInfo, "ptr")
                            return
                        moduleBaseMap[name] := base
                        cnt--
                    }
                }
            } until cnt == 0
            if cnt == 0
                return moduleBaseMap
        }

        static compile(x64) {
            if x64
                shellcodeBase64 := "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABrnppSh2UjT6uenH1oPjxQAeiAqiEg0hGT4ABgsGe4blNldFdpbmRvd3NIb29rRXhXAAAAVW5ob29rV2luZG93c0hvb2tFeABDYWxsTmV4dEhvb2tFeAAAAAAAAFNlbmRNZXNzYWdlVGltZW91dFcAQ29DcmVhdGVJbnN0YW5jZQAAAAAAAAAASIlcJAhIiXQkEFdIg+wgSYvYSIvyi/mFyXgjSIXbdB6LBQb///9BOUAQdRJIjQ3d/v//6JgBAACJBfL+//9Iiw3L/v//SI0VdP///+jnAgAASIXAdRBIi1wkMEiLdCQ4SIPEIF/DTIvLTIvGi9czyUiLXCQwSIt0JDhIg8QgX0j/4MzMzMzMzDPAw8zMzMzMQFNWSIPsSIvySIvZSIXJdQy4VwAHgEiDxEheW8NIi0kISI1UJGBIiVQkKEG4/////0iNVCQwSIl8JEAz/0iJVCQgiXwkYIvWSIsBRI1PAf9QKIXAeHJIOXwkMHRrOXwkYHRlSItLCEiNVCR4SIl8JHhIiwH/UEiL+IXAeDJIi0wkeEiFyXQoSIsBSI1UJHBMi0QkMEyNSxBIiVQkIIvW/1AgSItMJHiL+EiLAf9QEEiLTCQwSIsB/1AQi8dIi3wkQEiDxEheW8NIi3wkQLgBAAAASIPESF5bw8zMzMzMzMxIhcl0VEiF0nRPTYXAdEpIiwJIhcB1HUi4wAAAAAAAAEZIOUIIdCxJxwAAAAAAuAJAAIDDSbkD6ICqISDSEUk7wXXkSLiT4ABgsGe4bkg5Qgh11EmJCDPAw7hXAAeAw8xAU0iD7EBIi9lIjZHYAAAASItJCOhPAQAASIXAdQu4AQAAAEiDxEBbwzPJx0QkWAEAAABIjVQkaEiJTCRoSIlUJCBMjUt4M9JIiUwkYEiJTCQwiUwkUEiNS2hEjUIX/9CFwA+I7wAAAEiLTCRoSIXJD4ThAAAASIsBSI1UJFD/UBiFwA+IhQAAAEiLTCRoSI1UJGBIiwH/UDiFwHhxSItMJGBIhcl0bEiLAUiNVCQw/1AwhcB4WEiLTCQwSIXJdGZIjUNISIlLMEiJQyhMjUMoSI0Vyf7//0G5AwAAAEiJEEiNBdH9//9IiUNQSI1UJFhIiUNYSI0Fxf3//0iJQ2BIiwFIiVQkIItUJFD/UBhIi0wkYEiLVCQwSIXSdA5IiwJIi8r/UBBIi0wkYEiFyXQGSIsB/1AQSItMJGhIhcl0BkiLAf9QEItEJFj32BvAg+AESIPEQFvDuAQAAABIg8RAW8PMzMzMzMxIiVwkCEiJbCQQSIl0JBhIiXwkIEyL2kyL0UiFyXRwSIXSdGtIY0E8g7wIjAAAAAB0XYuMCIgAAACFyXRSRYtMCiBJjQQKi3AkTQPKi2gcSQPyi3gYSQPqD7YaRTPA/89BixFJA9I6GnUZD7bLSYvDSSvThMl0Lw+2SAFI/8A6DAJ08EH/wEmDwQREO8d20TPASItcJAhIi2wkEEiLdCQYSIt8JCDDSWPAD7cMRotEjQBJA8Lr28zMSIlcJAhIiWwkEEiJdCQYSIl8JCBBVkiD7EBIixlIjZGIAAAASIv5SIvL6Bn///9IjZfEAAAASIvLSIvw6Af///9IjZecAAAASIvLSIvo6PX+//9Mi/BIhfZ0ZUiF7XRgSIXAdFtEi08YSI0VoPv//0UzwEGNSAT/1kiL8EiFwHUFjUYC6z+LVxwzwEiLTxBFM8lIiUQkMEUzwMdEJCjIAAAAiUQkIP/VSIvOSIvYQf/WSIXbdQWNQwPrCotHIOsFuAEAAABIi1wkUEiLbCRYSIt0JGBIi3wkaEiDxEBBXsM="
            else
                shellcodeBase64 := "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGuemlKHZSNPq56cfWg+PFAB6ICqISDSEZPgAGCwZ7huU2V0V2luZG93c0hvb2tFeFcAAABVbmhvb2tXaW5kb3dzSG9va0V4AENhbGxOZXh0SG9va0V4AAAAAAAAU2VuZE1lc3NhZ2VUaW1lb3V0VwBDb0NyZWF0ZUluc3RhbmNlAAAAAFZX6MkCAACDfCQMAIvwi3wkFHwYhf90FItPCDtOEHUMVuhqAQAAg8QEiUYUjYaIAAAAUP826J4CAACDxAiFwHUFX17CDABX/3QkFP90JBRqAP/QX17CDAAzwMIEAMzMzIPsFFaLdCQchfZ1DLhXAAeAXoPEFMIIAItOBI1UJARSjVQkEMdEJAgAAAAAUosBagFq//90JDBR/1AUhcB4bIN8JAwAdGWDfCQEAHRei04EjVQkHFfHRCQgAAAAAFKLAVH/UCSL+IX/eC2LVCQghdJ0JYsCi0gQjUQkDFCNRghQ/3QkGP90JDBS/9GL+ItEJCBQiwj/UQiLRCQQUIsI/1EIi8dfXoPEFMIIALgBAAAAXoPEFMIIAMyLTCQIVot0JAiF9nRfhcl0W4tUJBCF0nRTiwELQQR1IYF5CMAAAAB1CYF5DAAAAEZ0MscCAAAAALgCQACAXsIMAIE5A+iAqnXpgXkEISDSEXXggXkIk+AAYHXXgXkMsGe4bnXOiTIzwF7CDAC4VwAHgF7CDADMzMyD7BBWi3QkGI2GsAAAAFD/dgToMQEAAIvIg8QIhcl1CI1BAV6DxBDDjUQkBMdEJAQAAAAAUI1GUMdEJBwAAAAAUGoXagCNRkDHRCQYAAAAAFDHRCQgAAAAAMdEJCQBAAAA/9GFwA+IywAAAItMJASFyQ+EvwAAAIsBjVQkDFdSUf9QDIXAeHCLTCQIjVQkHFJRiwH/UByFwHhdi0wkHIXJdFmLAY1UJAxSUf9QGIXAeEaLfCQMhf90UI1OMIl+HLjcAQAAiU4YA8aNVhiJAYvGBRwBAACNTCQUUYlGNIlGOLgkAQAAagMDxlL/dCQciUY8iwdX/1AMi0wkHItUJAyF0nQKiwJS/1AIi0wkHF+FyXQGiwFR/1AIi0wkBIXJdAaLAVH/UAiLRCQQ99heG8CD4ASDxBDDuAQAAABeg8QQw7gAAAAAw8zMg+wIU1VWV4t8JByF/w+EgQAAAItcJCCF23R5i0c8g3w4fAB0b4tEOHiFwHRni0w4JDP2i1Q4IAPPi2w4GAPXiUwkEItMOBwDz4lUJByJTCQUTYorixSyA9c6KnUTis2LwyvThMl0FIpIAUA6DAJ080Y79Xcfi1QkHOvZi0QkEItMJBQPtwRwiwSBA8dfXl1bg8QIw19eXTPAW4PECMPMzFNVVleLfCQUizeNR2BQVuhM////iUQkHI2HnAAAAFBW6Dv///+L2I1HdFBW6C////+LTCQsg8QYi+iFyXRshdt0aIXtdGSLxwWUAwAAiXgBuMQAAAD/dwwDx2oAUGoE/9GJRCQUhcB1DF9eXbgCAAAAW8IEAGoAaMgAAABqAGoAagD/dxD/dwj/0/90JBSL8P/VhfZ1Cl+NRgNeXVvCBACLRxRfXl1bwgQAX15duAEAAABbwgQA"
            len := StrLen(shellcodeBase64)
            shellcode := Buffer(len * 0.75)
            if !DllCall("crypt32\CryptStringToBinary", "str", shellcodeBase64, "uint", len, "uint", 1, "ptr", shellcode, "uint*", shellcode.Size, "ptr", 0, "ptr", 0)
                return
            return shellcode
        }

        static link(x64, shellcode, shellcodeBase, user32Base, combaseBase, hwnd, tid, msg, &pThreadProc, &pRect) {
            if x64 {
                NumPut("uint64", user32Base, shellcode, 0)
                NumPut("uint64", combaseBase, shellcode, 8)
                NumPut("uint64", hwnd, shellcode, 16)
                NumPut("uint", tid, shellcode, 24)
                NumPut("uint", msg, shellcode, 28)
                pThreadProc := shellcodeBase + 0x4e0
                pRect := shellcodeBase + 56
            }
            else {
                NumPut("uint", user32Base, shellcode, 0)
                NumPut("uint", combaseBase, shellcode, 4)
                NumPut("uint", hwnd, shellcode, 8)
                NumPut("uint", tid, shellcode, 12)
                NumPut("uint", msg, shellcode, 16)
                pThreadProc := shellcodeBase + 0x43c
                pRect := shellcodeBase + 32
            }
        }

        static msgWaitForSingleObject(handle) {
            while 1 == res := DllCall("MsgWaitForMultipleObjects", "uint", 1, "ptr*", handle, "int", false, "uint", -1, "uint", 7423) { ; QS_ALLINPUT := 7423
                msg := Buffer(A_PtrSize == 8 ? 48 : 28)
                while DllCall("PeekMessageW", "ptr", msg, "ptr", 0, "uint", 0, "uint", 0, "uint", 1) { ; PM_REMOVE := 1
                    DllCall("TranslateMessage", "ptr", msg)
                    DllCall("DispatchMessageW", "ptr", msg)
                }
            }
            return res
        }
    }

    static guidFromString(str) {
        DllCall("ole32\CLSIDFromString", "str", str, "ptr", buf := Buffer(16), "hresult")
        return buf
    }

    static getRect(buf, &left, &top, &right, &bottom) {
        left := NumGet(buf, 0, "int")
        top := NumGet(buf, 4, "int")
        right := NumGet(buf, 8, "int")
        bottom := NumGet(buf, 12, "int")
    }

    static getWindowScale(hwnd) {
        if winDpi := DllCall("GetDpiForWindow", "ptr", hwnd, "uint")
            return A_ScreenDPI / winDpi
        return 1
    }

    static scaleRect(scale, &left, &top, &right, &bottom) {
        left := Round(left * scale)
        top := Round(top * scale)
        right := Round(right * scale)
        bottom := Round(bottom * scale)
    }

    static clientToScreenRect(hwnd, &left, &top, &right, &bottom) {
        w := right - left
        h := bottom - top
        pt := left | top << 32
        DllCall("ClientToScreen", "ptr", hwnd, "int64*", &pt)
        left := pt & 0xffffffff
        top := pt >> 32
        right := left + w
        bottom := top + h
    }
}

ActivateJumpMode(mode) {
    global jumpMode, jumpActive, jumpBuffer, jumpPosition, g_inputHook
    
    ; 确保所有坐标模式一致为"Screen"，避免窗口切换导致的坐标偏移
    CoordMode "Mouse", "Screen"
    CoordMode "Caret", "Screen" 
    CoordMode "ToolTip", "Screen"
    
    ; 检查是否是相同的模式，如果是则取消跳转
    if (jumpActive && jumpMode == mode) {
        DeactivateJumpMode()
        return
    }
    
    ; 如果已经激活了不同的模式，则需要先停止当前的输入钩子
    if (jumpActive) {
        ; 停止当前输入钩子
        StopInputHook()
        
        ; 更新模式和清空缓冲区
        jumpMode := mode
        jumpBuffer := ""
    } else {
        ; 如果没有激活任何模式，进行常规的初始化
        jumpMode := mode
        jumpActive := true
        jumpBuffer := ""
    }
    
    ; 获取光标位置
    caretPos := GetCaretPosition()
    
    ; 如果无法获取有效的光标位置，取消跳转
    if (!caretPos) {
        DeactivateJumpMode()
        return
    }
    
    ; 保存光标位置用于显示ToolTip
    jumpPosition.x := caretPos.x
    jumpPosition.y := caretPos.y
    
    ; 显示初始提示
    UpdateJumpTooltip()
    
    ; 不管是首次激活还是切换模式，都重新创建并启动输入钩子
    StartInputHook()
}

UpdateJumpTooltip() {
    global jumpMode, jumpBuffer, jumpPosition
    
    ; 根据模式设置提示文本
    modeText := ""
    modeDefaultDir := "" ; 默认方向提示
    
    if (jumpMode = "up") {
        modeText := "移动"
        modeDefaultDir := "↑"
    }
    else if (jumpMode = "down") {
        modeText := "移动"
        modeDefaultDir := "↓"
    }
    else if (jumpMode = "left") {
        modeText := "移动"
        modeDefaultDir := "←"
    }
    else if (jumpMode = "right") {
        modeText := "移动"
        modeDefaultDir := "→"
    }
    else if (jumpMode = "selectUp") {
        modeText := "选择"
        modeDefaultDir := "↑"
    }
    else if (jumpMode = "selectDown") {
        modeText := "选择"
        modeDefaultDir := "↓"
    }
    else if (jumpMode = "selectLeft") {
        modeText := "选择"
        modeDefaultDir := "←"
    }
    else if (jumpMode = "selectRight") {
        modeText := "选择"
        modeDefaultDir := "→"
    }
    else if (jumpMode = "deleteLeft") {
        modeText := "删除"
        modeDefaultDir := "←"
    }
    else if (jumpMode = "deleteRight") {
        modeText := "删除"
        modeDefaultDir := "→"
    }
    
    ; 显示当前输入
    inputText := jumpBuffer ? jumpBuffer : ""
    
    ; 判断是否有负号
    dirSymbol := modeDefaultDir
    if (inputText && SubStr(inputText, 1, 1) == "-") {
        ; 如果有负号，显示方向已改变
        Switch modeDefaultDir {
            case "↑": dirSymbol := "↓"
            case "↓": dirSymbol := "↑"
            case "←": dirSymbol := "→"
            case "→": dirSymbol := "←"
        }
    }
    
    ; 组合提示文本（添加操作提示）
    tooltipText := ""

    ; 如果是水平方向的跳转或删除且启用了单词级跳转，添加"(按单词)"前缀
    if (isWordJump && (jumpMode == "left" || jumpMode == "right" || 
        jumpMode == "selectLeft" || jumpMode == "selectRight" ||
        jumpMode == "deleteLeft" || jumpMode == "deleteRight")) {
        tooltipText .= "(按单词) "
    }
    
    ; 添加原有的模式文本和方向
    tooltipText .= modeText . " " . dirSymbol . " " . inputText . " (Esc退出)"
    
    ; 显示提示在光标位置右上角
    CoordMode("ToolTip", "Screen")
    ToolTip(tooltipText, jumpPosition.x + 15, jumpPosition.y - 30)
}

DeactivateJumpMode() {
    global jumpActive, g_inputHook, jumpBuffer, isWordJump
    
    ; 停止输入钩子
    StopInputHook()
    
    ; 清除提示
    ToolTip()
    
    ; 重置状态和缓冲区
    jumpActive := false
    jumpBuffer := ""
    isWordJump := false  ; 重置单词跳转标志
}

ExecuteJump() {
    global jumpMode, jumpBuffer
    
    ; 如果输入为空，不执行任何操作
    if (jumpBuffer == "") {
        DeactivateJumpMode()
        return
    }
    
    ; 转换为数字
    jumpCount := 0
    Try {
        ; 检查输入的第一个字符是否是负号
        isNegative := false
        if (SubStr(jumpBuffer, 1, 1) == "-") {
            isNegative := true
            jumpBuffer := SubStr(jumpBuffer, 2)
        }
        
        ; 转换数字部分
        if (jumpBuffer == "")
            jumpCount := 1 ; 如果只输入了负号，假设是1
        else
            jumpCount := Integer(jumpBuffer)
        
        ; 根据模式设置正负
        Switch jumpMode {
            case "up", "left", "selectUp", "selectLeft":
                ; 这些模式默认为负数（向上/向左），负号会反转为正数
                jumpCount := isNegative ? jumpCount : -jumpCount
            case "down", "right", "selectDown", "selectRight":
                ; 这些模式默认为正数（向下/向右），负号会反转为负数
                jumpCount := isNegative ? -jumpCount : jumpCount
        }
    } Catch {
        ; 转换失败，取消操作
        DeactivateJumpMode()
        return
    }
    
    ; 如果输入为0，不执行操作
    if (jumpCount == 0) {
        DeactivateJumpMode()
        return
    }
    
    ; 执行对应操作
    absCount := Abs(jumpCount)

    Switch jumpMode {
        case "up", "down":
            if (jumpCount > 0) {
                MoveDown(absCount)  ; 正数向下
            } else {
                MoveUp(absCount)    ; 负数向上
            }
        case "left", "right":
            if (isWordJump) {
                ; 单词级跳转
                if (jumpCount > 0) {
                    MoveWordRight(absCount) ; 正数向右
                } else {
                    MoveWordLeft(absCount)  ; 负数向左
                }
            } else {
                ; 普通字符级跳转
                if (jumpCount > 0) {
                    MoveRight(absCount) ; 正数向右
                } else {
                    MoveLeft(absCount)  ; 负数向左
                }
            }
        case "selectUp", "selectDown":
            if (jumpCount > 0) {
                SelectDown(absCount) ; 正数向下选择
            } else {
                SelectUp(absCount)   ; 负数向上选择
            }
        case "selectLeft", "selectRight":
            if (isWordJump) {
                ; 单词级选择
                if (jumpCount > 0) {
                    SelectWordRight(absCount) ; 正数向右选择
                } else {
                    SelectWordLeft(absCount)  ; 负数向左选择
                }
            } else {
                ; 普通字符级选择
                if (jumpCount > 0) {
                    SelectRight(absCount) ; 正数向右选择
                } else {
                    SelectLeft(absCount)  ; 负数向左选择
                }
            }
        case "deleteLeft", "deleteRight":
            if (isWordJump) {
                ; 单词级删除
                if (jumpMode = "deleteLeft") {
                    Loop absCount {
                        DeleteWord()  ; 向左删除单词
                    }
                } else {
                    Loop absCount {
                        ForwardDeleteWord() ; 向右删除单词
                    }
                }
            } else {
                ; 字符级删除
                if (jumpMode = "deleteLeft") {
                    DeleteLeft(absCount)  ; 向左删除指定数量字符
                } else {
                    DeleteRight(absCount) ; 向右删除指定数量字符
                }
            }
    }
    
    ; 完成操作后退出跳转模式
    DeactivateJumpMode()
}

StartInputHook() {
    global g_inputHook, jumpBuffer
    
    ; 创建新的InputHook对象
    g_inputHook := InputHook("L0", "{Enter}")
    ; 设置输入结束键
    g_inputHook.EndKeys := "{Enter}"
    ; 设置可接受的按键（只允许数字和负号）
    g_inputHook.KeyOpt("{1}{2}{3}{4}{5}{6}{7}{8}{9}{0}{-}{Numpad1}{Numpad2}{Numpad3}{Numpad4}{Numpad5}{Numpad6}{Numpad7}{Numpad8}{Numpad9}{Numpad0}{NumpadSub}", "N")
    
    ; 设置字符输入回调
    g_inputHook.OnChar := OnChar
    ; 设置结束回调
    g_inputHook.OnEnd := OnInputEnd
    
    ; 启动输入钩子
    try {
        g_inputHook.Start()
    } catch as e {
        ToolTip("InputHook启动失败: " e.Message)
        SetTimer () => ToolTip(), -2000
    }
}

StopInputHook() {
    global g_inputHook
    
    ; 如果输入钩子有效，停止它
    if (IsObject(g_inputHook) && g_inputHook.HasProp("InProgress") && g_inputHook.InProgress)
        g_inputHook.Stop()
}

OnKeyDown(ih, vk, sc) {
    global jumpBuffer
    
    try {
        ; 获取按键名称
        keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
        
        ; 处理退格键 - 删除最后一个字符
        if (keyName == "Backspace") {
            if (jumpBuffer != "") {
                jumpBuffer := SubStr(jumpBuffer, 1, StrLen(jumpBuffer) - 1)
                UpdateJumpTooltip()
            }
            return 1  ; 返回1表示拦截此按键，不让它传递到应用程序
        }
        
        ; 处理回车键 - 执行跳转
        if (keyName == "Enter") {
            ExecuteJump()
            return 1  ; 返回1表示拦截此按键
        }
        
        ; 处理Esc键 - 取消操作
        if (keyName == "Escape") {
            DeactivateJumpMode()
            return 1  ; 返回1表示拦截此按键
        }
    } catch as e {
        ; 捕获错误但不做任何处理，避免中断跳转功能
    }
    
    ; 默认情况下也拦截所有按键
    return 1
}

OnChar(ih, char) {
    global jumpBuffer, isWordJump
    
    try {
        ; 处理0作为单词级跳转触发器
        if (char == "0" && jumpBuffer == "") {
            ; 只有在缓冲区为空时，0才表示单词级跳转
            isWordJump := true
            UpdateJumpTooltip()
            return 1
        }
        
        ; 只接受数字和负号
        if (char >= "0" && char <= "9" || char == "-") {
            ; 添加到缓冲区
            jumpBuffer .= char
            UpdateJumpTooltip()
        }
    } catch as e {
        ; 捕获错误但不做任何处理
    }
    
    ; 拦截所有字符输入
    return 1
}

OnKeyUp(ih, vk, sc) {
    ; 这里可以添加键释放时的操作
}

OnInputEnd(ih) {
    global jumpActive
    
    if (jumpActive) {
        try {
            ; 根据结束原因处理
            if (ih.EndReason == "EndKey") {
                ; 如果是因为按下了Enter，执行跳转
                if (ih.EndKey == "Enter")
                    ExecuteJump()
                ; 如果是因为按下了Escape，取消操作
                else if (ih.EndKey == "Escape")
                    DeactivateJumpMode()
            } else {
                ; 其他原因结束，取消操作
                DeactivateJumpMode()
            }
        } catch as e {
            ; 出错也取消操作
            DeactivateJumpMode()
        }
    }
}

#HotIf jumpActive

; Escape键, Delete键或空格键 - 退出跳转模式
Escape::DeactivateJumpMode()
Delete::DeactivateJumpMode()
CapsLock::DeactivateJumpMode()
~LButton::DeactivateJumpMode()
~RButton::DeactivateJumpMode()
~MButton::DeactivateJumpMode()

; Backspace键 - 删除最后一个字符，如果为空则退出
Backspace:: {
    global jumpBuffer, isWordJump
    
    if (jumpBuffer != "") {
        ; 如果缓冲区不为空，删除最后一个字符
        jumpBuffer := SubStr(jumpBuffer, 1, StrLen(jumpBuffer) - 1)
        UpdateJumpTooltip()
    } else if (isWordJump) {
        ; 如果缓冲区为空但处于单词模式，退回到字符级跳转模式
        isWordJump := false
        UpdateJumpTooltip()
    } else {
        ; 缓冲区为空且不在单词模式，退出跳转模式
        DeactivateJumpMode()
    }
}

; Enter键 - 执行跳转
Enter::ExecuteJump()

#HotIf

#HotIf GetKeyState("CapsLock", "P") && isToolEnabled && !GetKeyState("Alt", "P") && jumpActive
s::Send("")
f::Send("")
e::Send("")
d::Send("")
j::Send("")
l::Send("")
k::Send("")
i::Send("")
,::Send("")
.::Send("")
w::Send("")
r::Send("")
t::Send("")
y::Send("")
u::Send("")
o::Send("")
p::Send("")
a::Send("")
g::Send("")
h::Send("")
z::Send("")
x::Send("")
c::Send("")
v::Send("")
b::Send("")
n::Send("")
m::Send("")
/::Send("")
`;::Send("")
'::Send("")
q::Send("")
[::Send("")
]::Send("")
\::Send("")
#HotIf