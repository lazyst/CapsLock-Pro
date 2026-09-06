using System.Drawing;
using System.Windows.Forms;
using CapsLockPro.Config;
using CapsLockPro.Core;

namespace CapsLockPro.Features;

/// <summary>
/// 配置助手（对应原版 lib/ConfigHelper.ahk + lib/core/ConfigManager.ahk）。
/// CapsLock+\ 切换多标签 GUI：菜单配置（10 组 + 项的启用/重命名/排序/增删，终端/保持窗口命令构造）
/// 与速记路径（关键词→文件映射增删改排序）。保存直接写回 CapsLock++.ini（逐行编辑式，保留注释格式），
/// 随后重载 <see cref="MenuSystem"/> 与 <see cref="QuickNote"/> 目标。
/// </summary>
/// <remarks>
/// 命令字符串构造/解析见 <see cref="CommandString"/>；INI 读写见 <see cref="IniFile"/>。
/// 窗口在主 UI 线程创建（钩子回调线程），modeless；保存（文件 IO）在按钮事件同步执行。
/// </remarks>
internal static class ConfigHelper
{
    private static ConfigHelperForm? _form;
    private static string? _iniPath;

    public static void Initialize(string? iniPath) => _iniPath = iniPath;

    /// <summary>CapsLock+\ 切换：已打开则关闭，否则打开。</summary>
    public static void Toggle()
    {
        if (_form != null && !_form.IsDisposed) { _form.Close(); _form = null; return; }
        if (string.IsNullOrEmpty(_iniPath)) return;
        _form = new ConfigHelperForm(_iniPath!);
        _form.FormClosed += (_, _) => _form = null;
        _form.Show();
    }
}

internal sealed class ConfigHelperForm : Form
{
    private readonly string _iniPath;

    // —— 菜单页状态 ——
    private readonly bool[] _groupEnabled = new bool[10];
    private readonly List<List<MenuEntry>> _groupItems = new(10); // 0-indexed 10 组
    private int _currentGroup = -1; // -1 = 无选中；否则 0..9
    private ListView _menuGroupLv = null!;
    private ListView _menuItemLv = null!;
    private int _lastTerminalIndex = 2; // 默认 PowerShell 7
    private bool _lastKeepWindow;

    // —— 速记页 ——
    private ListView _noteLv = null!;

    public ConfigHelperForm(string iniPath)
    {
        _iniPath = iniPath;
        for (int i = 0; i < 10; i++) { _groupEnabled[i] = true; _groupItems.Add(new List<MenuEntry>()); }

        Text = "CapsLock++ 配置助手";
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = new Size(800, 614);
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        UiTheme.Apply(this);
        ShowInTaskbar = true;

        var tabs = new TabControl { Bounds = new Rectangle(8, 8, 784, 552), Alignment = TabAlignment.Top };
        var pageMenu = new TabPage("菜单配置");
        var pageNote = new TabPage("速记路径");
        tabs.TabPages.AddRange(new[] { pageMenu, pageNote });
        BuildMenuPage(pageMenu);
        BuildNotePage(pageNote);

        var reloadBtn = MakeBtn("重新加载", UiTheme.ButtonRole.Secondary, (_, _) =>
        {
            if (Confirm("重新加载将丢弃所有未保存的更改，是否继续？", "确认重新加载"))
                LoadFromIni();
        });
        var saveBtn = MakeBtn("保存配置", UiTheme.ButtonRole.Primary, (_, _) => Save());
        var bottomRow = MakeButtonRow(ClientSize.Width - 232, ClientSize.Height - 46, reloadBtn, saveBtn);

        Controls.AddRange(new Control[] { tabs, bottomRow });

        LoadFromIni();
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        UiTheme.EnableRounded(Handle);
    }

    private static Button MakeBtn(string text, UiTheme.ButtonRole role, EventHandler onClick, int minWidth = 92)
    {
        var b = new Button { Text = text };
        UiTheme.StyleButton(b, role, minWidth: minWidth);
        b.Click += onClick;
        return b;
    }

