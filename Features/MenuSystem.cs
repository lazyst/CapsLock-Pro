using System.Diagnostics;
using System.Text;
using CapsLockPro.Config;
using CapsLockPro.Core;
using CapsLockPro.Native;
using CapsLockPro.Views;

namespace CapsLockPro.Features;

/// <summary>
/// 快捷菜单系统（对应原版 lib/MenuSystem.ahk + lib/ui/MenuUI.ahk）。
/// CapsLock+1~8 显示对应菜单组；CapsLock+9/0 在第 9/10 组为空时发送左右圆括号，
/// 否则显示菜单（见 CHANGELOG v1.1）。菜单内按 1~0 执行对应项，Esc 或点击外部关闭。
/// </summary>
/// <remarks>
/// 配置从 <c>CapsLock++.json</c> 加载（AppConfig）。菜单组为固定 10 槽位数组，
/// 下标对应 CapsLock+1~0；动作字符串按命令行解析执行
/// （exe + 参数，失败回退 ShellExecute 处理 URL/文档）。
/// 钩子回调运行在 UI 线程，故 <see cref="Show"/> 可直接创建 WinForms 窗口（modeless，
/// 非阻塞）。动作执行 spawn 到后台线程（Process.Start 可能阻塞，避免冻 UI）。
/// </remarks>
internal static class MenuSystem
{
    private const int MaxGroups = 10;
    private static readonly MenuGroup?[] _groups = new MenuGroup?[MaxGroups + 1]; // 1-indexed
    private static MenuPopupWindow? _current;
    private static int _currentGroup; // 当前弹出菜单的组索引（供钩子路由选择用）
    private static string? _loadedConfigPath; // 缓存已加载的配置路径，避免重复 IO

    /// <summary>菜单组槽位总数（1..N）。</summary>
    public static int GroupCount => MaxGroups;

    /// <summary>当前是否有菜单弹出。</summary>
    public static bool IsMenuOpen => _current != null;

    /// <summary>从 JSON 加载全部 10 个菜单组。启动时调用一次；相同路径重复调用直接跳过。</summary>
    public static void Load(string? configPath)
    {
        if (configPath == _loadedConfigPath) return; // 已加载，跳过重复 IO
        _loadedConfigPath = configPath;
        var cfg = AppConfig.Load(configPath ?? "");
        TerminalLauncher.LoadFromConfig(cfg);
        for (int i = 1; i <= MaxGroups; i++)
            _groups[i] = FromDto(cfg.MenuGroups.Count >= i ? cfg.MenuGroups[i - 1] : null);
    }

    private static MenuGroup? FromDto(MenuGroupDto? d)
    {
        if (d == null) return null;
        var items = d.Items.Select(FromDto).ToList();
        return items.Count == 0 ? null : new MenuGroup(d.Name, items);
    }

    private static MenuItem FromDto(MenuItemDto d) =>
        new MenuItem(d.Name, d.Cmd, d.Terminal, d.KeepWindow, d.Workdir);

    /// <summary>第 groupIndex 组是否为空（未启用或无项目）。</summary>
    public static bool IsEmpty(int groupIndex) => _groups[groupIndex] == null;

    /// <summary>CapsLock+数字键 派发入口（钩子调用）。</summary>
    public static void Dispatch(ushort vk)
    {
        int group = (vk == '0') ? 10 : (vk - '0'); // '1'..'9' → 1..9, '0' → 10
        // 空组圆括号回退（CHANGELOG v1.1）
        if (group == 9 && IsEmpty(9)) { InputHelper.SendText("("); return; }
        if (group == 10 && IsEmpty(10)) { InputHelper.SendText(")"); return; }
        Show(group);
    }

    /// <summary>显示指定菜单组（已打开的菜单先关闭）。空组为 no-op。</summary>
    public static void Show(int groupIndex)
    {
        CloseCurrent();
        var g = _groups[groupIndex];
        if (g == null) return;
        _currentGroup = groupIndex;
        _current = new MenuPopupWindow(g.Name, groupIndex, g.Items.Select(x => x.Name).ToList());
        _current.Closed += (_, _) => _current = null;
        _current.Show();
    }

    /// <summary>菜单内按键路由（由全局钩子调用，不依赖窗口焦点）：
    /// 数字 1~9/0 → 选第 N 项（超范围→关菜单）；Esc → 关菜单。对齐 AHK #HotIf WinActive(menu) 的数字热键。</summary>
    public static bool HandleMenuKey(ushort vk, bool isDown)
    {
        if (!IsMenuOpen || !isDown) return false;
        if (vk >= '0' && vk <= '9')
        {
            int idx = (vk == '0') ? 10 : (vk - '0');
            var g = _groups[_currentGroup];
            if (g != null && idx >= 1 && idx <= g.Items.Count)
                SelectItem(_currentGroup, idx);
            else
                CloseCurrent();
            return true;
        }
        if (vk == Win32.VkEscape)
        {
            CloseCurrent();
            return true;
        }
        return false;
    }

