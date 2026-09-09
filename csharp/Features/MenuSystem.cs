using System.Diagnostics;
using System.Text;
using CapsLockPro.Config;
using CapsLockPro.Native;
using CapsLockPro.Views;

namespace CapsLockPro.Features;

/// <summary>
/// 快捷菜单系统（对应原版 lib/MenuSystem.ahk + lib/ui/MenuUI.ahk）。
/// CapsLock+1~8 显示对应菜单组；CapsLock+9/0 在第 9/10 组为空时发送左右圆括号，
/// 否则显示菜单（见 CHANGELOG v1.1）。菜单内按 1~0 执行对应项，Esc 或点击外部关闭。
/// </summary>
/// <remarks>
/// 配置从 <c>CapsLock++.ini</c> 加载：[MenuGroupsEnable]/[MenuGroupName]/
/// [MenuGroupCount]/[MenuGroups{N}Items](name+action)。动作字符串按命令行解析执行
/// （exe + 参数，失败回退 ShellExecute 处理 URL/文档）。
/// 钩子回调运行在 UI 线程，故 <see cref="Show"/> 可直接创建 WinForms 窗口（modeless，
/// 非阻塞）。动作执行 spawn 到后台线程（Process.Start 可能阻塞，避免冻 UI）。
/// </remarks>
internal static class MenuSystem
{
    private const int MaxGroups = 10;
    private static readonly MenuGroup?[] _groups = new MenuGroup?[MaxGroups + 1]; // 1-indexed
    private static MenuPopupWindow? _current;

    /// <summary>菜单组槽位总数（1..N）。</summary>
    public static int GroupCount => MaxGroups;

    /// <summary>从 INI 加载全部 10 个菜单组（启动时调用一次）。</summary>
    public static void Load(string? iniPath)
    {
        for (int i = 1; i <= MaxGroups; i++)
            _groups[i] = LoadGroup(iniPath, i);
    }

    private static MenuGroup? LoadGroup(string? iniPath, int idx)
    {
        if (string.IsNullOrEmpty(iniPath) || !File.Exists(iniPath))
            return null;

        string enabled = IniFile.ReadValue(iniPath, "MenuGroupsEnable", "enableGroup" + idx) ?? "true";
        if (!enabled.Equals("true", StringComparison.OrdinalIgnoreCase))
            return null; // 禁用组视为空

        string name = IniFile.ReadValue(iniPath, "MenuGroupName", "name" + idx) ?? ("菜单组 " + idx);
        int count = int.TryParse(IniFile.ReadValue(iniPath, "MenuGroupCount", "count" + idx), out var c) ? c : 0;

        var items = new List<MenuItem>();
        string section = "MenuGroups" + idx + "Items";
        for (int j = 1; j <= count; j++)
        {
            string iname = IniFile.ReadValue(iniPath, section, "name" + j) ?? "";
            if (iname.Length == 0) continue;
            string action = IniFile.ReadValue(iniPath, section, "action" + j) ?? "";
            items.Add(new MenuItem(iname, action));
        }
        if (items.Count == 0) return null;
        return new MenuGroup(name, items);
    }

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
        _current = new MenuPopupWindow(g.Name, groupIndex, g.Items.Select(x => x.Name).ToList());
        _current.Closed += (_, _) => _current = null;
        _current.Show();
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
        string action = g.Items[itemIndex - 1].Action;
        CloseCurrent();
        if (!string.IsNullOrEmpty(action))
            Task.Run(() => RunCommand(action));
    }

    /// <summary>解析命令行并启动进程（对应 AHK Run / RunCommand）。</summary>
    private static void RunCommand(string cmd)
    {
        try
        {
            TrySplitCommandLine(cmd, out string exe, out string args);
            var psi = new ProcessStartInfo(exe)
            {
                UseShellExecute = false,
                CreateNoWindow = false,
            };
            if (!string.IsNullOrEmpty(args)) psi.Arguments = args;
            Process.Start(psi);
        }
        catch
        {
            // 回退 ShellExecute（URL / 文档路径 / 含空格且非可执行的首段）
            try { Process.Start(new ProcessStartInfo(cmd) { UseShellExecute = true }); }
            catch (Exception ex) { Debug.WriteLine($"菜单动作执行失败: {cmd} - {ex.Message}"); }
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

    // —— 配置助手 CRUD（由 Views.ConfigHelperWindow 调用）——

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
    public static void AddItem(int groupIndex, string name, string cmd, string terminal, bool keepWindow)
    {
        var g = GetGroup(groupIndex);
        if (g == null) return;
        g.Items.Add(new MenuItem(name, CommandString.Build(cmd, terminal, keepWindow)));
    }

    /// <summary>修改指定菜单项。</summary>
    public static void EditItem(int groupIndex, int itemIndex, string name, string cmd, string terminal, bool keepWindow)
    {
        var g = GetGroup(groupIndex);
        if (g == null || itemIndex < 0 || itemIndex >= g.Items.Count) return;
        g.Items[itemIndex] = new MenuItem(name, CommandString.Build(cmd, terminal, keepWindow));
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

    /// <summary>从 INI 重新加载全部组。</summary>
    public static void ReloadFromIni(string? iniPath)
    {
        CloseCurrent();
        Load(iniPath);
    }

    /// <summary>将当前 10 个组写回 INI（整体重写菜单相关 section）。</summary>
    public static void SaveToIni(string iniPath)
    {
        string? dir = Path.GetDirectoryName(iniPath);
        if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            Directory.CreateDirectory(dir);

        for (int i = 1; i <= MaxGroups; i++)
        {
            string itemsSection = "MenuGroups" + i + "Items";
            try { IniFile.DeleteSection(iniPath, itemsSection); } catch { /* 静默 */ }
            var g = _groups[i];
            if (g == null || g.Items.Count == 0)
            {
                IniFile.WriteValue(iniPath, "MenuGroupsEnable", "enableGroup" + i, "false");
                IniFile.WriteValue(iniPath, "MenuGroupName", "name" + i, "菜单组 " + i);
                IniFile.WriteValue(iniPath, "MenuGroupCount", "count" + i, "0");
                continue;
            }
            IniFile.WriteValue(iniPath, "MenuGroupsEnable", "enableGroup" + i, "true");
            IniFile.WriteValue(iniPath, "MenuGroupName", "name" + i, g.Name);
            IniFile.WriteValue(iniPath, "MenuGroupCount", "count" + i, g.Items.Count.ToString());
            for (int j = 0; j < g.Items.Count; j++)
            {
                IniFile.WriteValue(iniPath, itemsSection, "name" + (j + 1), g.Items[j].Name);
                IniFile.WriteValue(iniPath, itemsSection, "action" + (j + 1), g.Items[j].Action);
            }
        }
    }

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
        public string Action { get; }
        public MenuItem(string name, string action) { Name = name; Action = action; }
    }
}