    /// <summary>创建自动排布的按钮行（AutoSize 按钮 + FlowLayoutPanel，永不裁剪文字、永不重叠）。</summary>
    private static FlowLayoutPanel MakeButtonRow(int x, int y, params Button[] btns)
        => MakeButtonRow(x, y, false, 0, btns);

    /// <summary>wrap=true 时宽度不足自动换行；maxWidth>0 时限制面板最大宽度（超宽换行，避免被父容器裁剪）。</summary>
    private static FlowLayoutPanel MakeButtonRow(int x, int y, bool wrap, int maxWidth = 0, params Button[] btns)
    {
        var panel = new FlowLayoutPanel
        {
            Location = new Point(x, y),
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink,
            WrapContents = wrap,
            BackColor = UiTheme.Background,
        };
        if (maxWidth > 0) panel.MaximumSize = new Size(maxWidth, 0);
        panel.Controls.AddRange(btns);
        return panel;
    }

    // —— 菜单配置页 ——
    private void BuildMenuPage(TabPage page)
    {
        // 菜单组
        var grpBox = new GroupBox { Text = "菜单组", Bounds = new Rectangle(8, 8, 360, 470), ForeColor = UiTheme.Text };
        _menuGroupLv = new ListView
        {
            Bounds = new Rectangle(12, 24, 336, 320),
            View = View.Details,
            FullRowSelect = true,
            MultiSelect = false,
            HeaderStyle = ColumnHeaderStyle.None,
        };
        UiTheme.StyleListView(_menuGroupLv);
        _menuGroupLv.Columns.Add("组名", 326);
        _menuGroupLv.SelectedIndexChanged += (_, _) => OnGroupFocus();
        grpBox.Controls.Add(_menuGroupLv);
        grpBox.Controls.Add(MakeButtonRow(12, 356, true, 336,
            MakeBtn("编辑名称", UiTheme.ButtonRole.Secondary, (_, _) => EditGroupName(), minWidth: 80),
            MakeBtn("启用/禁用", UiTheme.ButtonRole.Secondary, (_, _) => ToggleGroup(), minWidth: 88),
            MakeBtn("▲", UiTheme.ButtonRole.Secondary, (_, _) => MoveGroup(-1), minWidth: 34),
            MakeBtn("▼", UiTheme.ButtonRole.Secondary, (_, _) => MoveGroup(1), minWidth: 34)));
        var itemBox = new GroupBox { Text = "菜单项", Bounds = new Rectangle(368, 8, 424, 470), ForeColor = UiTheme.Text };
        _menuItemLv = new ListView
        {
            Bounds = new Rectangle(12, 24, 400, 398),
            View = View.Details,
            FullRowSelect = true,
            MultiSelect = false,
        };
        UiTheme.StyleListView(_menuItemLv);
        _menuItemLv.Columns.Add("名称", 120);
        _menuItemLv.Columns.Add("命令", 280);
        _menuItemLv.DoubleClick += (_, _) => EditMenuItem();
        itemBox.Controls.Add(_menuItemLv);
        itemBox.Controls.Add(MakeButtonRow(12, 430,
            MakeBtn("添加", UiTheme.ButtonRole.Primary, (_, _) => AddMenuItem()),
            MakeBtn("删除", UiTheme.ButtonRole.Danger, (_, _) => DelMenuItem()),
            MakeBtn("▲", UiTheme.ButtonRole.Secondary, (_, _) => MoveItem(-1), minWidth: 40),
            MakeBtn("▼", UiTheme.ButtonRole.Secondary, (_, _) => MoveItem(1), minWidth: 40)));

        page.Controls.AddRange(new Control[] { grpBox, itemBox });
    }

    // —— 速记路径页 ——
    private void BuildNotePage(TabPage page)
    {
        _noteLv = new ListView
        {
            Bounds = new Rectangle(10, 36, 780, 440),
            View = View.Details,
            FullRowSelect = true,
            MultiSelect = false,
        };
        UiTheme.StyleListView(_noteLv);
        _noteLv.Columns.Add("关键词", 150);
        _noteLv.Columns.Add("文件路径", 600);

        page.Controls.Add(_noteLv);
        page.Controls.Add(MakeButtonRow(10, 484,
            MakeBtn("添加", UiTheme.ButtonRole.Primary, (_, _) => NoteAdd()),
            MakeBtn("编辑", UiTheme.ButtonRole.Secondary, (_, _) => NoteEdit()),
            MakeBtn("删除", UiTheme.ButtonRole.Danger, (_, _) => NoteDel()),
            MakeBtn("上移", UiTheme.ButtonRole.Secondary, (_, _) => LvMove(_noteLv, -1)),
            MakeBtn("下移", UiTheme.ButtonRole.Secondary, (_, _) => LvMove(_noteLv, 1))));
    }

