using System.Windows.Forms;
using CapsLockPro.Config;
using CapsLockPro.Core;
using CapsLockPro.Native;

namespace CapsLockPro.Features;

/// <summary>
/// 鼠标模式（对应原版 lib/MouseControl.ahk）。
/// CapsLock+Space 进入；CapsLock+Space 或 Esc 退出。
/// - e/d/s/f 按住持续移动（10ms 循环，对角线归一化，速度 mouseSpeed 1~20）
/// - q/a 调速 ±1（INI 持久化 [MouseMode] Speed）
/// - w/r 左/右键点击
/// - j/k/h/l 按住持续滚轮（50ms 循环，j 下 k 上 h 左 l 右）
/// </summary>
internal static class MouseMode
{
    private static readonly System.Windows.Forms.Timer _moveTimer = new() { Interval = 10 };
    private static readonly System.Windows.Forms.Timer _wheelTimer = new() { Interval = 50 };
    private static int _dx, _dy;        // 当前移动方向 (-1/0/1)
    private static int _wheelDir;      // 0=WheelUp,1=WheelDown,2=WheelLeft,3=WheelRight

    static MouseMode()
    {
        _moveTimer.Tick += (_, _) => MoveLoop();
        _wheelTimer.Tick += (_, _) => WheelLoop();
    }

    /// <summary>进入鼠标模式。</summary>
    public static void Enter()
    {
        AppState.MouseModeActive = true;
        AppState.OtherKeyPressed = true;
        ShowTooltip($"鼠标模式已启用 (速度: {AppState.MouseModeSpeed})");
    }

    /// <summary>退出鼠标模式。</summary>
    public static void Exit()
    {
        AppState.MouseModeActive = false;
        AppState.OtherKeyPressed = true;
        _dx = _dy = 0; _moveTimer.Stop(); _wheelTimer.Stop();
        ShowTooltip("鼠标模式已关闭");
    }

    /// <summary>该键是否为鼠标模式键。</summary>
    public static bool IsMouseKey(ushort vk) => vk switch
    {
        (ushort)'E' or (ushort)'D' or (ushort)'S' or (ushort)'F'  // 移动
        or (ushort)'Q' or (ushort)'A'                              // 速度
        or (ushort)'W' or (ushort)'R'                              // 点击
        or (ushort)'J' or (ushort)'K' or (ushort)'H' or (ushort)'L' // 滚轮
        or (ushort)' ' or (ushort)Win32.VkEscape or (ushort)Win32.VkCapital => true, // Space/Esc 退出
        _ => false,
    };

    /// <summary>处理鼠标模式键。down=true 按下，false 释放。</summary>
    public static void OnKey(ushort vk, bool down)
    {
        switch (vk)
        {
            case (ushort)'E': SetMove('E'); break; // 但多键需独立：用累加
            case (ushort)'D': SetMove('D'); break;
            case (ushort)'S': SetMove('S'); break;
            case (ushort)'F': SetMove('F'); break;
            case (ushort)'Q': if (down) AdjustSpeed(+1); break;
            case (ushort)'A': if (down) AdjustSpeed(-1); break;
            case (ushort)'W': if (down) ClickLeft(); break;
            case (ushort)'R': if (down) ClickRight(); break;
            case (ushort)'J': StartWheel(down, 1); break;
            case (ushort)'K': StartWheel(down, 0); break;
            case (ushort)'H': StartWheel(down, 2); break;
            case (ushort)'L': StartWheel(down, 3); break;
            case (ushort)' ' or (ushort)Win32.VkEscape: if (down) Exit(); break;
        }
    }