    /// <summary>关闭当前菜单（若存在）。</summary>
    public static void CloseCurrent()
    {
        if (_current != null)
        {
            try { _current.Close(); } catch { /* 关闭失败静默 */ }
        }
        _current = null;
    }

    /// <summary>执行菜单项并关闭菜单（对应 ExecuteMenuItem + CloseMenu）。</summary>
    public static void SelectItem(int groupIndex, int itemIndex)
    {
        var g = _groups[groupIndex];
        if (g == null || itemIndex < 1 || itemIndex > g.Items.Count) return;
        var item = g.Items[itemIndex - 1];
        CloseCurrent();
        // direct 且空命令 → no-op；其余（含非 direct 仅开 shell）→ 执行
        if (!string.IsNullOrEmpty(item.Cmd) || (item.Terminal != "direct" && item.Terminal.Length != 0))
            Task.Run(() => RunCommand(item));
    }

    /// <summary>按菜单项的终端路由启动进程（direct 走原命令拆分+ShellExecute 回退，其余走 TerminalLauncher）。</summary>
    private static void RunCommand(MenuItem item)
    {
        if (item.Terminal == "direct" || item.Terminal.Length == 0)
        {
            RunDirect(item.Cmd, item.Workdir);
            return;
        }
        var r = TerminalLauncher.TryBuildLaunch(item.Terminal, item.KeepWindow, item.Cmd, item.Workdir);
        if (!r.Ok)
        {
            if (r.Error != null)
            {
                CrashLog.Write("RunCommand", new InvalidOperationException(r.Error));
                ConfirmDialog.Info(null, "CapsLock++", r.Error);
            }
            return;
        }
        try
        {
            var psi = new ProcessStartInfo(r.Exe!)
            {
                UseShellExecute = false,
                CreateNoWindow = false,
            };
            if (!string.IsNullOrEmpty(r.Args)) psi.Arguments = r.Args;
            if (!string.IsNullOrEmpty(r.Workdir) && Directory.Exists(r.Workdir))
                psi.WorkingDirectory = r.Workdir;
            Process.Start(psi);
        }
        catch (Exception ex)
        {
            CrashLog.Write("RunCommand", ex);
        }
    }

    /// <summary>direct 终端：拆 exe+args 启动，失败回退 ShellExecute（URL/文档/含空格非可执行首段）。
    /// 使用 workdir（空则默认桌面）作为工作目录，保证用户设置的工作目录生效。</summary>
    private static void RunDirect(string cmd, string workdir)
    {
        string wd = string.IsNullOrWhiteSpace(workdir)
            ? Environment.GetFolderPath(Environment.SpecialFolder.Desktop)
            : workdir.Trim();
        try
        {
            TrySplitCommandLine(cmd, out string exe, out string args);
            var psi = new ProcessStartInfo(exe)
            {
                UseShellExecute = false,
                CreateNoWindow = false,
            };
            if (!string.IsNullOrEmpty(args)) psi.Arguments = args;
            if (Directory.Exists(wd)) psi.WorkingDirectory = wd;
            Process.Start(psi);
        }
        catch
        {
            try { Process.Start(new ProcessStartInfo(cmd) { UseShellExecute = true, WorkingDirectory = wd }); }
            catch (Exception ex) { CrashLog.Write("MenuRunDirect", ex); }
        }
    }

    /// <summary>命令行拆分：首段（带引号或到空格）为 exe，其余为参数。无空格/无引号→整串为 exe。</summary>
    private static bool TrySplitCommandLine(string cmd, out string exe, out string args)
    {
        cmd = cmd.Trim();
        exe = ""; args = "";
        if (cmd.Length == 0) return false;
        if (cmd[0] == '"')
        {
            int end = cmd.IndexOf('"', 1);
            if (end < 0) { exe = cmd[1..]; return true; }
            exe = cmd[1..end];
            args = cmd[(end + 1)..].Trim();
            return true;
        }
        int sp = cmd.IndexOf(' ');
        if (sp < 0) { exe = cmd; return true; }
        exe = cmd[..sp];
        args = cmd[(sp + 1)..].Trim();
        return true;
    }

    // —— 设置 CRUD（由 Views.ConfigHelperWindow 调用）——

    /// <summary>取得 1..N 的菜单组（可能为 null）。</summary>
    public static MenuGroup? GetGroup(int groupIndex) =>
        (groupIndex >= 1 && groupIndex <= MaxGroups) ? _groups[groupIndex] : null;