    // —— 加载（对应 ConfigReload）——
    private void LoadFromIni()
    {
        // 菜单组
        _menuGroupLv.BeginUpdate(); _menuGroupLv.Items.Clear();
        for (int i = 0; i < 10; i++)
        {
            int idx = i + 1;
            string name = IniFile.ReadValue(_iniPath, "MenuGroupName", "name" + idx) ?? ("菜单组 " + idx);
            string en = IniFile.ReadValue(_iniPath, "MenuGroupsEnable", "enableGroup" + idx) ?? "true";
            _groupEnabled[i] = en.Equals("true", StringComparison.OrdinalIgnoreCase);
            int count = int.TryParse(IniFile.ReadValue(_iniPath, "MenuGroupCount", "count" + idx), out var c) ? c : 0;
            var items = new List<MenuEntry>();
            string section = "MenuGroups" + idx + "Items";
            for (int j = 1; j <= count; j++)
            {
                string? iname = IniFile.ReadValue(_iniPath, section, "name" + j);
                if (string.IsNullOrEmpty(iname)) continue;
                string action = IniFile.ReadValue(_iniPath, section, "action" + j) ?? "";
                items.Add(new MenuEntry(iname!, action));
            }
            _groupItems[i] = items;
            _menuGroupLv.Items.Add(BuildGroupItem(i, name));
        }
        _menuGroupLv.EndUpdate();

        if (_menuGroupLv.Items.Count > 0)
        {
            _menuGroupLv.Items[0].Selected = true;
            _menuGroupLv.Select();
        }
        else
        {
            _currentGroup = -1;
            _menuItemLv.Items.Clear();
        }

        // 速记目标
        _noteLv.BeginUpdate(); _noteLv.Items.Clear();
        int k = 1;
        while (true)
        {
            string? keyword = IniFile.ReadValue(_iniPath, "noteTargets", "note" + k + "1");
            if (string.IsNullOrEmpty(keyword)) break;
            string? path = IniFile.ReadValue(_iniPath, "noteTargets", "note" + k + "2") ?? "";
            _noteLv.Items.Add(new ListViewItem(keyword!) { SubItems = { path } });
            k++;
        }
        _noteLv.EndUpdate();

        if (int.TryParse(IniFile.ReadValue(_iniPath, "MenuSettings", "LastTerminalIdx"), out var tIdx)) _lastTerminalIndex = tIdx;
        _lastKeepWindow = (IniFile.ReadValue(_iniPath, "MenuSettings", "LastKeepWindow") ?? "false").Equals("true", StringComparison.OrdinalIgnoreCase);

        ShowTooltip("配置已加载");
    }

    private ListViewItem BuildGroupItem(int i, string name)
    {
        var prefix = _groupEnabled[i] ? "✓ " : "✗ ";
        return new ListViewItem(prefix + name);
    }

    // —— 菜单组焦点（对应 MenuGroupFocus）——
    private void OnGroupFocus()
    {
        if (_menuGroupLv.SelectedIndices.Count == 0) { _currentGroup = -1; return; }
        int row = _menuGroupLv.SelectedIndices[0];
        if (_currentGroup >= 0 && _currentGroup < 10 && _currentGroup != row)
            SyncItemLvToArray();
        _currentGroup = row;
        RefreshItemLv();
    }

    private void RefreshItemLv()
    {
        _menuItemLv.BeginUpdate(); _menuItemLv.Items.Clear();
        if (_currentGroup < 0 || _currentGroup >= 10) { _menuItemLv.EndUpdate(); return; }
        foreach (var it in _groupItems[_currentGroup])
        {
            var parsed = CommandString.Parse(it.Action);
            _menuItemLv.Items.Add(new ListViewItem(it.Name) { SubItems = { parsed.cmd } });
        }
        _menuItemLv.EndUpdate();
    }