    // —— 移动 ——
    // 注：多键同时按需独立方向分量。这里用每键独立判断再 StopMouseMove 兼容多键。
    private static void SetMove(char key)
    {
        // 直接覆盖该键对应分量；其他键仍按 GetAsyncKeyState 实时判断更稳
        // 这里用 GetAsyncKeyState 重算 dx/dy（与 AHK MouseMoveLoop 一致）
        _dx = 0; _dy = 0;
        if ((Win32.GetAsyncKeyState('E') & 0x8000) != 0) _dy -= 1;
        if ((Win32.GetAsyncKeyState('D') & 0x8000) != 0) _dy += 1;
        if ((Win32.GetAsyncKeyState('S') & 0x8000) != 0) _dx -= 1;
        if ((Win32.GetAsyncKeyState('F') & 0x8000) != 0) _dx += 1;
        if (_dx != 0 || _dy != 0) _moveTimer.Start(); else _moveTimer.Stop();
    }

    private static void MoveLoop()
    {
        int dx = 0, dy = 0;
        if ((Win32.GetAsyncKeyState('E') & 0x8000) != 0) dy -= 1;
        if ((Win32.GetAsyncKeyState('D') & 0x8000) != 0) dy += 1;
        if ((Win32.GetAsyncKeyState('S') & 0x8000) != 0) dx -= 1;
        if ((Win32.GetAsyncKeyState('F') & 0x8000) != 0) dx += 1;
        if (dx == 0 && dy == 0) { _moveTimer.Stop(); return; }
        // 对角线归一化
        if (dx != 0 && dy != 0)
        {
            double len = Math.Sqrt(dx * dx + dy * dy);
            dx = (int)Math.Round(dx / len); dy = (int)Math.Round(dy / len);
        }
        if (!Win32.GetCursorPos(out var pt)) return;
        Win32.SetCursorPos(pt.X + dx * AppState.MouseModeSpeed, pt.Y + dy * AppState.MouseModeSpeed);
    }

    // —— 速度 ——
    private static void AdjustSpeed(int delta)
    {
        AppState.MouseModeSpeed = Math.Clamp(AppState.MouseModeSpeed + delta, 1, 20);
        SaveSpeed();
        ShowTooltip("鼠标速度: " + AppState.MouseModeSpeed);
    }

    private static void SaveSpeed()
    {
        var ini = IniPath();
        if (ini != null) IniFile.WriteValue(ini, "MouseMode", "Speed", AppState.MouseModeSpeed.ToString());
    }

    // —— 点击 ——
    private static void ClickLeft() =>
        Win32.mouse_event(Win32.MouseeventfLeftdown | Win32.MouseeventfLeftup, 0, 0, 0, IntPtr.Zero);

    private static void ClickRight() =>
        Win32.mouse_event(Win32.MouseeventfRightdown | Win32.MouseeventfRightup, 0, 0, 0, IntPtr.Zero);

    // —— 滚轮 ——
    private static void StartWheel(bool down, int dir)
    {
        if (!down) { _wheelTimer.Stop(); return; }
        _wheelDir = dir;
        _wheelTimer.Start();
    }

    private static void WheelLoop()
    {
        uint delta = Win32.WheelDelta;
        switch (_wheelDir)
        {
            case 0: Win32.mouse_event(Win32.MouseeventfWheel, 0, 0, delta, IntPtr.Zero); break;       // 上
            case 1: Win32.mouse_event(Win32.MouseeventfWheel, 0, 0, unchecked((uint)-delta), IntPtr.Zero); break; // 下
            case 2: Win32.mouse_event(Win32.MouseeventfHwheel, 0, 0, unchecked((uint)-delta), IntPtr.Zero); break; // 左
            case 3: Win32.mouse_event(Win32.MouseeventfHwheel, 0, 0, delta, IntPtr.Zero); break;      // 右
        }
    }

    private static string? IniPath()
    {
        var dir = AppContext.BaseDirectory;
        // 发布：exe 同目录；开发：向上找仓库根
        var candidates = new[]
        {
            Path.Combine(dir, "CapsLock++.ini"),
            Path.Combine(dir, "..", "..", "..", "..", "..", "CapsLock++.ini"),
        };
        foreach (var p in candidates) if (File.Exists(p)) return p;
        return candidates[0]; // 不存在则创建在 exe 同目录
    }

    private static void ShowTooltip(string msg) =>
        AppState.TrayIcon?.ShowBalloonTip(1000, "CapsLock++", msg, ToolTipIcon.Info);
}
