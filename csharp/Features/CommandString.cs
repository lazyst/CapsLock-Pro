namespace CapsLockPro.Features;

/// <summary>终端选项元数据（显示名 ↔ 键），供编辑对话框下拉与运行时路由共用。</summary>
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
}