    // —— 同步当前组项 LV → 数组（保留 action，name 取自 LV）——
    private void SyncItemLvToArray()
    {
        if (_currentGroup < 0 || _currentGroup >= 10) return;
        var old = _groupItems[_currentGroup];
        var updated = new List<MenuEntry>();
        for (int i = 0; i < _menuItemLv.Items.Count; i++)
        {
            string name = _menuItemLv.Items[i].SubItems[0].Text;
            string action = (i < old.Count) ? old[i].Action : "";
            updated.Add(new MenuEntry(name, action));
        }
        _groupItems[_currentGroup] = updated;
    }

    private static string ExtractGroupName(string display)
    {
        if (display.Length >= 2 && (display.StartsWith("✓ ") || display.StartsWith("✗ ")))
            return display[2..];
        return display;
    }

    // —— 组操作 ——
    private void EditGroupName()
    {
        if (_menuGroupLv.SelectedIndices.Count == 0) return;
        int row = _menuGroupLv.SelectedIndices[0];
        string real = ExtractGroupName(_menuGroupLv.Items[row].Text);
        var (ok, val) = InputDialog.Show(this, "编辑组名称", "输入新的菜单组名称", real);
        if (ok && val.Length > 0)
            _menuGroupLv.Items[row].Text = (_groupEnabled[row] ? "✓ " : "✗ ") + val;
    }

    private void ToggleGroup()
    {
        if (_menuGroupLv.SelectedIndices.Count == 0) return;
        int row = _menuGroupLv.SelectedIndices[0];
        _groupEnabled[row] = !_groupEnabled[row];
        _menuGroupLv.Items[row].Text = (_groupEnabled[row] ? "✓ " : "✗ ") + ExtractGroupName(_menuGroupLv.Items[row].Text);
    }

    private void MoveGroup(int dir)
    {
        SyncItemLvToArray();
        if (_menuGroupLv.SelectedIndices.Count == 0) return;
        int row = _menuGroupLv.SelectedIndices[0];
        int target = row + dir;
        if (target < 0 || target >= 10) return;
        SwapGroupRows(row, target);
        _menuGroupLv.Items[target].Selected = true;
        _menuGroupLv.Items[target].Focused = true;
        _currentGroup = target;
        RefreshItemLv();
    }

    private void SwapGroupRows(int a, int b)
    {
        var aText = _menuGroupLv.Items[a].Text;
        _menuGroupLv.Items[a].Text = _menuGroupLv.Items[b].Text;
        _menuGroupLv.Items[b].Text = aText;
        (_groupEnabled[a], _groupEnabled[b]) = (_groupEnabled[b], _groupEnabled[a]);
        (_groupItems[a], _groupItems[b]) = (_groupItems[b], _groupItems[a]);
    }

    // —— 项操作 ——
    private void AddMenuItem()
    {
        if (_menuGroupLv.SelectedIndices.Count == 0) { ShowTooltip("请先选择一个菜单组"); return; }
        using var dlg = new MenuItemEditDialog("添加菜单项", "", "", IndexToTerminalKey(_lastTerminalIndex), _lastKeepWindow);
        if (dlg.ShowDialog(this) != DialogResult.OK || dlg.ItemName.Length == 0) return;
        _lastTerminalIndex = TerminalKeyToIndex(dlg.Terminal);
        _lastKeepWindow = dlg.KeepWindow;
        string fullCmd = CommandString.Build(dlg.Cmd, dlg.Terminal, dlg.KeepWindow);
        _menuItemLv.Items.Add(new ListViewItem(dlg.ItemName) { SubItems = { dlg.Cmd } });
        if (_currentGroup >= 0 && _currentGroup < 10)
            _groupItems[_currentGroup].Add(new MenuEntry(dlg.ItemName, fullCmd));
    }

