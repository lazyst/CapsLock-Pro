using System.Runtime.InteropServices;

namespace CapsLockPro.Native;

/// <summary>
/// 文件夹选择对话框，封装 <c>System.Windows.Forms.FolderBrowserDialog</c>。
/// .NET 8 的 FolderBrowserDialog 内部走 COM <c>IFileOpenDialog</c> + <c>FOS_PICKFOLDERS</c>，
/// 即 Windows 资源管理器同款 UI（左侧含「快速访问」/ 导航栏、可输入路径、最近访问等），
/// 自动适配各 Windows 版本的 broker 化差异（经典 CLSID 在新版已 broker 化，手写易碎）。
/// 返回所选文件夹完整路径，用户取消返回 null。
/// </summary>
internal static class FolderPicker
{
    /// <param name="ownerHwnd">父窗口句柄（模态）；传 IntPtr.Zero 则无父。</param>
    /// <param name="title">对话框描述文字；null 用默认。</param>
    public static string? PickFolder(IntPtr ownerHwnd, string? title = null)
    {
        // 用全限定名避免与 WPF 同名类型歧义（WinForms 与 WPF 在本项目的别名见 GlobalUsings.cs）
        var dlg = new System.Windows.Forms.FolderBrowserDialog
        {
            Description = title ?? "选择文件夹",
            ShowNewFolderButton = true,
            UseDescriptionForTitle = true,
            AutoUpgradeEnabled = true,
        };

        // 旧版 FolderBrowserDialog 选 Win32 IWin32Window 包装父窗口句柄
        var owner = ownerHwnd != IntPtr.Zero ? new HandleWrapper(ownerHwnd) : null;
        var result = dlg.ShowDialog(owner);
        return result == System.Windows.Forms.DialogResult.OK && !string.IsNullOrWhiteSpace(dlg.SelectedPath)
            ? dlg.SelectedPath
            : null;
    }

    /// <summary>把 IntPtr 句柄包成 IWin32Window，供 FolderBrowserDialog 做模态父窗口。</summary>
    private sealed class HandleWrapper : System.Windows.Forms.IWin32Window
    {
        private readonly IntPtr _handle;
        public HandleWrapper(IntPtr handle) => _handle = handle;
        public IntPtr Handle => _handle;
    }
}
