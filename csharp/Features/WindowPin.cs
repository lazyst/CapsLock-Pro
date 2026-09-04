using System.Runtime.InteropServices;
using CapsLockPro.Core;
using CapsLockPro.Native;

namespace CapsLockPro.Features;

/// <summary>
/// 窗口置顶（对应原版 lib/WindowPin.ahk）。CapsLock+右键 切换光标下窗口置顶/取消。
/// - 桌面窗口（Progman/WorkerW）、任务栏窗口不置顶
/// - 全屏窗口首次提示，再次操作强制置顶（防误触）
/// </summary>
internal static class WindowPin
{
    private const int GwlExstyle = -20;
    private const int WsExTopmost = 0x8;
    private static readonly IntPtr HwndTopmost = new(-1);
    private static readonly IntPtr HwndNoTopmost = new(-2);
    private const uint SwpNosize = 0x0001;
    private const uint SwpNomove = 0x0002;

    // 全屏双重确认状态：hwnd → 上次警告时间(TickCount)
    private static readonly Dictionary<IntPtr, int> _fullscreenWarn = new();

    /// <summary>切换光标下窗口置顶状态。</summary>
    public static void ToggleAtCursor(int x, int y)
    {
        var hwnd = WindowFromPointPoint(x, y);
        if (hwnd == IntPtr.Zero) { ShowTooltip("光标下无有效窗口"); return; }
        if (!IsTaskbarWindow(hwnd)) { ShowTooltip("当前窗口不是任务栏窗口，无法置顶"); return; }

        var className = GetClassNameStr(hwnd);
        if (className is "Progman" or "WorkerW") { ShowTooltip("桌面窗口不能置顶"); return; }

        bool isPinned = (GetWindowLong(hwnd, GwlExstyle) & WsExTopmost) != 0;
        bool isFull = IsWindowFullScreen(hwnd);

        if (isPinned)
        {
            Win32.SetWindowPos(hwnd, HwndNoTopmost, 0, 0, 0, 0, SwpNomove | SwpNosize);
            ShowTooltip("已取消置顶");
        }
        else
        {
            if (isFull)
            {
                int now = Environment.TickCount;
                if (_fullscreenWarn.TryGetValue(hwnd, out int last) && now - last < 3000)
                {
                    Win32.SetWindowPos(hwnd, HwndTopmost, 0, 0, 0, 0, SwpNomove | SwpNosize);
                    _fullscreenWarn.Remove(hwnd);
                    ShowTooltip("已强制置顶全屏窗口");
                }
                else
                {
                    _fullscreenWarn[hwnd] = now;
                    ShowTooltip("全屏窗口不建议置顶\n(再次操作将强制置顶)");
                }
                return;
            }
            Win32.SetWindowPos(hwnd, HwndTopmost, 0, 0, 0, 0, SwpNomove | SwpNosize);
            ShowTooltip("已置顶窗口");
        }
    }

    private static bool IsTaskbarWindow(IntPtr hwnd)
    {
        // 简化：排除纯工具窗口（不可见的辅助窗口）与桌面。
        // 原版 IsTaskbarWindow 检查 WS_EX_TOOLWINDOW 等，这里用可见性 + 类名粗筛。
        var ex = GetWindowLong(hwnd, GwlExstyle);
        if ((ex & 0x80) != 0) return false; // WS_EX_TOOLWINDOW
        return true;
    }

    private static bool IsWindowFullScreen(IntPtr hwnd)
    {
        // 最大化 OR 占据整个工作区/全屏
        var monitor = MonitorFromWindow(hwnd, 2 /*MONITOR_DEFAULTTONEAREST*/);
        if (monitor == IntPtr.Zero) return false;
        var mi = new MonitorInfo { cbSize = Marshal.SizeOf<MonitorInfo>() };
        if (!GetMonitorInfo(monitor, ref mi)) return false;

        Win32.GetWindowRect(hwnd, out var r);
        bool maximized = (GetWindowLong(hwnd, -16 /*GWL_STYLE*/) & 0x01000000 /*WS_MAXIMIZE*/) != 0;
        bool coversWork = Math.Abs(r.Left - mi.rcWorkLeft) <= 1 && Math.Abs(r.Top - mi.rcWorkTop) <= 1 &&
                          Math.Abs(r.Right - mi.rcWorkRight) <= 1 && Math.Abs(r.Bottom - mi.rcWorkBottom) <= 1;
        return maximized || coversWork;
    }

    private static string GetClassNameStr(IntPtr hwnd)
    {
        var sb = new System.Text.StringBuilder(256);
        Win32.GetClassName(hwnd, sb, sb.Capacity);
        return sb.ToString();
    }

    private static void ShowTooltip(string msg) =>
        AppState.TrayIcon?.ShowBalloonTip(2000, "CapsLock++", msg, ToolTipIcon.Info);

    [DllImport("user32.dll")]
    private static extern IntPtr WindowFromPoint(int x, int y);

    [DllImport("user32.dll")]
    private static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint dwFlags);

    [DllImport("user32.dll")]
    private static extern bool GetMonitorInfo(IntPtr hMonitor, ref MonitorInfo lpmi);

    [DllImport("user32.dll")]
    private static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll")]
    private static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    [StructLayout(LayoutKind.Sequential)]
    private struct MonitorInfo
    {
        public int cbSize;
        public int rcMonitorLeft, rcMonitorTop, rcMonitorRight, rcMonitorBottom;
        public int rcWorkLeft, rcWorkTop, rcWorkRight, rcWorkBottom;
        public uint dwFlags;
    }

    private static IntPtr WindowFromPointPoint(int x, int y) => WindowFromPoint(x, y);
}