    private void EditMenuItem()
    {
        if (_menuItemLv.SelectedIndices.Count == 0) return;
        int row = _menuItemLv.SelectedIndices[0];
        if (_currentGroup < 0 || _currentGroup >= 10) return;
        var items = _groupItems[_currentGroup];
        if (row >= items.Count) return;
        var cur = items[row];
        var parsed = CommandString.Parse(cur.Action);
        using var dlg = new MenuItemEditDialog("编辑菜单项", cur.Name, parsed.cmd, parsed.terminal, parsed.keepWindow);
        if (dlg.ShowDialog(this) != DialogResult.OK || dlg.ItemName.Length == 0) return;
        string fullCmd = CommandString.Build(dlg.Cmd, dlg.Terminal, dlg.KeepWindow);
        _menuItemLv.Items[row].SubItems[0].Text = dlg.ItemName;
        _menuItemLv.Items[row].SubItems[1].Text = dlg.Cmd;
        items[row] = new MenuEntry(dlg.ItemName, fullCmd);
    }

    private void DelMenuItem()
    {
        SyncItemLvToArray();
        if (_menuItemLv.SelectedIndices.Count == 0) return;
        int row = _menuItemLv.SelectedIndices[0];
        _menuItemLv.Items.RemoveAt(row);
        if (_currentGroup >= 0 && _currentGroup < 10 && row < _groupItems[_currentGroup].Count)
            _groupItems[_currentGroup].RemoveAt(row);
    }

    private void MoveItem(int dir)
    {
        SyncItemLvToArray();
        if (_menuItemLv.SelectedIndices.Count == 0) return;
        int row = _menuItemLv.SelectedIndices[0];
        int target = row + dir;
        if (target < 0 || target >= _menuItemLv.Items.Count) return;
        SwapItemLvRows(row, target);
        if (_currentGroup >= 0 && _currentGroup < 10)
        {
            var items = _groupItems[_currentGroup];
            if (row < items.Count && target < items.Count)
                (items[target], items[row]) = (items[row], items[target]);
        }
        _menuItemLv.Items[target].Selected = true;
        _menuItemLv.Items[target].Focused = true;
    }

    private void SwapItemLvRows(int a, int b)
    {
        var a0 = _menuItemLv.Items[a].SubItems[0].Text;
        var a1 = _menuItemLv.Items[a].SubItems[1].Text;
        _menuItemLv.Items[a].SubItems[0].Text = _menuItemLv.Items[b].SubItems[0].Text;
        _menuItemLv.Items[a].SubItems[1].Text = _menuItemLv.Items[b].SubItems[1].Text;
        _menuItemLv.Items[b].SubItems[0].Text = a0;
        _menuItemLv.Items[b].SubItems[1].Text = a1;
    }

    // —— 速记目标操作 ——
    private void NoteAdd()
    {
        var (ok1, kw) = InputDialog.Show(this, "添加速记目标", "输入关键词", "");
        if (!ok1 || kw.Length == 0) return;
        var (ok2, path) = InputDialog.Show(this, "添加速记目标", "输入文件路径", "");
        if (!ok2 || path.Length == 0) return;
        _noteLv.Items.Add(new ListViewItem(kw) { SubItems = { path } });
    }

    private void NoteEdit()
    {
        if (_noteLv.SelectedIndices.Count == 0) return;
        int row = _noteLv.SelectedIndices[0];
        string kw = _noteLv.Items[row].SubItems[0].Text;
        string path = _noteLv.Items[row].SubItems[1].Text;
        var (ok1, nkw) = InputDialog.Show(this, "编辑速记目标", "编辑关键词", kw);
        if (!ok1) return;
        var (ok2, npath) = InputDialog.Show(this, "编辑速记目标", "编辑文件路径", path);
        if (!ok2) return;
        _noteLv.Items[row].SubItems[0].Text = nkw;
        _noteLv.Items[row].SubItems[1].Text = npath;
    }

    private void NoteDel()
    {
        if (_noteLv.SelectedIndices.Count == 0) return;
        int row = _noteLv.SelectedIndices[0];
        _noteLv.Items.RemoveAt(row);
    }

