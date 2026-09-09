using System.Windows;
using H.NotifyIcon;

namespace CapsLockPro.Core;

/// <summary>
/// 托盘气球提示服务（替代旧 <c>AppState.TrayIcon?.ShowBalloonTip</c>）。
/// 功能模块（速记/配置助手等）通过本类显示提示，不直接依赖 <see cref="TaskbarIcon"/>。
/// </summary>
internal static class TrayService
{
    private static TaskbarIcon? _tray;

    /// <summary>由 App 启动时注入托盘图标实例。</summary>
    public static void Init(TaskbarIcon tray) => _tray = tray;

    /// <summary>显示气球提示（失败静默，不干扰主流程）。</summary>
    public static void ShowBalloon(string message)
    {
        if (_tray == null) return;
        try { _tray.ShowNotification("CapsLock++", message); }
        catch { /* 静默 */ }
    }

    /// <summary>WPF MessageBox 封装（统一标题）。</summary>
    public static MessageBoxResult Confirm(string message, string title)
        => MessageBox.Show(message, title, MessageBoxButton.YesNo, MessageBoxImage.Question);
}
