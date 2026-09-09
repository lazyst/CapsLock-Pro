using System.Windows;
using CapsLockPro.Core;
using CapsLockPro.Features;

namespace CapsLockPro.Views;

/// <summary>配置助手 GUI（对应 AHK ConfigHelper.ahk）。
/// 菜单组/菜单项双列表 + 增删改 + 上下移动 + 搜索 + 保存/重载；逻辑委托 <see cref="MenuSystem"/>。</summary>
public partial class ConfigHelperWindow : Window
{
    private readonly string _iniPath;
    private int _selectedGroupDisplay = -1;   // ListBox 0-indexed 显示位置
    private int _selectedItemDisplay = -1;    // ListBox 0-indexed 显示位置
    private List<int> _itemDisplayToIndex = new(); // 显示位置 → 组内真实索引

    public ConfigHelperWindow(string iniPath)
    {
        InitializeComponent();
        _iniPath = iniPath;
        try { MenuSystem.Load(_iniPath); } catch { /* 加载失败留空 */ }
        PopulateGroupList();
    }

    /// <summary>显示槽位 → 组槽位（1..10）。</summary>
    private int SelectedSlot => _selectedGroupDisplay + 1;

    private void PopulateGroupList()
    {
        GroupList.Items.Clear();
        for (int i = 1; i <= MenuSystem.GroupCount; i++)
        {
            var g = MenuSystem.GetGroup(i);
            GroupList.Items.Add(g != null ? g.Name : "(空)");
        }
        if (GroupList.Items.Count > 0 && _selectedGroupDisplay >= 0 && _selectedGroupDisplay < GroupList.Items.Count)
            GroupList.SelectedIndex = _selectedGroupDisplay;
    }

    private void GroupList_SelectedIndexChanged(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
    {
        _selectedGroupDisplay = GroupList.SelectedIndex;
        _selectedItemDisplay = -1;
        PopulateItemList(SearchBox.Text);
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
                ItemList.Items.Add(g.Items[i].Name);
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

    private void SearchBox_TextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e) => PopulateItemList(SearchBox.Text);

    // —— 组操作 ——
    private void AddGroup_Click(object sender, RoutedEventArgs e)
    {
        var (ok, name) = InputDialog.Show(this, "添加菜单组", "请输入菜单组名称:", "");
        if (!ok || string.IsNullOrWhiteSpace(name)) return;
        int slot = MenuSystem.AddGroup(name.Trim());
        if (slot < 0) { MessageBox.Show("菜单组已满 (最多10组)", "配置助手", MessageBoxButton.OK, MessageBoxImage.Warning); return; }
        _selectedGroupDisplay = slot - 1;
        PopulateGroupList();
    }

    private void EditGroup_Click(object sender, RoutedEventArgs e)
    {
        var g = MenuSystem.GetGroup(SelectedSlot);
        if (g == null) return;
        var (ok, name) = InputDialog.Show(this, "编辑菜单组", "请输入菜单组名称:", g.Name);
        if (ok && !string.IsNullOrWhiteSpace(name))
        {
            MenuSystem.EditGroup(SelectedSlot, name.Trim());
            PopulateGroupList();
        }
    }

    private void DeleteGroup_Click(object sender, RoutedEventArgs e)
    {
        if (MenuSystem.GetGroup(SelectedSlot) == null) return;
        if (TrayService.Confirm("确定要删除选中的菜单组吗？", "删除菜单组") != MessageBoxResult.Yes) return;
        MenuSystem.DeleteGroup(SelectedSlot);
        _selectedGroupDisplay = -1;
        _selectedItemDisplay = -1;
        PopulateGroupList();
    }

    // —— 项操作 ——
    private void AddItem_Click(object sender, RoutedEventArgs e)
    {
        if (MenuSystem.GetGroup(SelectedSlot) == null) return;
        var dlg = MenuItemEditDialog.ShowDialog(this, "添加菜单项", "", "", "direct", false);
        if (dlg != null)
        {
            MenuSystem.AddItem(SelectedSlot, dlg.ItemName, dlg.Cmd, dlg.Terminal, dlg.KeepWindow);
            PopulateItemList(SearchBox.Text);
        }
    }

    private void EditItem_Click(object sender, RoutedEventArgs e)
    {
        var g = MenuSystem.GetGroup(SelectedSlot);
        if (g == null || _selectedItemDisplay < 0) return;
        if (_selectedItemDisplay >= g.Items.Count) return;
        var item = g.Items[_selectedItemDisplay];
        var (cmd, terminal, keepWindow) = CommandString.Parse(item.Action);
        var dlg = MenuItemEditDialog.ShowDialog(this, "编辑菜单项", item.Name, cmd, terminal, keepWindow);
        if (dlg != null)
        {
            MenuSystem.EditItem(SelectedSlot, _selectedItemDisplay, dlg.ItemName, dlg.Cmd, dlg.Terminal, dlg.KeepWindow);
            PopulateItemList(SearchBox.Text);
        }
    }

    private void DeleteItem_Click(object sender, RoutedEventArgs e)
    {
        if (MenuSystem.GetGroup(SelectedSlot) == null || _selectedItemDisplay < 0) return;
        MenuSystem.DeleteItem(SelectedSlot, _selectedItemDisplay);
        PopulateItemList(SearchBox.Text);
    }

    private void MoveUp_Click(object sender, RoutedEventArgs e)
    {
        if (MenuSystem.GetGroup(SelectedSlot) == null || _selectedItemDisplay < 0) return;
        if (MenuSystem.MoveMenuItem(SelectedSlot, _selectedItemDisplay, -1)) SelectRealIndex(_selectedItemDisplay - 1);
        PopulateItemList(SearchBox.Text);
    }

    private void MoveDown_Click(object sender, RoutedEventArgs e)
    {
        if (MenuSystem.GetGroup(SelectedSlot) == null || _selectedItemDisplay < 0) return;
        if (MenuSystem.MoveMenuItem(SelectedSlot, _selectedItemDisplay, 1)) SelectRealIndex(_selectedItemDisplay + 1);
        PopulateItemList(SearchBox.Text);
    }

    private void SelectRealIndex(int realIndex)
    {
        int d = _itemDisplayToIndex.IndexOf(realIndex);
        _selectedItemDisplay = d;
    }

    private void Reload_Click(object sender, RoutedEventArgs e)
    {
        MenuSystem.ReloadFromIni(_iniPath);
        _selectedGroupDisplay = -1;
        _selectedItemDisplay = -1;
        PopulateGroupList();
        TrayService.ShowBalloon("已重新加载配置");
    }

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            MenuSystem.SaveToIni(_iniPath);
            QuickNote.ReloadTargets();
            TrayService.ShowBalloon("配置已保存");
        }
        catch (Exception ex)
        {
            MessageBox.Show("保存失败: " + ex.Message, "配置助手", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }
}