    private void LvMove(ListView lv, int dir)
    {
        if (lv.SelectedIndices.Count == 0) return;
        int row = lv.SelectedIndices[0];
        int target = row + dir;
        if (target < 0 || target >= lv.Items.Count) return;
        int cols = lv.Columns.Count;
        var rowData = new string[cols];
        var targetData = new string[cols];
        for (int c = 0; c < cols; c++)
        {
            rowData[c] = lv.Items[row].SubItems[c].Text;
            targetData[c] = lv.Items[target].SubItems[c].Text;
        }
        for (int c = 0; c < cols; c++) lv.Items[row].SubItems[c].Text = targetData[c];
        for (int c = 0; c < cols; c++) lv.Items[target].SubItems[c].Text = rowData[c];
        lv.Items[target].Selected = true;
        lv.Items[target].Focused = true;
    }

    // —— 保存（对应 ConfigSave）——
    private void Save()
    {
        SyncItemLvToArray();
        try
        {
            SaveMenus();
            SaveSettings();
            MenuSystem.Load(_iniPath);
            QuickNote.ReloadTargets();
            ShowTooltip("配置已保存并重新加载");
        }
        catch (Exception ex)
        {
            ShowTooltip("保存配置失败: " + ex.Message);
        }
    }

    private void SaveMenus()
    {
        for (int i = 0; i < 10; i++)
        {
            int idx = i + 1;
            string name = ExtractGroupName(_menuGroupLv.Items[i].Text);
            IniFile.WriteValue(_iniPath, "MenuGroupName", "name" + idx, name);
            IniFile.WriteValue(_iniPath, "MenuGroupsEnable", "enableGroup" + idx, _groupEnabled[i] ? "true" : "false");
            string section = "MenuGroups" + idx + "Items";
            var items = _groupItems[i];
            int j = 1;
            for (; j <= items.Count; j++)
            {
                IniFile.WriteValue(_iniPath, section, "name" + j, items[j - 1].Name);
                IniFile.WriteValue(_iniPath, section, "action" + j, items[j - 1].Action);
            }
            // 清理超出当前数量的残留键
            int stale = j;
            while (true)
            {
                string? staleName = IniFile.ReadValue(_iniPath, section, "name" + stale);
                if (string.IsNullOrEmpty(staleName)) break;
                IniFile.DeleteKey(_iniPath, section, "name" + stale);
                IniFile.DeleteKey(_iniPath, section, "action" + stale);
                stale++;
            }
            IniFile.WriteValue(_iniPath, "MenuGroupCount", "count" + idx, items.Count.ToString());
        }
    }

    private void SaveSettings()
    {
        IniFile.WriteValue(_iniPath, "MenuSettings", "LastTerminalIdx", _lastTerminalIndex.ToString());
        IniFile.WriteValue(_iniPath, "MenuSettings", "LastKeepWindow", _lastKeepWindow ? "true" : "false");
        // 速记目标：整段重写（noteX1=关键词 / noteX2=路径）
        IniFile.DeleteSection(_iniPath, "noteTargets");
        int k = 1;
        foreach (ListViewItem item in _noteLv.Items)
        {
            string kw = item.SubItems[0].Text;
            string path = item.SubItems.Count > 1 ? item.SubItems[1].Text : "";
            if (kw.Length > 0 && path.Length > 0)
            {
                IniFile.WriteValue(_iniPath, "noteTargets", "note" + k + "1", kw);
                IniFile.WriteValue(_iniPath, "noteTargets", "note" + k + "2", path);
                k++;
            }
        }
    }

    // —— 终端索引 ↔ 键 ——
    private static string IndexToTerminalKey(int idx)
    {
        int i = idx - 1;
        return (i >= 0 && i < CommandString.Terminals.Length) ? CommandString.Terminals[i].key : "direct";
    }
    private static int TerminalKeyToIndex(string key)
    {
        for (int i = 0; i < CommandString.Terminals.Length; i++)
            if (CommandString.Terminals[i].key == key) return i + 1;
        return 1; // 直接运行
    }

    private bool Confirm(string msg, string title) =>
        MessageBox.Show(this, msg, title, MessageBoxButtons.YesNo, MessageBoxIcon.Question) == DialogResult.Yes;

    private void ShowTooltip(string msg) =>
        AppState.TrayIcon?.ShowBalloonTip(1500, "CapsLock++", msg, ToolTipIcon.Info);

    private sealed record MenuEntry(string Name, string Action);
}
