using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;
using CapsLockPro.Config;
using CapsLockPro.Native;

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
    private const int GroupCount = 10;
    private static readonly MenuGroup?[] _groups = new MenuGroup?[GroupCount + 1]; // 1-indexed
    private static MenuPopup? _current;

    /// <summary>从 INI 加载全部 10 个菜单组（启动时调用一次）。</summary>
    public static void Load(string? iniPath)
    {
        for (int i = 1; i <= GroupCount; i++)
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
        _current = new MenuPopup(g, groupIndex);
        _current.FormClosed += (_, _) => _current = null;
        _current.Show();
    }

    /// <summary>关闭当前菜单（若存在）。</summary>
    public static void CloseCurrent()
    {
        if (_current != null && !_current.IsDisposed)
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

/// <summary>
/// 菜单弹出窗口（对应 lib/ui/MenuUI.ahk CreateMenuGUI）。
/// 无边框置顶工具窗口；标题 + 序号按钮列表 + 关闭按钮；Esc/点击外部/选号 关闭。
/// </summary>
internal sealed class MenuPopup : Form
{
    private readonly MenuSystem.MenuGroup _group;
    private readonly int _groupIndex;

    public MenuPopup(MenuSystem.MenuGroup group, int groupIndex)
    {
        _group = group;
        _groupIndex = groupIndex;

        FormBorderStyle = FormBorderStyle.None;
        StartPosition = FormStartPosition.Manual;
        TopMost = true;
        ShowInTaskbar = false;
        KeyPreview = true;
        BackColor = UiTheme.Surface;
        Font = UiTheme.UiFont;
        DoubleBuffered = true;

        BuildControls();

        // 居中（主屏工作区）
        var wa = Screen.PrimaryScreen!.WorkingArea;
        Location = new Point(wa.X + (wa.Width - Width) / 2, wa.Y + (wa.Height - Height) / 2);
    }

    private void BuildControls()
    {
        // 标题
        var title = new Label
        {
            Text = _group.Name,
            TextAlign = ContentAlignment.MiddleCenter,
            Bounds = new Rectangle(0, 0, 300, 48),
            BackColor = UiTheme.Accent,
            ForeColor = Color.White,
            Font = new Font("Segoe UI", 13f, FontStyle.Bold),
        };
        Controls.Add(title);

        int y = 58;
        const int btnH = 42, gap = 6, left = 15, numW = 30;
        int btnW = 300 - left - numW - left;

        for (int i = 0; i < _group.Items.Count; i++)
        {
            var item = _group.Items[i];
            string numText = (i < 9) ? (i + 1).ToString() : "0";
            int itemIndex = i + 1; // 闭包捕获

            var num = new Label
            {
                Text = numText,
                Bounds = new Rectangle(left + 5, y + 10, 24, 24),
                ForeColor = UiTheme.Accent,
                Font = new Font("Segoe UI", 12f, FontStyle.Bold),
                TextAlign = ContentAlignment.MiddleCenter,
            };
            Controls.Add(num);

            var btn = new Button
            {
                Text = "  " + item.Name,
                Bounds = new Rectangle(left + numW, y, btnW, btnH),
            };
            UiTheme.StyleButton(btn, UiTheme.ButtonRole.Secondary, false);
            btn.TextAlign = ContentAlignment.MiddleLeft;
            btn.Click += (_, _) => MenuSystem.SelectItem(_groupIndex, itemIndex);
            Controls.Add(btn);

            y += btnH + gap;
        }

        // 关闭按钮
        y += 8;
        var close = new Button
        {
            Text = "关闭 (Esc)",
            Bounds = new Rectangle(left, y, 300 - left - left, 36),
        };
        UiTheme.StyleButton(close, UiTheme.ButtonRole.Secondary, false);
        close.Click += (_, _) => MenuSystem.CloseCurrent();
        Controls.Add(close);

        y += 36 + 12;
        ClientSize = new Size(300, y);
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        UiTheme.EnableRounded(Handle);
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        base.OnKeyDown(e);
        int idx = e.KeyCode switch
        {
            Keys.D1 => 1, Keys.D2 => 2, Keys.D3 => 3, Keys.D4 => 4, Keys.D5 => 5,
            Keys.D6 => 6, Keys.D7 => 7, Keys.D8 => 8, Keys.D9 => 9,
            Keys.D0 => 10,
            Keys.NumPad1 => 1, Keys.NumPad2 => 2, Keys.NumPad3 => 3, Keys.NumPad4 => 4,
            Keys.NumPad5 => 5, Keys.NumPad6 => 6, Keys.NumPad7 => 7, Keys.NumPad8 => 8,
            Keys.NumPad9 => 9, Keys.NumPad0 => 10,
            _ => -1,
        };
        if (idx >= 1)
        {
            if (idx <= _group.Items.Count)
                MenuSystem.SelectItem(_groupIndex, idx);
            else
                MenuSystem.CloseCurrent();
            e.Handled = true;
            return;
        }
        if (e.KeyCode == Keys.Escape)
        {
            MenuSystem.CloseCurrent();
            e.Handled = true;
        }
    }

    protected override void OnDeactivate(EventArgs e)
    {
        base.OnDeactivate(e);
        // 点击外部自动关闭（对应 CheckMenuActive）
        if (!IsDisposed)
            MenuSystem.CloseCurrent();
    }
}
