using System.Diagnostics;
using System.Drawing;
using System.Text;
using System.Text.RegularExpressions;
using System.Windows.Forms;
using CapsLockPro.Config;
using CapsLockPro.Core;
using CapsLockPro.Native;

namespace CapsLockPro.Features;

/// <summary>
/// 速记窗口（对应原版 lib/QuickNote.ahk 后半 ShowQuickNote 及保存逻辑）。
/// CapsLock+N 切换速记 GUI：多行编辑 + 保存格式（<c>## 标题</c> 首行、<c>==目标==</c> 末行）。
/// 目标映射从 <c>CapsLock++.ini [noteTargets]</c> 加载（noteX1=关键词, noteX2=路径）。
/// </summary>
/// <remarks>
/// 默认目录 = ini 同级 <c>速记\</c>（与 AHK A_ScriptDir\速记\ 一致）。窗口在主 UI 线程
/// 创建（钩子回调线程），modeless 非阻塞；保存（文件 IO）在按钮事件同步执行（文件极小）。
/// 速记目标重载入口 <see cref="ReloadTargets"/> 供配置助手保存后调用。
/// </remarks>
internal static class QuickNote
{
    private static QuickNoteForm? _form;
    private static string? _iniPath;
    private static string _defaultDir = "";
    private static readonly Dictionary<string, string> _targets = new(); // 关键词 -> 绝对路径

    /// <summary>启动时初始化（计算默认目录 + 加载目标）。由 TrayAppContext 调用。</summary>
    public static void Initialize(string? iniPath)
    {
        _iniPath = iniPath;
        _defaultDir = ComputeDefaultDir(iniPath);
        ReloadTargets();
        EnsureNoteDirectories();
    }

    /// <summary>重新加载速记目标（配置助手保存后调用）。</summary>
    public static void ReloadTargets()
    {
        _targets.Clear();
        if (!string.IsNullOrEmpty(_iniPath) && File.Exists(_iniPath))
        {
            int i = 1;
            while (true)
            {
                string? keyword = IniFile.ReadValue(_iniPath, "noteTargets", "note" + i + "1");
                if (string.IsNullOrEmpty(keyword)) break;
                string? path = IniFile.ReadValue(_iniPath, "noteTargets", "note" + i + "2");
                if (!string.IsNullOrEmpty(path))
                {
                    if (!Regex.IsMatch(path, @"^[A-Za-z]:\\"))
                        path = Path.Combine(GetDesktopPath(), path);
                    _targets[keyword!] = path!;
                }
                i++;
            }
        }
        if (_targets.Count == 0)
        {
            // 默认目标（与 AHK 一致：速记\<名>.txt）
            _targets["论文"] = Path.Combine(_defaultDir, "论文灵感.txt");
            _targets["日记"] = Path.Combine(_defaultDir, "日记.txt");
            _targets["工作"] = Path.Combine(_defaultDir, "工作.txt");
            _targets["想法"] = Path.Combine(_defaultDir, "想法.txt");
        }
    }

    /// <summary>CapsLock+N 切换：已打开则关闭，否则打开。</summary>
    public static void Toggle()
    {
        if (_form != null && !_form.IsDisposed)
        {
            _form.Close();
            _form = null;
            return;
        }
        EnsureNoteDirectories();
        _form = new QuickNoteForm(_defaultDir, _targets);
        _form.FormClosed += (_, _) => _form = null;
        _form.Show();
    }

    private static string ComputeDefaultDir(string? iniPath)
    {
        // 与 AHK A_ScriptDir\速记\ 一致：ini 同级目录（发布=exe 同级，开发=仓库根）
        string baseDir = !string.IsNullOrEmpty(iniPath) ? Path.GetDirectoryName(iniPath)! : AppContext.BaseDirectory;
        return Path.Combine(baseDir, "速记") + Path.DirectorySeparatorChar;
    }

    private static string GetDesktopPath()
    {
        try
        {
            string desktop = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Desktop") + Path.DirectorySeparatorChar;
            if (Directory.Exists(desktop)) return desktop;
        }
        catch { }
        try
        {
            string desktop = Environment.GetFolderPath(Environment.SpecialFolder.Desktop) + Path.DirectorySeparatorChar;
            if (Directory.Exists(desktop)) return desktop;
        }
        catch { }
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Desktop") + Path.DirectorySeparatorChar;
    }

