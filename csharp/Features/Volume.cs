using CapsLockPro.Core;
using CapsLockPro.Native;

namespace CapsLockPro.Features;

/// <summary>
/// 屏幕底部滚轮调音量（对应原版 lib/VolumeControl.ahk）。
/// 鼠标位于屏幕底部 5px 内滚动滚轮 → 系统音量 ±2（每格）。跟随全局启用开关。
/// </summary>
internal static class Volume
{
    private const int BottomMargin = 5; // 底部 5px 触发
    private const int Step = 2;         // 每格步长（与原版一致）

    /// <summary>处理一次滚轮事件。返回 true 表示已消费（吞掉滚轮）。</summary>
    public static bool OnWheel(int x, int y, int delta)
    {
        if (!AppState.IsToolEnabled) return false;
        int screenH = ScreenHeight();
        if (screenH - y > BottomMargin) return false; // 不在底部 5px 内，放行
        int steps = Math.Sign(delta);
        for (int i = 0; i < Step; i++)
        {
            InputHelper.Tap((ushort)(steps > 0 ? Win32.VkVolumeUp : Win32.VkVolumeDown));
        }
        return true;
    }

    private static int ScreenHeight()
    {
        var hdc = GetDC(IntPtr.Zero);
        int h = GetDeviceCaps(hdc, 10 /*VERTRES*/);
        ReleaseDC(IntPtr.Zero, hdc);
        return h;
    }

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern IntPtr GetDC(IntPtr hWnd);

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern int ReleaseDC(IntPtr hWnd, IntPtr hdc);

    [System.Runtime.InteropServices.DllImport("gdi32.dll")]
    private static extern int GetDeviceCaps(IntPtr hdc, int nIndex);
}