    /// <summary>在首个空槽添加菜单组，返回槽位索引；无空槽返回 -1。</summary>
    public static int AddGroup(string name)
    {
        for (int i = 1; i <= MaxGroups; i++)
            if (_groups[i] == null)
            {
                _groups[i] = new MenuGroup(name, new List<MenuItem>());
                return i;
            }
        return -1;
    }

    /// <summary>修改组名（保留原项目）。</summary>
    public static void EditGroup(int groupIndex, string name)
    {
        var g = GetGroup(groupIndex);
        if (g == null) return;
        _groups[groupIndex] = new MenuGroup(name, g.Items);
    }

    /// <summary>删除菜单组（置空槽位）。</summary>
    public static void DeleteGroup(int groupIndex)
    {
        if (groupIndex >= 1 && groupIndex <= MaxGroups) _groups[groupIndex] = null;
    }

    /// <summary>在组末尾添加菜单项。</summary>
    public static void AddItem(int groupIndex, string name, string cmd, string terminal, bool keepWindow, string workdir)
    {
        var g = GetGroup(groupIndex);
        if (g == null) return;
        g.Items.Add(new MenuItem(name, cmd, terminal, keepWindow, workdir));
    }

    /// <summary>修改指定菜单项。</summary>
    public static void EditItem(int groupIndex, int itemIndex, string name, string cmd, string terminal, bool keepWindow, string workdir)
    {
        var g = GetGroup(groupIndex);
        if (g == null || itemIndex < 0 || itemIndex >= g.Items.Count) return;
        g.Items[itemIndex] = new MenuItem(name, cmd, terminal, keepWindow, workdir);
    }

    /// <summary>删除指定菜单项。</summary>
    public static void DeleteItem(int groupIndex, int itemIndex)
    {
        var g = GetGroup(groupIndex);
        if (g == null || itemIndex < 0 || itemIndex >= g.Items.Count) return;
        g.Items.RemoveAt(itemIndex);
        if (g.Items.Count == 0) _groups[groupIndex] = null; // 空组视为不存在
    }

    /// <summary>移动菜单项；delta=-1 上移 / +1 下移；返回是否实际移动。</summary>
    public static bool MoveMenuItem(int groupIndex, int itemIndex, int delta)
    {
        var g = GetGroup(groupIndex);
        if (g == null) return false;
        int ni = itemIndex + delta;
        if (ni < 0 || ni >= g.Items.Count) return false;
        (g.Items[itemIndex], g.Items[ni]) = (g.Items[ni], g.Items[itemIndex]);
        return true;
    }

    /// <summary>从 JSON 重新加载全部组（关闭已开菜单）。</summary>
    public static void ReloadFromConfig(string? configPath)
    {
        _loadedConfigPath = null; // 清除缓存，强制重新加载
        CloseCurrent();
        Load(configPath);
    }

    /// <summary>将当前 10 个组写回 JSON（读现有配置→替换菜单部分→整体写回，保留终端/鼠标等其它配置）。</summary>
    public static void SaveToConfig(string configPath)
    {
        var cfg = AppConfig.Load(configPath);
        cfg.MenuGroups = new List<MenuGroupDto?>();
        for (int i = 1; i <= MaxGroups; i++)
            cfg.MenuGroups.Add(ToDto(_groups[i]));
        cfg.Save(configPath);
    }

    private static MenuGroupDto? ToDto(MenuGroup? g)
    {
        if (g == null) return null;
        return new MenuGroupDto
        {
            Enabled = true,
            Name = g.Name,
            Items = g.Items.Select(ToDto).ToList(),
        };
    }

    private static MenuItemDto ToDto(MenuItem it) => new MenuItemDto
    {
        Name = it.Name,
        Cmd = it.Cmd,
        Terminal = it.Terminal,
        KeepWindow = it.KeepWindow,
        Workdir = it.Workdir,
    };

    // —— 数据模型 ——
    internal sealed class MenuGroup
    {
        public string Name { get; }
        public List<MenuItem> Items { get; }
        public MenuGroup(string name, List<MenuItem> items) { Name = name; Items = items; }
    }

    internal sealed class MenuItem
    {
        public string Name { get; }
        public string Cmd { get; }           // 原始命令（不再 bake 终端信息）
        public string Terminal { get; }      // direct/pwsh7/pwsh5/cmd/gitbash/wslbash
        public bool KeepWindow { get; }
        public string Workdir { get; }       // 空则执行时默认桌面
        public MenuItem(string name, string cmd, string terminal, bool keepWindow, string workdir)
        { Name = name; Cmd = cmd; Terminal = terminal; KeepWindow = keepWindow; Workdir = workdir ?? ""; }
    }
}

