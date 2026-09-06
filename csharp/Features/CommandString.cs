using System.Text.RegularExpressions;

namespace CapsLockPro.Features;

/// <summary>
/// 终端命令构造与解析（对应原版 lib/Utils.ahk 的 BuildCommandString / ParseCommandString）。
/// 菜单项动作字符串可带终端前缀（pwsh/powershell/cmd/git bash/wsl bash，可选 Windows Terminal 保持窗口）；
/// <c>direct</c> 终端直接运行原始命令。配置助手的"添加/编辑菜单项"对话框用它构造/回显完整命令。
/// </summary>
internal static class CommandString
{
    /// <summary>终端选项：显示名 → 键。</summary>
    internal static readonly (string display, string key)[] Terminals =
    {
        ("直接运行", "direct"),
        ("PowerShell 7", "pwsh7"),
        ("PowerShell 5", "pwsh5"),
        ("CMD", "cmd"),
        ("Git Bash", "gitbash"),
        ("WSL Bash", "wslbash"),
    };

    /// <summary>构建完整命令字符串。</summary>
    public static string Build(string cmd, string terminal, bool keepWindow)
    {
        if (cmd.Length == 0) return "";
        if (terminal == "direct" || terminal.Length == 0) return cmd;
        return terminal switch
        {
            "pwsh7" => keepWindow ? $"wt pwsh -NoExit -c \"{cmd}\"" : $"pwsh -c \"{cmd}\"",
            "pwsh5" => keepWindow ? $"wt powershell -NoExit -Command \"{cmd}\"" : $"powershell -Command \"{cmd}\"",
            "cmd" => keepWindow ? $"wt cmd /k \"{cmd}\"" : $"cmd /c \"{cmd}\"",
            "gitbash" => keepWindow ? $"wt \"C:\\Program Files\\Git\\bin\\bash.exe\" -c \"{cmd}\""
                                     : $"\"C:\\Program Files\\Git\\bin\\bash.exe\" -c \"{cmd}\"",
            "wslbash" => keepWindow ? $"wt wsl bash -c \"{cmd}\"" : $"wsl bash -c \"{cmd}\"",
            _ => cmd,
        };
    }

    /// <summary>解析动作字符串 → (cmd, terminal, keepWindow)。无匹配视为 direct。</summary>
    public static (string cmd, string terminal, bool keepWindow) Parse(string actionStr)
    {
        if (string.IsNullOrEmpty(actionStr))
            return ("", "direct", false);

        foreach (var (re, term, kw) in Patterns)
        {
            var m = Regex.Match(actionStr, re);
            if (m.Success)
                return (m.Groups[1].Value, term, kw);
        }
        return (actionStr, "direct", false);
    }

    // 对应 ParseCommandString 的 patterns 列表（先 quoted 后 unquoted 兼容旧格式）
    private static readonly (string re, string terminal, bool keepWindow)[] Patterns =
    {
        // Quoted format（新 UI 产出）
        (@"^wt pwsh -NoExit -c ""(.*)""$", "pwsh7", true),
        (@"^wt powershell -NoExit -Command ""(.*)""$", "pwsh5", true),
        (@"^wt cmd /k ""(.*)""$", "cmd", true),
        (@"^wt ""C:\\Program Files\\Git\\bin\\bash\.exe"" -c ""(.*)""$", "gitbash", true),
        (@"^wt wsl bash -c ""(.*)""$", "wslbash", true),
        (@"^pwsh -c ""(.*)""$", "pwsh7", false),
        (@"^powershell -Command ""(.*)""$", "pwsh5", false),
        (@"^cmd /c ""(.*)""$", "cmd", false),
        (@"^""C:\\Program Files\\Git\\bin\\bash\.exe"" -c ""(.*)""$", "gitbash", false),
        (@"^wsl bash -c ""(.*)""$", "wslbash", false),
        // Unquoted format（旧命令，向后兼容）
        (@"^wt pwsh -NoExit -c (.+)$", "pwsh7", true),
        (@"^wt powershell -NoExit -Command (.+)$", "pwsh5", true),
        (@"^wt cmd /k (.+)$", "cmd", true),
        (@"^wt ""C:\\Program Files\\Git\\bin\\bash\.exe"" -c (.+)$", "gitbash", true),
        (@"^wt wsl bash -c (.+)$", "wslbash", true),
        (@"^pwsh -c (.+)$", "pwsh7", false),
        (@"^powershell -Command (.+)$", "pwsh5", false),
        (@"^cmd /c (.+)$", "cmd", false),
        (@"^""C:\\Program Files\\Git\\bin\\bash\.exe"" -c (.+)$", "gitbash", false),
        (@"^wsl bash -c (.+)$", "wslbash", false),
    };
}