    private static void EnsureNoteDirectories()
    {
        try { if (!Directory.Exists(_defaultDir)) Directory.CreateDirectory(_defaultDir); } catch (Exception ex) { Debug.WriteLine($"创建速记目录失败: {ex.Message}"); }
        foreach (var path in _targets.Values)
        {
            try
            {
                var dir = Path.GetDirectoryName(path);
                if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir)) Directory.CreateDirectory(dir);
            }
            catch (Exception ex) { Debug.WriteLine($"创建目标目录失败: {ex.Message}"); }
        }
    }

    // —— 文件名清理（对应 CleanFileNameFromTitle）——
    internal static string CleanFileNameFromTitle(string title)
    {
        title = title.Replace("\\", "「反斜杠」");
        title = title.Replace("/", "「斜杠」");
        title = title.Replace(":", "「冒号」");
        title = title.Replace("*", "「星号」");
        title = title.Replace("?", "「问号」");
        title = title.Replace("\"", "「引号」");
        title = title.Replace("<", "「小于」");
        title = title.Replace(">", "「大于」");
        title = title.Replace("|", "「竖线」");
        return title;
    }

    internal static string Timestamp() => DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
    internal static string TimestampCompact() => DateTime.Now.ToString("yyyyMMdd_HHmmss");
}

/// <summary>
/// 速记 GUI（对应 AHK ShowQuickNote 创建的 Gui）。
/// 编辑模式（Edit 多行）/ 查看模式（ListView 列出速记文件）切换；Ctrl+S 保存。
/// </summary>
internal sealed class QuickNoteForm : Form
{
    private readonly string _defaultDir;
    private readonly Dictionary<string, string> _targets; // 关键词 -> 路径
    private string _currentEditingFile = "";
    private bool _viewMode;

    private readonly TextBox _edit;
    private readonly Label _statusBar;
    private readonly Button _viewToggleBtn;
    private readonly Label _searchLabel;
    private readonly TextBox _searchEdit;
    private readonly ListView _listView;
    private readonly Button _saveBtn;
    private readonly Button _newNoteBtn;
    private readonly Button _cancelBtn;
    private readonly Button _deleteBtn;
    private readonly Control _buttonBar;

    public QuickNoteForm(string defaultDir, Dictionary<string, string> targets)
    {
        _defaultDir = defaultDir;
        _targets = targets;

        Text = "速记";
        StartPosition = FormStartPosition.CenterScreen;
        TopMost = true;
        KeyPreview = true;
        Font = new Font("Segoe UI", 10f);
        ClientSize = new Size(500, 400);
        ShowInTaskbar = true;

        _buttonBar = new Control { Bounds = new Rectangle(10, ClientSize.Height - 60, 480, 30) };

        _viewToggleBtn = new Button { Text = "查看速记", Bounds = new Rectangle(10, 0, 80, 25) };
        _searchLabel = new Label { Text = "搜索:", Bounds = new Rectangle(100, 5, 50, 20), Visible = false };
        _searchEdit = new TextBox { Bounds = new Rectangle(155, 0, 150, 25), Visible = false };
        _buttonBar.Controls.AddRange(new Control[] { _viewToggleBtn, _searchLabel, _searchEdit });

        _listView = new ListView
        {
            Bounds = new Rectangle(10, 40, 480, 200),
            View = View.Details,
            FullRowSelect = true,
            MultiSelect = false,
            Visible = false,
        };
        _listView.Columns.Add("文件名", 220);
        _listView.Columns.Add("修改时间", 140);
        _listView.Columns.Add("目标", 80);
        _listView.Columns.Add("路径", 0);
        _listView.ItemActivate += (_, _) => OpenSelected();

        _edit = new TextBox
        {
            Bounds = new Rectangle(10, 40, 480, 200),
            Multiline = true,
            AcceptsTab = true,
            ScrollBars = ScrollBars.Vertical,
            Text = "## ",
        };

        _statusBar = new Label { Text = "提示: 输入标题或删除## | 最后一行使用==目标==指定保存位置 | Ctrl+S保存" };

        _saveBtn = new Button { Text = "保存", Bounds = new Rectangle(10, 0, 80, 25) };
        _newNoteBtn = new Button { Text = "新建速记", Bounds = new Rectangle(100, 0, 80, 25) };
        _cancelBtn = new Button { Text = "取消", Bounds = new Rectangle(190, 0, 80, 25) };
        _deleteBtn = new Button { Text = "删除选中", Bounds = new Rectangle(280, 0, 80, 25), Visible = false };
        _buttonBar.Controls.AddRange(new Control[] { _saveBtn, _newNoteBtn, _cancelBtn, _deleteBtn });

        Controls.AddRange(new Control[] { _buttonBar, _edit, _listView, _statusBar });

        _saveBtn.Click += (_, _) => SaveNote();
        _newNoteBtn.Click += (_, _) => NewNote();
        _cancelBtn.Click += (_, _) => Close();
        _deleteBtn.Click += (_, _) => DeleteSelected();
        _viewToggleBtn.Click += (_, _) => ToggleView();
        _searchEdit.TextChanged += (_, _) => LoadFilesToList(_searchEdit.Text);
        _listView.ItemActivate += (_, _) => OpenSelected();

        LoadIcon();
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        int pref = Win32.DwmwcpRound;
        try { Win32.DwmSetWindowAttribute(Handle, Win32.DwmwaWindowCornerPreference, ref pref, sizeof(int)); }
        catch { /* 旧系统无 DWM 圆角 */ }
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        base.OnKeyDown(e);
        if (e.Control && e.KeyCode == Keys.S)
        {
            SaveNote();
            e.Handled = true;
        }
    }

