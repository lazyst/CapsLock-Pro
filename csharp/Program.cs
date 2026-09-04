using System.Runtime.Versioning;
using System.Threading;

namespace CapsLockPro;

/// <summary>
/// 程序入口。阶段0 骨架：单实例互斥体 → 托盘图标 → 消息循环。
/// 后续阶段在此挂载键盘/鼠标钩子（见 <see cref="Hooks.KeyboardHook"/> 等）。
/// </summary>
internal static class Program
{
    /// <summary>命名互斥体，跨会话全局生效，确保仅一个实例运行。</summary>
    private const string SingleInstanceMutexName = @"Global\CapsLockPlusPlus_SingleInstance";

    /// <summary>持有互斥体到进程退出，防止被 GC 回收导致提前释放。</summary>
    private static Mutex? _singleInstanceMutex;

    [STAThread]
    [SupportedOSPlatform("windows")]
    private static void Main()
    {
        // —— 单实例检查 ——
        _singleInstanceMutex = new Mutex(initiallyOwned: true, SingleInstanceMutexName, out bool createdNew);
        if (!createdNew)
        {
            // 第二实例：静默退出（不弹任何 UI，避免干扰）
            return;
        }

        // WinForms 应用配置（高 DPI、默认字体等）
        ApplicationConfiguration.Initialize();

        // 托盘应用上下体承载消息循环
        var context = new TrayAppContext();
        // 阶段1 起在此前后安装低级键盘/鼠标钩子（主线程消息循环泵送）
        try
        {
            Application.Run(context);
        }
        finally
        {
            _singleInstanceMutex?.ReleaseMutex();
        }
    }
}
