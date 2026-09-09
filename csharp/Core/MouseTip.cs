using System.Windows;
using System.Windows.Threading;
using CapsLockPro.Views;

namespace CapsLockPro.Core;

/// <summary>
/// 跟随鼠标的提示文本框（替代系统托盘气球，对应原版 AHK <c>ToolTip</c> + <c>SetTimer(() =&gt; ToolTip(), -N)</c>）。
/// 在光标右下角显示一段文字，约 1.8s 后自动隐藏；可从任意线程调用（自动 marshal 到 UI 线程）。
/// </summary>
internal static class MouseTip
{
    private const int DefaultDurationMs = 1800;
    private static MouseTipWindow? _window;
    private static DispatcherTimer? _timer;

    /// <summary>显示提示文本（支持 \n 换行）。</summary>
    public static void Show(string text, int durationMs = DefaultDurationMs)
    {
        var disp = Application.Current?.Dispatcher;
        if (disp == null) return;
        if (!disp.CheckAccess())
            disp.BeginInvoke(() => ShowCore(text, durationMs));
        else
            ShowCore(text, durationMs);
    }

    private static void ShowCore(string text, int durationMs)
    {
        _timer?.Stop();

        _window ??= new MouseTipWindow();
        _window.SetText(text);

        // 先 Show 一次以完成 measure（拿真实尺寸定位），随后放置并置可见。
        _window.Visibility = Visibility.Visible;
        _window.PlaceNearCursor();
        _window.Show();

        _timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(durationMs) };
        _timer.Tick += (_, _) =>
        {
            _timer?.Stop();
            try { _window?.Hide(); } catch { /* 静默 */ }
        };
        _timer.Start();
    }
}
