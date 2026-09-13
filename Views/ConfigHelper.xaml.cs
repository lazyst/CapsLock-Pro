using System.Windows;
using System.Windows.Input;
using CapsLockPro.Core;
using CapsLockPro.Features;

namespace CapsLockPro.Views;

/// <summary>设置 GUI（对应 AHK ConfigHelper.ahk）。
/// 菜单组/菜单项双列表 + 增删改 + 上下移动 + 搜索 + 保存/重载；逻辑委托 <see cref="MenuSystem"/>。</summary>
public partial class ConfigHelperWindow : Window
{
    private readonly string _configPath;
    private int _selectedGroupDisplay = -1;   // ListBox 0-indexed 显示位置
    private int _selectedItemDisplay = -1;    // ListBox 0-indexed 显示位置
    private List<int> _itemDisplayToIndex = new(); // 显示位置 → 组内真实索引
    private bool _initializing = true;   // 初始化设 IsChecked 会触发 Checked/Unchecked，用此标志跳过
    private bool _suppressGroupSelection; // PopulateGroupList 期间抑制 GroupList_SelectedIndexChanged 避免选中被重置

    public ConfigHelperWindow(string configPath)
    {
        InitializeComponent();
        _configPath = configPath;
        try { MenuSystem.Load(_configPath); } catch { /* 加载失败留空 */ }
        PopulateGroupList();
        // 异步查询开机自启状态（schtasks 是外部进程，同步调用会阻塞 UI 线程导致白屏）
        Loaded += async (_, _) =>
        {
            _initializing = true;
            AutoStartBox.IsChecked = await System.Threading.Tasks.Task.Run(() => AutoStartService.IsEnabled());
            _initializing = false;
        };
    }

    /// <summary>显示槽位 → 组槽位（1..10）。</summary>
    private int SelectedSlot => _selectedGroupDisplay + 1;

    private void PopulateGroupList()
    {
        GroupList.Items.Clear();
        for (int i = 1; i <= MenuSystem.GroupCount; i++)
        {
            var g = MenuSystem.GetGroup(i);
            string seq = (i % 10).ToString();   // 1-9→"1"~"9"，10→"0"，对应 CapsLock+1~9,0 选组热键
            GroupList.Items.Add($"{seq}. {g?.Name ?? "(空)"}");
        }
        if (GroupList.Items.Count > 0 && _selectedGroupDisplay >= 0 && _selectedGroupDisplay < GroupList.Items.Count)
            GroupList.SelectedIndex = _selectedGroupDisplay;
    }

