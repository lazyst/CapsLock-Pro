using System.Windows;
using CapsLockPro.Core;
using CapsLockPro.Features;
using OpenFileDialog = Microsoft.Win32.OpenFileDialog;

namespace CapsLockPro.Views;

/// <summary>终端路径设置对话框：展示各终端探测状态（只读），可配置 Git Bash 路径（存 INI [TerminalPaths]）。</summary>
public partial class TerminalPathsDialog : Window
{
    public TerminalPathsDialog()
    {
        InitializeComponent();
        Refresh();
    }

    public static void ShowDialog(Window? owner)
    {
        var dlg = new TerminalPathsDialog();
        if (owner != null) dlg.Owner = owner;
        dlg.ShowDialog();
    }

    private void Refresh_Click(object sender, RoutedEventArgs e) => Refresh();

    private void Refresh()
    {
        var rows = new System.Collections.Generic.List<PathRow>();
        foreach (var key in TerminalLauncher.ResolvableTerminals)
            rows.Add(new PathRow(TerminalLauncher.DisplayLabel(key), TerminalLauncher.Resolve(key) ?? "（未检测到）"));
        PathsGrid.ItemsSource = rows;
        GitBashBox.Text = TerminalLauncher.GetGitBashPath() ?? "";
    }

    private void Browse_Click(object sender, RoutedEventArgs e)
    {
        var ofd = new OpenFileDialog
        {
            Filter = "bash.exe|bash.exe|可执行文件 (*.exe)|*.exe|所有文件 (*.*)|*.*",
            FileName = "bash.exe",
            Title = "选择 Git Bash 可执行文件",
        };
        if (ofd.ShowDialog() == true)
            GitBashBox.Text = ofd.FileName;
    }

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        TerminalLauncher.SaveGitBashPath(GitBashBox.Text.Trim());
        Refresh();
        TrayService.Notify("终端路径已保存");
        DialogResult = true;
    }

    private sealed record PathRow(string Label, string Path);
}
