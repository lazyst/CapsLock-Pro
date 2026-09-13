using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using CapsLockPro.Features;
using CapsLockPro.Native;

namespace CapsLockPro.Views;

/// <summary>菜单项添加/编辑对话框（对应 AHK MenuAddItem/MenuEditItem）。
/// 名称 + 命令 + 终端下拉 + 保持窗口 + 完整命令预览。</summary>
public partial class MenuItemEditDialog : Window
{
    private string _terminalKey = "direct";
    private bool _ok;

    public string ItemName { get; private set; } = "";
    public string Cmd { get; private set; } = "";
    public string Terminal { get; private set; } = "direct";
    public bool KeepWindow { get; private set; }
    public string Workdir { get; private set; } = "";

    public MenuItemEditDialog(string title, string name, string cmd, string terminal, bool keepWindow, string workdir)
    {
        InitializeComponent();
        Title = title;
        NameBox.Text = name;
        CmdBox.Text = cmd;
        _terminalKey = terminal;
        KeepWindowCheck.IsChecked = keepWindow;
        WorkdirBox.Text = workdir;

        foreach (var (display, _) in CommandString.Terminals)
            TerminalCombo.Items.Add(display);
        int sel = 0;
        for (int i = 0; i < CommandString.Terminals.Length; i++)
            if (CommandString.Terminals[i].key == terminal) { sel = i; break; }
        TerminalCombo.SelectedIndex = sel;

        Loaded += (_, _) =>
        {
            NameBox.Focus();
            NameBox.SelectAll();
            // 初始显示终端说明
            var desc = _terminalDescs.FirstOrDefault(d => d.key == _terminalKey).desc;
            TerminalDesc.Text = desc;
            // direct 模式显示"选择..."按钮
            PickFileBtn.Visibility = _terminalKey == "direct" ? Visibility.Visible : Visibility.Collapsed;
        };
        UpdatePreview();
    }

    /// <summary>弹出模态编辑框。</summary>
    public static MenuItemEditDialog? ShowDialog(Window? owner, string title, string name, string cmd, string terminal, bool keepWindow, string workdir)
    {
        var dlg = new MenuItemEditDialog(title, name, cmd, terminal, keepWindow, workdir);
        if (owner != null) dlg.Owner = owner;
        dlg.ShowDialog();
        return dlg._ok ? dlg : null;
    }

    private static readonly (string key, string desc)[] _terminalDescs =
    {
        ("direct",   "直接运行，不打开终端窗口。适用于 GUI 程序、打开 URL/文件、静默执行"),
        ("pwsh7",    "PowerShell 7，需要已安装"),
        ("pwsh5",    "Windows 自带 PowerShell 5.1"),
        ("cmd",      "Windows 命令提示符"),
        ("gitbash",  "Git Bash（需安装 Git for Windows）"),
        ("wslbash",  "WSL Linux Bash（需安装 WSL）"),
    };

    private void Terminal_Changed(object sender, SelectionChangedEventArgs e)
    {
        if (TerminalCombo.SelectedIndex >= 0)
        {
            _terminalKey = CommandString.Terminals[TerminalCombo.SelectedIndex].key;
            var desc = _terminalDescs.FirstOrDefault(d => d.key == _terminalKey).desc;
            TerminalDesc.Text = desc;
            // direct 模式显示"选择..."按钮，其他终端隐藏
            PickFileBtn.Visibility = _terminalKey == "direct" ? Visibility.Visible : Visibility.Collapsed;
        }
        UpdatePreview();
    }

    private void UpdatePreview(object sender, RoutedEventArgs e) => UpdatePreview();
    private void UpdatePreview(object sender, EventArgs e) => UpdatePreview();

    private void UpdatePreview() =>
        PreviewBox.Text = TerminalLauncher.BuildPreview(_terminalKey, KeepWindowCheck.IsChecked == true, CmdBox.Text, WorkdirBox.Text);

    private void Ok_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(NameBox.Text)) return;
        ItemName = NameBox.Text;
        Cmd = CmdBox.Text;
        Terminal = _terminalKey;
        KeepWindow = KeepWindowCheck.IsChecked == true;
        Workdir = WorkdirBox.Text;
        _ok = true;
        DialogResult = true;
    }

    private void BrowseWorkdir_Click(object sender, RoutedEventArgs e)
    {
        var picked = FolderPicker.PickFolder(new WindowInteropHelper(this).Handle, "选择工作目录");
        if (picked != null) WorkdirBox.Text = picked;
    }

    private void PickFile_Click(object sender, RoutedEventArgs e)
    {
        // 弹出选择：文件 or 文件夹
        var choice = System.Windows.MessageBox.Show(
            "点击 是 选择文件，点击 否 选择文件夹", "选择类型",
            MessageBoxButton.YesNoCancel, MessageBoxImage.Question);
        if (choice == MessageBoxResult.Yes)
        {
            var dlg = new Microsoft.Win32.OpenFileDialog
            {
                Title = "选择要执行的文件",
                Filter = "所有文件 (*.*)|*.*",
            };
            if (dlg.ShowDialog() == true)
                CmdBox.Text = dlg.FileName;
        }
        else if (choice == MessageBoxResult.No)
        {
            var picked = FolderPicker.PickFolder(new WindowInteropHelper(this).Handle, "选择文件夹");
            if (picked != null) CmdBox.Text = picked;
        }
    }
}
