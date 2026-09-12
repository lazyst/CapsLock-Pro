using CapsLockPro.Views;

namespace CapsLockPro.Features;

/// <summary>
/// 设置（对应原版 lib/ConfigHelper.ahk）。CapsLock+\ 切换配置窗口；
/// UI 见 <see cref="Views.ConfigHelperWindow"/>，逻辑委托 <see cref="MenuSystem"/> 的 CRUD。
/// </summary>
internal static class ConfigHelper
{
    private static ConfigHelperWindow? _window;
    private static string? _iniPath;

    /// <summary>启动时初始化（记录 INI 路径）。由 App 调用。</summary>
    public static void Initialize(string? iniPath) => _iniPath = iniPath;

    /// <summary>CapsLock+\ 切换：已打开则关闭，否则打开。</summary>
    public static void Toggle()
    {
        if (_window != null)
        {
            _window.Close();
            _window = null;
            return;
        }
        _window = new ConfigHelperWindow(_iniPath ?? "");
        _window.Closed += (_, _) => _window = null;
        _window.Show();
    }
}
