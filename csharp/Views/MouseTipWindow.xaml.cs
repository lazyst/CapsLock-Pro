using System.Runtime.InteropServices;
using System.Windows;
using CapsLockPro.Native;

namespace CapsLockPro.Views;

/// <summary>跟随鼠标右下角的轻量提示文本框（替代系统托盘气球）。
/// 无边框置顶 + 半透明圆角深色背景；按光标位置自动避开屏幕边缘。</summary>
public partial class MouseTipWindow : Window
{
    public MouseTipWindow()
    {
        InitializeComponent();
        // 不抢焦点、不参与 Alt+Tab
        ShowActivated = false;
        Visibility = Visibility.Collapsed;
    }

    /// <summary>设置文本（支持 \n 换行）。</summary>
    public void SetText(string text) => TipText.Text = text;

    /// <summary>定位到光标右下角，避开屏幕右下边缘。</summary>
    public void PlaceNearCursor()
    {
        if (!Win32.GetCursorPos(out var pt)) return;

        // 先测量尺寸（需要曾 Show 过一次才有 ActualWidth/Height；首次用 Estimated）
        double w = ActualWidth > 0 ? ActualWidth : 200;
        double h = ActualHeight > 0 ? ActualHeight : 32;

        double x = pt.X + 16;
        double y = pt.Y + 16;

        // 屏幕工作区避让（多显示器：用光标所在显示器）
        var screen = GetScreenBounds(pt.X, pt.Y);
        if (x + w > screen.Right - 8) x = pt.X - w - 16; // 右溢出→放左侧
        if (x < screen.Left + 8) x = screen.Left + 8;
        if (y + h > screen.Bottom - 8) y = pt.Y - h - 16; // 下溢出→放上方
        if (y < screen.Top + 8) y = screen.Top + 8;

        Left = x;
        Top = y;
    }

    private static (double Left, double Top, double Right, double Bottom) GetScreenBounds(int x, int y)
    {
        var mon = MonitorFromPoint(new POINT { x = x, y = y }, 2 /*MONITOR_DEFAULTTONEAREST*/);
        var mi = new MONITORINFO { cbSize = Marshal.SizeOf<MONITORINFO>() };
        if (GetMonitorInfo(mon, ref mi))
            return (mi.rcWork.left, mi.rcWork.top, mi.rcWork.right, mi.rcWork.bottom);
        // 回退主屏幕
        var wa = SystemParameters.WorkArea;
        return (wa.Left, wa.Top, wa.Right, wa.Bottom);
    }

    private struct POINT { public int x; public int y; }
    private struct RECT { public int left; public int top; public int right; public int bottom; }
    private struct MONITORINFO
    {
        public int cbSize;
        public RECT rcMonitor;
        public RECT rcWork;
        public uint dwFlags;
    }

    [DllImport("user32.dll")]
    private static extern IntPtr MonitorFromPoint(POINT pt, uint dwFlags);

    [DllImport("user32.dll")]
    private static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO lpmi);
}
