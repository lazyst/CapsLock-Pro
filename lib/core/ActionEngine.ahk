; =====================================================================
; CapsLock++ 动作引擎
; =====================================================================

ExecuteAction(actionConfig, context) {
    if !IsObject(actionConfig) || !actionConfig.HasOwnProp("type") {
        return { success: false, error: "无效的动作配置" }
    }

    type := actionConfig.type
    params := actionConfig.HasOwnProp("params") ? actionConfig.params : {}

    try {
        switch type {
            case "RunApp":
                path := params.HasOwnProp("path") ? params.path : ""
                workdir := params.HasOwnProp("workdir") ? params.workdir : ""
                if path != "" {
                    if workdir != ""
                        Run(path, workdir)
                    else
                        Run(path)
                    return { success: true, result: "已启动: " path }
                }
                return { success: false, error: "程序路径为空" }

            case "SendKeys":
                keys := params.HasOwnProp("keys") ? params.keys : ""
                if keys != "" {
                    SendInput(keys)
                    return { success: true, result: "已发送按键: " keys }
                }
                return { success: false, error: "按键序列为空" }

            case "SendText":
                text := params.HasOwnProp("text") ? params.text : ""
                if text != "" {
                    SendText(text)
                    return { success: true, result: "已输入文本" }
                }
                return { success: false, error: "文本为空" }

            case "ProcessKill":
                name := params.HasOwnProp("name") ? params.name : ""
                if name != "" {
                    ProcessClose(name)
                    return { success: true, result: "已终止: " name }
                }
                return { success: false, error: "进程名为空" }

            case "Custom":
                code := params.HasOwnProp("code") ? params.code : ""
                if code != "" {
                    ExecuteCustomAction(code)
                    return { success: true, result: "已执行自定义动作" }
                }
                return { success: false, error: "自定义动作为空" }

            case "None":
                return { success: true, result: "无动作" }

            default:
                return { success: false, error: "未知动作类型: " type }
        }
    } catch Error as e {
        return { success: false, error: e.Message }
    }
}

CreateActionContext() {
    return { timestamp: FormatTime(, "yyyy-MM-dd HH:mm:ss") }
}

ActionGetMeta(actionType) {
    metaMap := Map(
        "None", { name: "无动作" },
        "RunApp", { name: "运行程序" },
        "SendKeys", { name: "模拟按键" },
        "SendText", { name: "输入文本" },
        "ProcessKill", { name: "终止进程" },
        "Custom", { name: "自定义动作" }
    )
    return metaMap.Has(actionType) ? metaMap[actionType] : { name: actionType }
}
