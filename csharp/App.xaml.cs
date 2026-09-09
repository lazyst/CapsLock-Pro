using System.ComponentModel;
using System.IO;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;
using CapsLockPro.Core;
using CapsLockPro.Features;
using CapsLockPro.Hooks;
using H.NotifyIcon;

namespace CapsLockPro;

/// <summary>
/// WPF 应用入口（替代旧 WinForms <c>TrayAppContext</c>）。
/// OnStartup：单实例互斥体 → H.NotifyIcon 托盘 → 装/卸钩子 → 初始化菜单/速记/配置助手 → 看门狗。
/// 主 STA 线程由 WPF Dispatcher 泵送，低级键盘/鼠标钩子回调仍在本线程派发（模型不变）。
/// </summary>
public partial class App : Application
{
    private const string SingleInstanceMutexName = @"Global\CapsLockPlusPlus_SingleInstance";
    private static Mutex? _singleInstanceMutex;

    private TaskbarIcon? _tray;
    private DispatcherTimer? _watchdog;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // —— UI 线程未捕获异常兑底：记录到崩溃日志并吞掉（常驻输入工具不因单次异常退出）——
        DispatcherUnhandledException += App_DispatcherUnhandledException;

        // —— 单实例 ——
        _singleInstanceMutex = new Mutex(initiallyOwned: true, SingleInstanceMutexName, out bool createdNew);
        if (!createdNew)
        {
            Shutdown(0);
            return;
        }

        // —— 托盘 ——
        BuildTray();

        // 启动确保 CapsLock 灯灭
        CapsLockStateMachine.EnsureLightOff();

        // —— 看门狗（对应 AHK CheckCapsLockState，2s）——
        _watchdog = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2) };
        _watchdog.Tick += (_, _) => CapsLockStateMachine.WatchdogTick();
        _watchdog.Start();

        // —— 钩子（主线程安装，Dispatcher 泵送）——
        try { KeyboardHook.Install(); }
        catch (Win32Exception ex) { System.Diagnostics.Debug.WriteLine($"键盘钩子失败: {ex.Message}"); }
        try { MouseHook.Install(); }
        catch (Win32Exception ex) { System.Diagnostics.Debug.WriteLine($"鼠标钩子失败: {ex.Message}"); }

        // —— 加载配置 ——
        var iniPath = FindIniPath();
        MenuSystem.Load(iniPath);
        QuickNote.Initialize(iniPath);
        ConfigHelper.Initialize(iniPath);
    }

    private void BuildTray()
    {
        var menu = new ContextMenu();
        menu.Items.Add(NewItem("帮助面板 (CapsLock+`)", () => HelpPanel.Toggle()));
        menu.Items.Add(NewItem("速记 (CapsLock+N)", () => QuickNote.Toggle()));
        menu.Items.Add(NewItem("配置助手 (CapsLock+\\)", () => ConfigHelper.Toggle()));
        menu.Items.Add(new Separator());
        menu.Items.Add(NewItem("退出 CapsLock++", ExitApplication));

        _tray = new TaskbarIcon
        {
            ToolTipText = "CapsLock++",
            IconSource = LoadIconSource(),
            ContextMenu = menu,
        };
        TrayService.Init(_tray);
        _tray.ForceCreate();
    }

    private static MenuItem NewItem(string header, Action onClick)
    {
        var mi = new MenuItem { Header = header };
        mi.Click += (_, _) => onClick();
        return mi;
    }

    private static System.Windows.Media.ImageSource? LoadIconSource()
    {
        var candidates = new[]
        {
            Path.Combine(AppContext.BaseDirectory, "Icon", "CapsLock++.ico"),
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "Icon", "CapsLock++.ico"),
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "Icon", "CapsLock++.ico"),
        };
        foreach (var p in candidates)
        {
            try
            {
                if (File.Exists(p))
                    return new System.Windows.Media.Imaging.BitmapImage(new Uri(p));
            }
            catch { /* 尝试下一个 */ }
        }
        return null;
    }

    private void App_DispatcherUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        CrashLog.Write("Dispatcher", e.Exception);
        e.Handled = true;
    }

    private void ExitApplication()
    {
        _watchdog?.Stop();
        KeyboardHook.Uninstall();
        MouseHook.Uninstall();
        _tray?.Dispose();
        _singleInstanceMutex?.ReleaseMutex();
        Shutdown();
    }

    /// <summary>定位 CapsLock++.ini（发布=exe 同级，开发=上溯仓库根）。</summary>
    private static string? FindIniPath()
    {
        var candidates = new[]
        {
            Path.Combine(AppContext.BaseDirectory, "CapsLock++.ini"),
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "CapsLock++.ini"),
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "CapsLock++.ini"),
        };
        foreach (var p in candidates)
            if (File.Exists(p)) return p;
        return null;
    }
}