    protected override void OnResize(EventArgs e)
    {
        base.OnResize(e);
        if (WindowState == FormWindowState.Minimized) return;
        // 构造期 ClientSize 赋值早于控件创建：控件未就绪时跳过布局
        if (_edit == null || _listView == null || _buttonBar == null) return;
        int w = ClientSize.Width, h = ClientSize.Height;
        _edit.Bounds = new Rectangle(10, 40, w - 20, h - 110);
        _listView.Bounds = new Rectangle(10, 40, w - 20, h - 110);
        _buttonBar.Bounds = new Rectangle(10, h - 60, w - 20, 30);
    }

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);
        _edit.Focus();
        _edit.SelectionStart = _edit.TextLength;
    }

    private void LoadIcon()
    {
        var candidates = new[]
        {
            Path.Combine(AppContext.BaseDirectory, "Icon", "QuickNote.ico"),
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "Icon", "QuickNote.ico"),
        };
        foreach (var p in candidates)
        {
            try { if (File.Exists(p)) { Icon = new Icon(p, 32, 32); return; } } catch { }
        }
    }

    // —— 查看/编辑 切换 ——
    private void ToggleView()
    {
        _viewMode = !_viewMode;
        if (_viewMode)
        {
            _edit.ReadOnly = true;
            _edit.Text = "";
            _edit.Visible = false;
            _listView.Visible = true;
            _searchEdit.Visible = true;
            _searchLabel.Visible = true;
            _deleteBtn.Visible = true;
            _newNoteBtn.Visible = false;
            _viewToggleBtn.Text = "编辑速记";
            LoadFilesToList("");
            _statusBar.Text = "提示: 双击文件加载 | 选择后点击删除选中";
        }
        else
        {
            _edit.ReadOnly = false;
            _edit.Text = "## ";
            _edit.Visible = true;
            _listView.Visible = false;
            _searchEdit.Visible = false;
            _searchLabel.Visible = false;
            _deleteBtn.Visible = false;
            _newNoteBtn.Visible = true;
            _viewToggleBtn.Text = "查看速记";
            _currentEditingFile = "";
            _statusBar.Text = "提示: 输入标题或删除## | 最后一行使用==目标==指定保存位置 | Ctrl+S保存";
            _edit.Focus();
            _edit.SelectionStart = _edit.TextLength;
        }
    }

    private void NewNote()
    {
        _currentEditingFile = "";
        _edit.Text = "## ";
        _statusBar.Text = "提示: 输入标题或删除## | 最后一行使用==目标==指定保存位置 | Ctrl+S保存";
        _edit.Focus();
        _edit.SelectionStart = _edit.TextLength;
    }

    // —— 列表加载（对应 LoadNoteFilesToList）——
    private void LoadFilesToList(string filter)
    {
        _listView.BeginUpdate();
        _listView.Items.Clear();
        var files = new List<(string name, string path, string target, DateTime mtime)>();

        // 目标文件
        foreach (var kv in _targets)
        {
            if (File.Exists(kv.Value))
            {
                string name = Path.GetFileName(kv.Value);
                if (filter == "" || name.Contains(filter) || kv.Key.Contains(filter))
                    files.Add((name, kv.Value, kv.Key, File.GetLastWriteTime(kv.Value)));
            }
        }
        // 默认目录其余 .txt
        try
        {
            foreach (var f in Directory.EnumerateFiles(_defaultDir, "*.txt"))
            {
                if (files.Exists(x => string.Equals(x.path, f, StringComparison.OrdinalIgnoreCase))) continue;
                string name = Path.GetFileName(f);
                if (filter == "" || name.Contains(filter))
                    files.Add((name, f, "默认", File.GetLastWriteTime(f)));
            }
        }
        catch { /* 默认目录不存在静默 */ }

        // 按修改时间降序
        files.Sort((a, b) => b.mtime.CompareTo(a.mtime));

        foreach (var f in files)
        {
            var item = new ListViewItem(f.name);
            item.SubItems.Add(f.mtime.ToString("yyyy-MM-dd HH:mm"));
            item.SubItems.Add(f.target);
            item.SubItems.Add(f.path);
            _listView.Items.Add(item);
        }
        _listView.EndUpdate();
    }

    private void OpenSelected()
    {
        if (_listView.SelectedItems.Count == 0) return;
        string? filePath = _listView.SelectedItems[0].SubItems[3].Text;
        if (string.IsNullOrEmpty(filePath) || !File.Exists(filePath)) return;

        string content;
        try { content = File.ReadAllText(filePath, Encoding.UTF8); }
        catch { try { content = File.ReadAllText(filePath); } catch { return; } }

        _edit.Text = content;
        _currentEditingFile = filePath;

        // 切回编辑模式
        if (_viewMode) ToggleView();
        else
        {
            _edit.Visible = true;
            _listView.Visible = false;
            _edit.ReadOnly = false;
        }
        _statusBar.Text = "提示: 正在编辑 | Ctrl+S保存 | 新建速记按钮可写新内容";
        _edit.Focus();
        _edit.SelectionStart = _edit.TextLength;
    }

    // —— 保存（对应 SaveNoteHandler + SaveTo* 系列）——
    private void SaveNote()
    {
        string content = _edit.Text;
        if (string.IsNullOrEmpty(content))
        {
            MessageBox.Show(this, "笔记内容为空，未保存", "速记", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        // 编辑现有文件：替换首行时间戳后整体覆盖
        if (!string.IsNullOrEmpty(_currentEditingFile) && File.Exists(_currentEditingFile))
        {
            try
            {
                string ts = QuickNote.Timestamp();
                content = Regex.Replace(content, @"^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]", "[" + ts + "]");
                File.WriteAllText(_currentEditingFile, content, new UTF8Encoding(false));
                ShowTooltip("已保存到「" + _currentEditingFile + "」");
                _edit.Focus();
                return;
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, "保存失败: " + ex.Message, "速记", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
        }

        _currentEditingFile = "";

        // 解析行
        var lines = new List<string>(content.Split('\n'));
        for (int i = 0; i < lines.Count; i++) lines[i] = lines[i].TrimEnd('\r');
        // 去掉末尾空行（避免末行 ==目标== 因尾随空行解析失败）
        while (lines.Count > 0 && string.IsNullOrWhiteSpace(lines[^1]))
            lines.RemoveAt(lines.Count - 1);

        // 标题（首行 ## xxx）
        string title = "";
        if (lines.Count > 0)
        {
            var m = Regex.Match(lines[0], @"^##\s+(.+)$");
            if (m.Success)
            {
                string t = m.Groups[1].Value.Trim();
                if (t.Length > 0) title = t;
            }
        }

        // 目标（末行 == xxx ==）
        string targetName = "";
        string targetFile = "";
        if (lines.Count > 0)
        {
            var m = Regex.Match(lines[^1], @"^==\s*(.+?)\s*==$");
            if (m.Success)
            {
                targetName = m.Groups[1].Value.Trim();
                lines.RemoveAt(lines.Count - 1);
                if (_targets.TryGetValue(targetName, out var tp))
                    targetFile = tp;
                else
                {
                    string potential = Path.Combine(_defaultDir, targetName + ".txt");
                    if (File.Exists(potential)) targetFile = potential;
                }
            }
        }

        // 移除仅 "## " 的占位首行
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
            // 新建速记：不置位 currentEditingFile（与 AHK 一致，下次保存追加新条目而非覆盖整个文件）
            _currentEditingFile = "";
            _edit.Text = "## ";
            _statusBar.Text = "提示: 输入标题或删除## | 最后一行使用==目标==指定保存位置 | Ctrl+S保存";
        }
        _edit.Focus();
        _edit.SelectionStart = _edit.TextLength;
    }

    private string SaveToNewFile(List<string> lines, string title)
    {
        string fileName = title.Length > 0
            ? QuickNote.CleanFileNameFromTitle(title) + ".txt"
            : QuickNote.TimestampCompact() + ".txt";
        string filePath = Path.Combine(_defaultDir, fileName);
        string ts = QuickNote.Timestamp();
        bool fileExists = File.Exists(filePath);
        var sb = new StringBuilder();

        if (fileExists && title.Length > 0)
        {
            // 追加到现有同名标题文件
            sb.Append("\n\n\n");
            bool hasNewTitle = false;
            string newTitle = "";
            if (lines.Count > 0)
            {
                var m = Regex.Match(lines[0], @"^##\s+(.+)$");
                if (m.Success && m.Groups[1].Value.Trim().Length > 0)
                {
                    hasNewTitle = true;
                    newTitle = lines[0];
                }
            }
            if (hasNewTitle)
            {
                sb.Append("[").Append(ts).Append("]\n").Append(newTitle).Append("\n\n");
            }
            else
            {
                sb.Append("[").Append(ts).Append("]\n\n");
            }
            for (int i = 0; i < lines.Count; i++)
            {
                if (i == 0 && hasNewTitle) continue;
                sb.Append(lines[i]).Append("\n");
            }
            try { File.AppendAllText(filePath, sb.ToString(), new UTF8Encoding(false)); ShowTooltip("已追加到「" + filePath + "」"); }
            catch (Exception ex) { MessageBox.Show(this, "保存失败: " + ex.Message, "速记", MessageBoxButtons.OK, MessageBoxIcon.Error); }
        }
        else
        {
            // 新文件
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
            try { File.WriteAllText(filePath, sb.ToString(), new UTF8Encoding(false)); ShowTooltip("已保存到「" + filePath + "」"); }
            catch (Exception ex) { MessageBox.Show(this, "保存失败: " + ex.Message, "速记", MessageBoxButtons.OK, MessageBoxIcon.Error); }
        }
        return filePath;
    }

    private string SaveToTargetFile(string targetName, List<string> lines, string title)
        => SaveToSpecificFile(_targets[targetName], lines, title, targetName);

    private string SaveToSpecificFile(string filePath, List<string> lines, string title, string displayName)
    {
        var sb = new StringBuilder();
        sb.Append("\n\n\n");
        string ts = QuickNote.Timestamp();
        if (title.Length > 0)
            sb.Append("[").Append(ts).Append("]\n").Append("## ").Append(title).Append("\n\n");
        else
            sb.Append("[").Append(ts).Append("]\n\n");
        for (int i = 0; i < lines.Count; i++)
        {
            if (i == 0 && title.Length > 0 && Regex.IsMatch(lines[i], @"^##\s+")) continue;
            sb.Append(lines[i]).Append("\n");
        }
        try
        {
            File.AppendAllText(filePath, sb.ToString(), new UTF8Encoding(false));
            string tip = displayName.Length > 0 ? "已保存到「" + displayName + "」" : "已保存到「" + Path.GetFileName(filePath) + "」";
            ShowTooltip(tip);
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, "保存失败: " + ex.Message, "速记", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        return filePath;
    }

    private void DeleteSelected()
    {
        if (_listView.SelectedItems.Count == 0)
        {
            MessageBox.Show(this, "请先选择一个速记文件", "删除速记", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }
        string? filePath = _listView.SelectedItems[0].SubItems[3].Text;
        string fileName = _listView.SelectedItems[0].SubItems[0].Text;
        if (string.IsNullOrEmpty(filePath) || !File.Exists(filePath)) return;
        try
        {
            File.Delete(filePath);
            LoadFilesToList(_searchEdit.Text);
            ShowTooltip("已删除「" + fileName + "」");
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, "删除失败: " + ex.Message, "删除速记", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private void ShowTooltip(string msg) =>
        AppState.TrayIcon?.ShowBalloonTip(2000, "CapsLock++", msg, ToolTipIcon.Info);
}