    private void GroupList_SelectedIndexChanged(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
    {
        if (_suppressGroupSelection) return;
        _selectedGroupDisplay = GroupList.SelectedIndex;
        _selectedItemDisplay = -1;
        PopulateItemList(string.Empty);
    }

    private void PopulateItemList(string filter)
    {
        ItemList.Items.Clear();
        _itemDisplayToIndex.Clear();
        var g = MenuSystem.GetGroup(SelectedSlot);
        if (g == null) return;
        for (int i = 0; i < g.Items.Count; i++)
        {
            if (string.IsNullOrEmpty(filter) || g.Items[i].Name.Contains(filter))
            {
                ItemList.Items.Add($"{i + 1}. {g.Items[i].Name}");
                _itemDisplayToIndex.Add(i);
            }
        }
        if (ItemList.Items.Count > 0 && _selectedItemDisplay >= 0 && _selectedItemDisplay < ItemList.Items.Count)
            ItemList.SelectedIndex = _selectedItemDisplay;
    }

    private void ItemList_SelectedIndexChanged(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
    {
        int d = ItemList.SelectedIndex;
        if (d >= 0 && d < _itemDisplayToIndex.Count)
            _selectedItemDisplay = _itemDisplayToIndex[d];
    }

    private void ItemList_MouseDoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (ItemList.SelectedIndex < 0) return;
        EditItem_Click(sender, e);
    }

    // —— 组操作 ——
    private void EditGroup_Click(object sender, RoutedEventArgs e)
    {
        var g = MenuSystem.GetGroup(SelectedSlot);
        string currentName = g?.Name ?? "";
        var (ok, name) = InputDialog.Show(this, "编辑菜单组", "请输入菜单组名称:", currentName);
        if (ok && !string.IsNullOrWhiteSpace(name))
        {
            if (g == null)
            {
                // 空槽 → 创建组
                int slot = MenuSystem.AddGroup(name.Trim());
                if (slot < 0) { ConfirmDialog.Info(this, "设置", "菜单组已满（最多10组）"); return; }
                _selectedGroupDisplay = slot - 1;
            }
            else
            {
                MenuSystem.EditGroup(SelectedSlot, name.Trim());
            }
            _suppressGroupSelection = true;
            PopulateGroupList();
            _suppressGroupSelection = false;
        }
    }

    private void DeleteGroup_Click(object sender, RoutedEventArgs e)
    {
        if (MenuSystem.GetGroup(SelectedSlot) == null) return;
        if (!ConfirmDialog.Confirm(this, "删除菜单组", "确定要删除选中的菜单组吗？", danger: true)) return;
        MenuSystem.DeleteGroup(SelectedSlot);
        _selectedGroupDisplay = -1;
        _selectedItemDisplay = -1;
        PopulateGroupList();
    }

    // —— 项操作 ——
    private void AddItem_Click(object sender, RoutedEventArgs e)
    {
        var g = MenuSystem.GetGroup(SelectedSlot);
        if (g == null)
        {
            // 空槽 → 先自动创建组（用默认名），再添加项
            int slot = MenuSystem.AddGroup("新组");
            if (slot < 0) { ConfirmDialog.Info(this, "设置", "菜单组已满（最多10组）"); return; }
            _selectedGroupDisplay = slot - 1;
            _suppressGroupSelection = true;
            PopulateGroupList();
            _suppressGroupSelection = false;
        }
        var dlg = MenuItemEditDialog.ShowDialog(this, "添加菜单项", "", "", "direct", false, "");
        if (dlg != null)
        {
            MenuSystem.AddItem(SelectedSlot, dlg.ItemName, dlg.Cmd, dlg.Terminal, dlg.KeepWindow, dlg.Workdir);
            PopulateItemList(string.Empty);
        }
    }

    private void EditItem_Click(object sender, RoutedEventArgs e)
    {
        var g = MenuSystem.GetGroup(SelectedSlot);
        if (g == null || _selectedItemDisplay < 0) return;
        if (_selectedItemDisplay >= g.Items.Count) return;
        var item = g.Items[_selectedItemDisplay];
        var dlg = MenuItemEditDialog.ShowDialog(this, "编辑菜单项", item.Name, item.Cmd, item.Terminal, item.KeepWindow, item.Workdir);
        if (dlg != null)
        {
            MenuSystem.EditItem(SelectedSlot, _selectedItemDisplay, dlg.ItemName, dlg.Cmd, dlg.Terminal, dlg.KeepWindow, dlg.Workdir);
            PopulateItemList(string.Empty);
        }
    }

    private void DeleteItem_Click(object sender, RoutedEventArgs e)
    {
        if (MenuSystem.GetGroup(SelectedSlot) == null || _selectedItemDisplay < 0) return;
        MenuSystem.DeleteItem(SelectedSlot, _selectedItemDisplay);
        PopulateItemList(string.Empty);
    }

    private void MoveUp_Click(object sender, RoutedEventArgs e)
    {
        if (MenuSystem.GetGroup(SelectedSlot) == null || _selectedItemDisplay < 0) return;
        if (MenuSystem.MoveMenuItem(SelectedSlot, _selectedItemDisplay, -1)) SelectRealIndex(_selectedItemDisplay - 1);
        PopulateItemList(string.Empty);
    }

    private void MoveDown_Click(object sender, RoutedEventArgs e)
    {
        if (MenuSystem.GetGroup(SelectedSlot) == null || _selectedItemDisplay < 0) return;
        if (MenuSystem.MoveMenuItem(SelectedSlot, _selectedItemDisplay, 1)) SelectRealIndex(_selectedItemDisplay + 1);
        PopulateItemList(string.Empty);
    }

    private void SelectRealIndex(int realIndex)
    {
        int d = _itemDisplayToIndex.IndexOf(realIndex);
        _selectedItemDisplay = d;
    }

    private void AutoStartBox_Changed(object sender, RoutedEventArgs e)
    {
        if (_initializing) return;
        bool want = AutoStartBox.IsChecked == true;
        bool ok = want ? AutoStartService.Enable() : AutoStartService.Disable();
        if (!ok)
        {
            // 操作失败：回滚勾选并提示
            _initializing = true;
            AutoStartBox.IsChecked = !want;
            _initializing = false;
            ConfirmDialog.Info(this, "开机自启", want ? "启用失败，请检查权限或任务计划服务。" : "禁用失败。");
        }
    }

    private void TerminalPaths_Click(object sender, RoutedEventArgs e)
    {
        TerminalPathsDialog.ShowDialog(this);
        MenuSystem.ReloadFromConfig(_configPath);
        PopulateGroupList();
    }

    private void Reload_Click(object sender, RoutedEventArgs e)
    {
        MenuSystem.ReloadFromConfig(_configPath);
        _selectedGroupDisplay = -1;
        _selectedItemDisplay = -1;
        PopulateGroupList();
        TrayService.Notify("已重新加载配置");
    }

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            MenuSystem.SaveToConfig(_configPath);
            QuickNote.Refresh();
            TrayService.Notify("配置已保存");
        }
        catch (Exception ex)
        {
            ConfirmDialog.Info(this, "设置", "保存失败: " + ex.Message);
        }
    }
}