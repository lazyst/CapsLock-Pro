using System.Runtime.InteropServices;
using System.Text;
using CapsLockPro.Core;
using CapsLockPro.Features;
using CapsLockPro.Native;

namespace CapsLockPro.Hooks;

/// <summary>
/// 低级鼠标钩子（WH_MOUSE_LL）。在主线程安装，消息循环泵送。
/// 职责（跟随全局启用开关与 CapsLock 按下态）：
/// - 屏幕底部 5px 滚轮 → 系统音量调节（<see cref="Volume"/>）
/// - CapsLock 按住 + 右键按下 → 切换光标下窗口置顶（<see cref="WindowPin"/>）
/// - CapsLock 按住 + 左键按下 → 资源管理器选中文件重命名（F2，对应 lib/Workspace.ahk）
/// </summary>
/// <remarks>
/// 与 <see cref="KeyboardHook"/> 一样，忽略 <see cref="Win32.LlmhfInjected"/> 事件防止递归
/// （自己注入的点击/按键不触发本钩子逻辑）。
/// </remarks>
internal static class MouseHook
{
    private static IntPtr _handle = IntPtr.Zero;
    private static Win32.LowLevelKeyboardProc? _proc; // 签名与 LowLevelMouseProc 兼容
    private static GCHandle _procHandle;

    public static void Install()
    {
        if (_handle != IntPtr.Zero) return;
        _proc = HookCallback;
        _procHandle = GCHandle.Alloc(_proc);
        var hMod = Win32.GetModuleHandle(null);
        _handle = Win32.SetWindowsHookEx(Win32.WhMouseLl, _proc!, hMod, 0);
        if (_handle == IntPtr.Zero)
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "SetWindowsHookEx(WH_MOUSE_LL) 失败");
    }

    public static void Uninstall()
    {
        if (_handle != IntPtr.Zero)
        {
            Win32.UnhookWindowsHookEx(_handle);
            _handle = IntPtr.Zero;
        }
        if (_procHandle.IsAllocated) _procHandle.Free();
        _proc = null;
    }

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode == Win32.HcAction)
        {
            var ms = Marshal.PtrToStructure<Win32.Msllhookstruct>(lParam);

            // 忽略注入事件（防递归：本类注入的左键点击不重新触发重命名）
            if ((ms.Flags & Win32.LlmhfInjected) != 0)
                return Win32.CallNextHookEx(_handle, nCode, wParam, lParam);

            switch ((int)wParam)
            {
                case Win32.WmMousewheel:
                    int delta = (short)((ms.MouseData >> 16) & 0xFFFF);
                    if (Volume.OnWheel(ms.Pt.X, ms.Pt.Y, delta))
                        return (IntPtr)1; // 吞掉滚轮
                    break;

                case Win32.WmRbuttondown:
                    if (AppState.IsToolEnabled && AppState.IsCapsLockDown)
                    {
                        WindowPin.ToggleAtCursor(ms.Pt.X, ms.Pt.Y);
                        return (IntPtr)1; // 吞掉右键，避免弹出系统右键菜单
                    }
                    break;

                case Win32.WmLbuttondown:
                    if (AppState.IsToolEnabled && AppState.IsCapsLockDown)
                    {
                        // 吞掉左键，异步执行点击+重命名（对应 lib/Workspace.ahk LButton 热键）
                        AppState.OtherKeyPressed = true;
                        StartRenameSequence(ms.Pt);
                        return (IntPtr)1;
                    }
                    break;
            }
        }
        return Win32.CallNextHookEx(_handle, nCode, wParam, lParam);
    }

    // —— 资源管理器重命名（对应 lib/Workspace.ahk：LButton / PerformClick / LButtonRenamer）——

    private static void StartRenameSequence(Win32.Point cursorAtTrigger)
    {
        // 触发瞬间捕获前台窗口与光标下窗口的类名（决定是否需要先激活）
        string activeClass = GetWindowClass(Win32.GetForegroundWindow());
        IntPtr mouseWin = Win32.WindowFromPoint(cursorAtTrigger);
        string mouseClass = GetWindowClass(mouseWin);
        bool needActivate = IsExplorerBrowserOwnerCase(activeClass, mouseClass);

        var t = new Thread(() =>
        {
            try
            {
                if (needActivate)
                {
                    // 先激活光标下窗口，再点击，再重命名
                    Win32.SetForegroundWindow(mouseWin);
                    Thread.Sleep(40);
                    DoLeftClick();
                    Thread.Sleep(20);
                    TryRenameUnderCursor();
                }
                else
                {
                    DoLeftClick();
                    Thread.Sleep(20);
                    TryRenameUnderCursor();
                }
            }
            catch { /* 重命名失败静默降级 */ }
        }) { IsBackground = true };
        t.Start();
    }

    /// <summary>注入一次左键点击（mouse_event；注入事件被本钩子忽略，不递归）。</summary>
    private static void DoLeftClick()
    {
        Win32.mouse_event(Win32.MouseeventfLeftdown, 0, 0, 0, IntPtr.Zero);
        Win32.mouse_event(Win32.MouseeventfLeftup, 0, 0, 0, IntPtr.Zero);
    }

    /// <summary>取当前光标下窗口的类名；若为资源管理器/桌面类 → 注入 F2 进入重命名。</summary>
    private static void TryRenameUnderCursor()
    {
        Win32.GetCursorPos(out var pt);
        IntPtr hwnd = Win32.WindowFromPoint(pt);
        if (hwnd == IntPtr.Zero) return;
        string cls = GetWindowClass(hwnd);
        if (cls == "CabinetWClass" || cls == "ExploreWClass" ||
            cls == "Progman" || cls == "WorkerW" || cls == "ExplorerBrowserOwner")
        {
            InputHelper.Tap((ushort)Win32.VkF2);
        }
    }

    private static bool IsExplorerBrowserOwnerCase(string activeClass, string mouseClass)
    {
        bool a = activeClass == "ExplorerBrowserOwner";
        bool m = mouseClass == "ExplorerBrowserOwner";
        return a ^ m; // 恰好一方是 ExplorerBrowserOwner
    }

    private static string GetWindowClass(IntPtr hWnd)
    {
        if (hWnd == IntPtr.Zero) return "";
        var sb = new StringBuilder(256);
        Win32.GetClassName(hWnd, sb, sb.Capacity);
        return sb.ToString();
    }
}
