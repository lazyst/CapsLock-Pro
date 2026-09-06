using System.ComponentModel;
using System.Drawing;
using System.Reflection;
using System.Windows.Forms;
using CapsLockPro.Core;
using CapsLockPro.Features;
using CapsLockPro.Hooks;

namespace CapsLockPro;

/// <summary>
/// 托盘应用上下体（阶段0）。承载 <see cref="NotifyIcon"/> + 右键菜单，
/// 驱动 <see cref="Application.Run"/> 消息循环（钩子线程的主循环由此泵送）。
/// </summary>
internal sealed class TrayAppContext : ApplicationContext
{
    private readonly NotifyIcon _notifyIcon;
    private readonly System.Windows.Forms.Timer _watchdog;

    public TrayAppContext()
    {
        _notifyIcon = new NotifyIcon
        {
            Icon = LoadAppIcon(),
            Text = "CapsLock++",
            Visible = true,
            ContextMenuStrip = BuildMenu(),
        };
        // 阶段0 占位：双击托盘图标 打开帮助面板（原占位为退出，退出见右键菜单）
        _notifyIcon.DoubleClick += (_, _) => HelpPanel.Toggle();

        // 暴露托盘图标给状态机/功能模块（显示气球提示）
        AppState.TrayIcon = _notifyIcon;

        // 启动时确保 CapsLock 灯灭
        CapsLockStateMachine.EnsureLightOff();
        // 看门狗定时器（2s，对应 AHK CheckCapsLockState）
        _watchdog = new System.Windows.Forms.Timer { Interval = 2000 };
        _watchdog.Tick += (_, _) => CapsLockStateMachine.WatchdogTick();
        _watchdog.Start();

        // 阶段1：安装低级键盘钩子（主线程消息循环泵送）
        try { KeyboardHook.Install(); }
        catch (Win32Exception ex) { System.Diagnostics.Debug.WriteLine($"键盘钩子失败: {ex.Message}"); }
        // 阶段2：安装低级鼠标钩子（音量/置顶/重命名）
        try { MouseHook.Install(); }
        catch (Win32Exception ex) { System.Diagnostics.Debug.WriteLine($"鼠标钩子失败: {ex.Message}"); }

        // 阶段4：从 CapsLock++.ini 加载菜单组配置
        MenuSystem.Load(FindIniPath());
        // 阶段5：初始化速记（默认目录 + 目标加载 + 建目录）
        QuickNote.Initialize(FindIniPath());
        // 阶段5：初始化配置助手（INI 路径）
        ConfigHelper.Initialize(FindIniPath());
    }

    /// <summary>构建托盘右键菜单。后续阶段会扩展（启用/禁用、帮助、速记等）。</summary>
    private ContextMenuStrip BuildMenu()
    {
        var menu = new ContextMenuStrip();
        // 退出项：先隐藏托盘再退出，避免图标残留
        menu.Items.Add("帮助面板 (CapsLock+`)", image: null, (_, _) => HelpPanel.Toggle());
        menu.Items.Add("速记 (CapsLock+N)", image: null, (_, _) => QuickNote.Toggle());
        menu.Items.Add("配置助手 (CapsLock+\\)", image: null, (_, _) => ConfigHelper.Toggle());
        menu.Items.Add("-", image: null, null);
        menu.Items.Add("退出 CapsLock++", image: null, (_, _) => ExitApplication());
        return menu;
    }

    /// <summary>退出应用：隐藏托盘图标后调用 Application.Exit。</summary>
    private void ExitApplication()
    {
        _notifyIcon.Visible = false;
        Application.Exit();
    }

    /// <summary>
    /// 加载托盘图标：优先 exe 同目录 <c>Icon/CapsLock++.ico</c>，
    /// 失败回退向上查找（开发期 exe 在 bin/Debug/... 下），
    /// 仍失败用系统默认应用图标。
    /// </summary>
    private static Icon LoadAppIcon()
    {
        var candidates = new[]
        {
            // 发布：exe 同目录 Icon\CapsLock++.ico
            Path.Combine(AppContext.BaseDirectory, "Icon", "CapsLock++.ico"),
            // 开发：从 bin/<cfg>/<tfm>/ 向上找仓库根 Icon\
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "Icon", "CapsLock++.ico"),
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "Icon", "CapsLock++.ico"),
        };
        foreach (var p in candidates)
        {
            try
            {
                if (File.Exists(p))
                    return new Icon(p, 32, 32);
            }
            catch { /* 忽略单个候选失败，尝试下一个 */ }
        }
        return SystemIcons.Application;
    }

    /// <summary>
    /// 定位 CapsLock++.ini：先 exe 同目录（发布），再向上若干级查找（开发期 exe 在 bin/Debug 下）。
    /// </summary>
    private static string? FindIniPath()
    {
        var candidates = new[]
        {
            Path.Combine(AppContext.BaseDirectory, "CapsLock++.ini"),
            // 开发：bin/Debug/net8.0-windows → 上溯 4 级到仓库根
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "CapsLock++.ini"),
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "CapsLock++.ini"),
        };
        foreach (var p in candidates)
            if (File.Exists(p)) return p;
        return null;
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _watchdog?.Stop();
            _watchdog?.Dispose();
            KeyboardHook.Uninstall();
            MouseHook.Uninstall();
            _notifyIcon.Visible = false;
            _notifyIcon.Dispose();
        }
        base.Dispose(disposing);
    }
}
