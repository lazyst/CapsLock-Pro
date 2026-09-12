using System.Runtime.InteropServices;
using System.Text;

namespace CapsLockPro.Native;

/// <summary>
/// 文件夹选择对话框（基于 Win32 <c>SHBrowseForFolder</c> + <c>BIF_USENEWUI</c>，
/// 现代可调整大小的树视图）。不依赖 WinForms <c>FolderBrowserDialog</c>。
/// 返回所选文件夹完整路径，用户取消返回 null。
/// </summary>
internal static class FolderPicker
{
    /// <param name="ownerHwnd">父窗口句柄（模态）；传 IntPtr.Zero 则无父。</param>
    /// <param name="title">对话框标题；null 用默认。</param>
    public static string? PickFolder(IntPtr ownerHwnd, string? title = null)
    {
        // pszDisplayName 是对话框写回的输出缓冲（260 wchar）
        IntPtr buf = Marshal.AllocHGlobal(520);
        try
        {
            var bi = new BrowseInfo
            {
                hwndOwner = ownerHwnd,
                pidlRoot = IntPtr.Zero,
                pszDisplayName = buf,
                lpszTitle = title ?? "选择文件夹",
                ulFlags = BifReturnOnlyFsdirs | BifUseNewUi,
            };
            IntPtr pidl = SHBrowseForFolderW(ref bi);
            try
            {
                if (pidl == IntPtr.Zero) return null; // 取消
                var path = new StringBuilder(260);
                bool ok = SHGetPathFromIDListW(pidl, path);
                return ok && path.Length > 0 ? path.ToString() : null;
            }
            finally { CoTaskMemFree(pidl); }
        }
        finally { Marshal.FreeHGlobal(buf); }
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct BrowseInfo
    {
        public IntPtr hwndOwner;
        public IntPtr pidlRoot;
        public IntPtr pszDisplayName; // LPWSTR 输出缓冲（手动 AllocHGlobal）
        public string lpszTitle;      // LPCWSTR 输入标题
        public uint ulFlags;
        public IntPtr lpfn;           // 回调，不用
        public IntPtr lParam;
        public int iImage;
    }

    private const uint BifReturnOnlyFsdirs = 0x00000001; // 只返回文件系统目录
    private const uint BifUseNewUi = 0x00000040;          // 现代可调整大小对话框

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr SHBrowseForFolderW(ref BrowseInfo lpbi);

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern bool SHGetPathFromIDListW(IntPtr pidl, [MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszPath);

    [DllImport("kernel32.dll")]
    private static extern void CoTaskMemFree(IntPtr ptr);
}
