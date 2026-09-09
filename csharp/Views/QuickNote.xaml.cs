using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using CapsLockPro.Core;
using CapsLockPro.Features;

namespace CapsLockPro.Views;

/// <summary>速记 GUI（编辑/查看双模 + 保存逻辑）。对应 AHK ShowQuickNote。</summary>
public partial class QuickNoteWindow : Window
{
    private readonly string _defaultDir;
    private readonly Dictionary<string, string> _targets;
    private string _currentEditingFile = "";
    private bool _viewMode;

    private record NoteFile(string Name, string Mtime, string Target, string Path);

    public QuickNoteWindow(string defaultDir, Dictionary<string, string> targets)
    {
        InitializeComponent();
        _defaultDir = defaultDir;
        _targets = targets;
        Loaded += (_, _) => { EditBox.Focus(); EditBox.CaretIndex = EditBox.Text.Length; };
    }

    private void Window_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.S && (Keyboard.Modifiers & ModifierKeys.Control) != 0)
        {
            SaveNote();
            e.Handled = true;
        }
    }

    private void ViewToggle_Click(object sender, RoutedEventArgs e) => ToggleView();

    private void ToggleView()
    {
        _viewMode = !_viewMode;
        if (_viewMode)
        {
            EditBox.Visibility = Visibility.Collapsed;
            NoteList.Visibility = Visibility.Visible;
            SearchBox.Visibility = Visibility.Visible;
            SearchLabel.Visibility = Visibility.Visible;
            DeleteBtn.Visibility = Visibility.Visible;
            NewNoteBtn.Visibility = Visibility.Collapsed;
            ViewToggleBtn.Content = "编辑速记";
            LoadFilesToList("");
            StatusBar.Text = "提示: 双击文件加载 | 选择后点击删除选中";
        }
        else
        {
            EditBox.Visibility = Visibility.Visible;
            NoteList.Visibility = Visibility.Collapsed;
            SearchBox.Visibility = Visibility.Collapsed;
            SearchLabel.Visibility = Visibility.Collapsed;
            DeleteBtn.Visibility = Visibility.Collapsed;
            NewNoteBtn.Visibility = Visibility.Visible;
            ViewToggleBtn.Content = "查看速记";
            _currentEditingFile = "";
            StatusBar.Text = "提示: 输入标题或删除## | 最后一行使用==目标==指定保存位置 | Ctrl+S保存";
            EditBox.Text = "## ";
            EditBox.Focus();
            EditBox.CaretIndex = EditBox.Text.Length;
        }
    }

    private void NewNote_Click(object sender, RoutedEventArgs e)
    {
        _currentEditingFile = "";
        EditBox.Text = "## ";
        StatusBar.Text = "提示: 输入标题或删除## | 最后一行使用==目标==指定保存位置 | Ctrl+S保存";
        EditBox.Focus();
        EditBox.CaretIndex = EditBox.Text.Length;
    }

    private void Cancel_Click(object sender, RoutedEventArgs e) => Close();

    private void SearchBox_TextChanged(object sender, TextChangedEventArgs e) => LoadFilesToList(SearchBox.Text);

    // —— 列表加载 ——
    private void LoadFilesToList(string filter)
    {
        var files = new List<NoteFile>();
        foreach (var kv in _targets)
            if (File.Exists(kv.Value))
            {
                string name = Path.GetFileName(kv.Value);
                if (filter == "" || name.Contains(filter) || kv.Key.Contains(filter))
                    files.Add(new NoteFile(name, File.GetLastWriteTime(kv.Value).ToString("yyyy-MM-dd HH:mm"), kv.Key, kv.Value));
            }
        try
        {
            foreach (var f in Directory.EnumerateFiles(_defaultDir, "*.txt"))
            {
                if (files.Exists(x => string.Equals(x.Path, f, StringComparison.OrdinalIgnoreCase))) continue;
                string name = Path.GetFileName(f);
                if (filter == "" || name.Contains(filter))
                    files.Add(new NoteFile(name, File.GetLastWriteTime(f).ToString("yyyy-MM-dd HH:mm"), "默认", f));
            }
        }
        catch { /* 默认目录不存在静默 */ }
        files.Sort((a, b) => string.Compare(b.Mtime, a.Mtime, StringComparison.Ordinal));
        NoteList.ItemsSource = files;
    }

    private void NoteList_DoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (NoteList.SelectedItem is not NoteFile sel || !File.Exists(sel.Path)) return;
        string content;
        try { content = File.ReadAllText(sel.Path, Encoding.UTF8); }
        catch { try { content = File.ReadAllText(sel.Path); } catch { return; } }

        EditBox.Text = content;
        _currentEditingFile = sel.Path;
        if (_viewMode) ToggleView();
        StatusBar.Text = "提示: 正在编辑 | Ctrl+S保存 | 新建速记按钮可写新内容";
        EditBox.Focus();
        EditBox.CaretIndex = EditBox.Text.Length;
    }

    private void Delete_Click(object sender, RoutedEventArgs e)
    {
        if (NoteList.SelectedItem is not NoteFile sel)
        {
            MessageBox.Show("请先选择一个速记文件", "删除速记", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }
        if (!File.Exists(sel.Path)) return;
        try
        {
            File.Delete(sel.Path);
            LoadFilesToList(SearchBox.Text);
            TrayService.Notify("已删除「" + sel.Name + "」");
        }
        catch (Exception ex)
        {
            MessageBox.Show("删除失败: " + ex.Message, "删除速记", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private void Save_Click(object sender, RoutedEventArgs e) => SaveNote();

    // —— 保存（对应 SaveNoteHandler + SaveTo* 系列，逻辑原样保留）——
    private void SaveNote()
    {
        string content = EditBox.Text;
        if (string.IsNullOrEmpty(content))
        {
            MessageBox.Show("笔记内容为空，未保存", "速记", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        // 编辑现有文件：替换首行时间戳后整体覆盖
        if (!string.IsNullOrEmpty(_currentEditingFile) && File.Exists(_currentEditingFile))
        {
            try
            {
                string ts = Features.QuickNote.Timestamp();
                content = Regex.Replace(content, @"^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]", "[" + ts + "]");
                File.WriteAllText(_currentEditingFile, content, new UTF8Encoding(false));
                TrayService.Notify("已保存到「" + _currentEditingFile + "」");
                EditBox.Focus();
                return;
            }
            catch (Exception ex)
            {
                MessageBox.Show("保存失败: " + ex.Message, "速记", MessageBoxButton.OK, MessageBoxImage.Error);
                return;
            }
        }

        _currentEditingFile = "";

        var lines = new List<string>(content.Split('\n'));
        for (int i = 0; i < lines.Count; i++) lines[i] = lines[i].TrimEnd('\r');
        while (lines.Count > 0 && string.IsNullOrWhiteSpace(lines[^1]))
            lines.RemoveAt(lines.Count - 1);

        string title = "";
        if (lines.Count > 0)
        {
            var m = Regex.Match(lines[0], @"^##\s+(.+)$");
            if (m.Success) { string t = m.Groups[1].Value.Trim(); if (t.Length > 0) title = t; }
        }

        string targetName = "";
        string targetFile = "";
        if (lines.Count > 0)
        {
            var m = Regex.Match(lines[^1], @"^==\s*(.+?)\s*==$");
            if (m.Success)
            {
                targetName = m.Groups[1].Value.Trim();
                lines.RemoveAt(lines.Count - 1);
                if (_targets.TryGetValue(targetName, out var tp)) targetFile = tp;
                else
                {
                    string potential = Path.Combine(_defaultDir, targetName + ".txt");
                    if (File.Exists(potential)) targetFile = potential;
                }
            }
        }

        if (lines.Count > 0 && Regex.IsMatch(lines[0], @"^##\s*$"))
            lines.RemoveAt(0);

        string? savedPath;
        if (!string.IsNullOrEmpty(targetFile) && File.Exists(targetFile))
            savedPath = SaveToSpecificFile(targetFile, lines, title, targetName);
        else if (!string.IsNullOrEmpty(targetName) && _targets.ContainsKey(targetName))
            savedPath = SaveToTargetFile(targetName, lines, title);
        else
            savedPath = SaveToNewFile(lines, title);

        if (!string.IsNullOrEmpty(savedPath) && File.Exists(savedPath))
        {
            _currentEditingFile = "";
            EditBox.Text = "## ";
            StatusBar.Text = "提示: 输入标题或删除## | 最后一行使用==目标==指定保存位置 | Ctrl+S保存";
        }
        EditBox.Focus();
        EditBox.CaretIndex = EditBox.Text.Length;
    }

    private string SaveToNewFile(List<string> lines, string title)
    {
        string fileName = title.Length > 0
            ? Features.QuickNote.CleanFileNameFromTitle(title) + ".txt"
            : Features.QuickNote.TimestampCompact() + ".txt";
        string filePath = Path.Combine(_defaultDir, fileName);
        string ts = Features.QuickNote.Timestamp();
        bool fileExists = File.Exists(filePath);
        var sb = new StringBuilder();

        if (fileExists && title.Length > 0)
        {
            sb.Append("\n\n\n");
            bool hasNewTitle = false;
            string newTitle = "";
            if (lines.Count > 0)
            {
                var m = Regex.Match(lines[0], @"^##\s+(.+)$");
                if (m.Success && m.Groups[1].Value.Trim().Length > 0) { hasNewTitle = true; newTitle = lines[0]; }
            }
            if (hasNewTitle) sb.Append("[").Append(ts).Append("]\n").Append(newTitle).Append("\n\n");
            else sb.Append("[").Append(ts).Append("]\n\n");
            for (int i = 0; i < lines.Count; i++)
            {
                if (i == 0 && hasNewTitle) continue;
                sb.Append(lines[i]).Append("\n");
            }
            try { File.AppendAllText(filePath, sb.ToString(), new UTF8Encoding(false)); TrayService.Notify("已追加到「" + filePath + "」"); }
            catch (Exception ex) { MessageBox.Show("保存失败: " + ex.Message, "速记", MessageBoxButton.OK, MessageBoxImage.Error); }
        }
        else
        {
            if (title.Length > 0)
            {
                bool hasTitle = false;
                if (lines.Count > 0)
                {
                    var m = Regex.Match(lines[0], @"^##\s+(.+)$");
                    if (m.Success && m.Groups[1].Value.Trim().Length > 0) hasTitle = true;
                }
                if (hasTitle)
                {
                    for (int i = 0; i < lines.Count; i++)
                    {
                        if (i == 0) { sb.Append("[").Append(ts).Append("]\n").Append(lines[i]).Append("\n\n"); }
                        else sb.Append(lines[i]).Append("\n");
                    }
                }
                else
                {
                    sb.Append("[").Append(ts).Append("]\n").Append("## ").Append(title).Append("\n\n");
                    foreach (var line in lines) sb.Append(line).Append("\n");
                }
            }
            else
            {
                sb.Append("[").Append(ts).Append("]\n\n");
                foreach (var line in lines) sb.Append(line).Append("\n");
            }
            try { File.WriteAllText(filePath, sb.ToString(), new UTF8Encoding(false)); TrayService.Notify("已保存到「" + filePath + "」"); }
            catch (Exception ex) { MessageBox.Show("保存失败: " + ex.Message, "速记", MessageBoxButton.OK, MessageBoxImage.Error); }
        }
        return filePath;
    }

    private string SaveToTargetFile(string targetName, List<string> lines, string title)
        => SaveToSpecificFile(_targets[targetName], lines, title, targetName);

    private string SaveToSpecificFile(string filePath, List<string> lines, string title, string displayName)
    {
        var sb = new StringBuilder();
        sb.Append("\n\n\n");
        string ts = Features.QuickNote.Timestamp();
        if (title.Length > 0) sb.Append("[").Append(ts).Append("]\n").Append("## ").Append(title).Append("\n\n");
        else sb.Append("[").Append(ts).Append("]\n\n");
        for (int i = 0; i < lines.Count; i++)
        {
            if (i == 0 && title.Length > 0 && Regex.IsMatch(lines[i], @"^##\s+")) continue;
            sb.Append(lines[i]).Append("\n");
        }
        try
        {
            File.AppendAllText(filePath, sb.ToString(), new UTF8Encoding(false));
            string tip = displayName.Length > 0 ? "已保存到「" + displayName + "」" : "已保存到「" + Path.GetFileName(filePath) + "」";
            TrayService.Notify(tip);
        }
        catch (Exception ex)
        {
            MessageBox.Show("保存失败: " + ex.Message, "速记", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        return filePath;
    }
}
