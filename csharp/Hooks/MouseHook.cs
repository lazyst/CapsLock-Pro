using System.Runtime.InteropServices;
using CapsLockPro.Core;
using CapsLockPro.Features;
using CapsLockPro.Native;

namespace CapsLockPro.Hooks;

/// <summary>
/// 低级鼠标钩子（WH_MOUSE_LL）。在主线程安装，消息循环泵送。
/// 职责（跟随全局启用开关与 CapsLock 按下态）：
/// - 屏幕底部 5px 滚轮 → 系统音量调节（<see cref="Volume"/>）
/// - CapsLock 按住 + 右键按下 → 切换光标下窗口置顶（<see cref="WindowPin"/>）
/// - CapsLock 按住 + 左键按下 → 资源管理器选中文件重命名（阶段3 补齐）
/// </summary>
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
                        // TODO(阶段3): 资源管理器中 CapsLock+左键 触发选中文件重命名（F2）
                        return (IntPtr)1;
                    }
                    break;
            }
        }
        return Win32.CallNextHookEx(_handle, nCode, wParam, lParam);
    }
}
