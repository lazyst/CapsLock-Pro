; =====================================================================
; CapsLock++ 日志模块
; =====================================================================

LogInfo(tag, msg, extra?) {
    _WriteLog("INFO", tag, msg, extra?)
}

LogWarn(tag, msg, extra?) {
    _WriteLog("WARN", tag, msg, extra?)
}

LogError(tag, msg, extra?) {
    _WriteLog("ERROR", tag, msg, extra?)
}

LogDebug(tag, msg, extra?) {
    _WriteLog("DEBUG", tag, msg, extra?)
}

_WriteLog(level, tag, msg, extra?) {
    try {
        logDir := A_ScriptDir "\logs"
        if !DirExist(logDir)
            DirCreate(logDir)
        logFile := logDir "\debug.log"
        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        extraStr := ""
        if IsSet(extra) && IsObject(extra) {
            for k, v in extra.OwnProps()
                extraStr .= " " k "=" v
        }
        FileAppend(timestamp " [" level "] [" tag "] " msg extraStr "`n", logFile)
    } catch {
    }
}
