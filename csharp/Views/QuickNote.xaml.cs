using System.IO;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using CapsLockPro.Core;
using CapsLockPro.Features;

namespace CapsLockPro.Views;

/// <summary>速记 GUI（双列：左列表 + 右编辑区，正文带行号）。数据层见 <see cref="NoteRepository"/>。</summary>
public partial class QuickNoteWindow : Window
{
    private readonly NoteRepository _repo;
    private NoteEntry? _current;
    private bool _loading;
    private string _filter = "";

    private ScrollViewer? _bodyScroll;

    // 搜索防抖：按键间隙不重扫目录，停顿 300ms 后统一刷新一次
    private DispatcherTimer? _searchDebounce;

    // 列表行（供 GridView 绑定；NoteEntry 的 Mtime 是 DateTime 不便直接显示）
    private record NoteRow(string Title, string MtimeText, string Path, string Category, DateTime Mtime, string Body);

    internal QuickNoteWindow(NoteRepository repo)
    {
        InitializeComponent();
        _repo = repo;
        _searchDebounce = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(300) };
        _searchDebounce.Tick += (_, _) => { _searchDebounce.Stop(); ReloadList(); };
        Loaded += OnLoaded;
        PopulateCategoryBox(NoteRepository.Unclassified);
        ReloadList();
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        // 钩住 BodyBox 内部 ScrollViewer，按垂直滚动偏移平移行号 gutter
        _bodyScroll = FindVisualChild<ScrollViewer>(BodyBox);
        if (_bodyScroll != null) _bodyScroll.ScrollChanged += BodyScroll_ScrollChanged;
        NewNote();
    }

    /// <summary>外部（QuickNote.Refresh）通知仓库可能变化，重刷分类+列表。</summary>
    public void ReloadFromRepository()
    {
        string? sel = CategoryBox.SelectedItem as string;
        PopulateCategoryBox(sel ?? NoteRepository.Unclassified);
        ReloadList();
    }

    // —— 顶栏：分类 ——

    private void CategoryBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_loading) return;
        ReloadList();
    }

    private void NewCategory_Click(object sender, RoutedEventArgs e)
    {
        var (ok, name) = InputDialog.Show(this, "新建分类", "输入分类名:");
        if (!ok || string.IsNullOrWhiteSpace(name)) return;
        _repo.EnsureCategory(name.Trim());
        PopulateCategoryBox(name.Trim());
    }

    private void RenameCategory_Click(object sender, RoutedEventArgs e)
    {
        string? cat = SelectedRealCategory();
        if (cat == null)
        {
            ConfirmDialog.Info(this, "重命名分类", "请先在下拉框选择一个具体分类（不能是“全部”）");
            return;
        }
        var (ok, name) = InputDialog.Show(this, "重命名分类", "输入新分类名:", cat);
        if (!ok || string.IsNullOrWhiteSpace(name)) return;
        try { _repo.RenameCategory(cat, name.Trim()); }
        catch (Exception ex) { ConfirmDialog.Info(this, "重命名分类", ex.Message); return; }
        PopulateCategoryBox(name.Trim());
        // 当前编辑中的笔记若在被改名的分类，更新其分类归属
        if (_current != null && _current.Category == cat) _current = _repo.Load(_current.Path);
        ReloadList();
        TrayService.Notify("已重命名「" + cat + "」→「" + name.Trim() + "」");
    }

    private void DeleteCategory_Click(object sender, RoutedEventArgs e)
    {
        string? cat = SelectedRealCategory();
        if (cat == null)
        {
            ConfirmDialog.Info(this, "删除分类", "请先在下拉框选择一个具体分类（不能是“全部”）");
            return;
        }
        int count = _repo.CountNotes(cat);
        string msg = count == 0
            ? "确认删除空分类「" + cat + "」？"
            : "确认删除分类「" + cat + "」及其下 " + count + " 条速记？此操作不可撤销。";
        if (!ConfirmDialog.Confirm(this, "删除分类", msg, danger: true)) return;
        int removed = _repo.DeleteCategory(cat);
        if (_current != null && _current.Category == cat) { _current = null; NewNote(); }
        PopulateCategoryBox(NoteRepository.AllCategories);
        ReloadList();
        TrayService.Notify("已删除分类「" + cat + "」（" + removed + " 条速记）");
    }

    private string? SelectedRealCategory()
        => CategoryBox.SelectedItem is string s && s != NoteRepository.AllCategories ? s : null;

    private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        _filter = SearchBox.Text ?? "";
        // 防抖：停顿 300ms 后重扫一次，避免每键都全量扫目录+读文件
        _searchDebounce?.Stop();
        _searchDebounce?.Start();
    }

    private void NewNote_Click(object sender, RoutedEventArgs e) => NewNote();

    private void Save_Click(object sender, RoutedEventArgs e) => SaveCurrent();

    private void Delete_Click(object sender, RoutedEventArgs e)
    {
        if (_current == null || _current.IsNew)
        {
            ConfirmDialog.Info(this, "删除速记", "当前是新建未保存内容，没有可删除的速记");
            return;
        }
        var name = System.IO.Path.GetFileName(_current.Path);
        if (!ConfirmDialog.Confirm(this, "删除速记", "确认删除「" + name + "」？此操作不可撤销。", danger: true)) return;
        _repo.Delete(_current.Path);
        TrayService.Notify("已删除「" + name + "」");
        _current = null;
        NewNote();
        ReloadList();
    }

    private void Close_Click(object sender, RoutedEventArgs e) => Close();

    // —— 列表 ——

    private void NoteList_DoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (NoteList.SelectedItem is not NoteRow row) return;
        var entry = _repo.Load(row.Path);
        if (entry == null) { ReloadList(); return; }
        LoadEntry(entry);
    }

    private void LoadEntry(NoteEntry entry)
    {
        _loading = true;
        _current = entry;
        TitleBox.Text = entry.Title;
        BodyBox.Text = entry.Body;
        _loading = false;
        BodyBox.ScrollToHome();
        UpdateLineNumbers();
        StatusBar.Text = "提示: 正在编辑「" + entry.Title + "」 | Ctrl+S 保存";
        BodyBox.Focus();
        BodyBox.CaretIndex = BodyBox.Text.Length;
    }

    private void ReloadList()
    {
        string? cat = CategoryBox.SelectedItem as string;
        if (string.IsNullOrEmpty(cat) || cat == NoteRepository.AllCategories) cat = null;
        var entries = _repo.List(cat, _filter);
        var rows = entries.Select(e => new NoteRow(
            string.IsNullOrEmpty(e.Title) ? System.IO.Path.GetFileNameWithoutExtension(e.Path) : e.Title,
            e.Mtime.ToString("yyyy-MM-dd HH:mm"),
            e.Path, e.Category, e.Mtime, e.Body)).ToList();
        string? keep = _current?.Path;
        NoteList.ItemsSource = rows;
        if (keep != null)
        {
            var sel = rows.FirstOrDefault(r => string.Equals(r.Path, keep, StringComparison.OrdinalIgnoreCase));
            if (sel != null) NoteList.SelectedItem = sel;
        }
    }

    private void PopulateCategoryBox(string selectName)
    {
        _loading = true;
        var cats = _repo.Categories();
        var items = new List<string> { NoteRepository.AllCategories };
        items.AddRange(cats);
        CategoryBox.ItemsSource = items;
        CategoryBox.SelectedItem = items.Contains(selectName) ? selectName : NoteRepository.AllCategories;
        _loading = false;
    }

    // —— 编辑区 ——

    private void NewNote()
    {
        _loading = true;
        _current = null;
        TitleBox.Text = "";
        BodyBox.Text = "";
        _loading = false;
        BodyBox.ScrollToHome();
        UpdateLineNumbers();
        StatusBar.Text = "提示: 输入标题与正文后 Ctrl+S 保存";
        TitleBox.Focus();
    }

    private void TitleBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        if (_loading) return;
        StatusBar.Text = "提示: 未保存改动 | Ctrl+S 保存";
    }

    private void BodyBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        UpdateLineNumbers();
        if (_loading) return;
        StatusBar.Text = "提示: 未保存改动 | Ctrl+S 保存";
    }

    private void BodyBox_SizeChanged(object sender, SizeChangedEventArgs e) => UpdateLineNumbers();

    // —— 行号 gutter ——

    private void BodyScroll_ScrollChanged(object sender, ScrollChangedEventArgs e)
    {
        LineNumbers.ScrollToVerticalOffset(e.VerticalOffset);
    }

    private void UpdateLineNumbers()
    {
        if (LineNumbers == null) return;
        int n = BodyBox.LineCount;
        if (n < 1) n = 1;
        var sb = new StringBuilder(n * 3);
        for (int i = 1; i <= n; i++) sb.Append(i).Append('\n');
        LineNumbers.Text = sb.ToString(0, sb.Length - 1); // 去末尾换行
        if (_bodyScroll != null) LineNumbers.ScrollToVerticalOffset(_bodyScroll.VerticalOffset);
    }

    private static T? FindVisualChild<T>(DependencyObject root) where T : DependencyObject
    {
        for (int i = 0; i < VisualTreeHelper.GetChildrenCount(root); i++)
        {
            var c = VisualTreeHelper.GetChild(root, i);
            if (c is T t) return t;
            var r = FindVisualChild<T>(c);
            if (r != null) return r;
        }
        return null;
    }

    private void SaveCurrent()
    {
        string title = TitleBox.Text.Trim();
        string body = BodyBox.Text;
        if (string.IsNullOrWhiteSpace(body) && string.IsNullOrWhiteSpace(title))
        {
            ConfirmDialog.Info(this, "速记", "标题和正文都为空，未保存");
            return;
        }

        string category = ResolveSaveCategory();
        string? oldPath = _current?.Path;
        var entry = new NoteEntry
        {
            Path = oldPath ?? "",
            Title = title,
            Category = category,
            Body = body,
            Mtime = DateTime.Now,
        };

        string savedPath;
        try { savedPath = _repo.Save(entry, oldPath); }
        catch (Exception ex) { ConfirmDialog.Info(this, "速记", "保存失败: " + ex.Message); return; }

        TrayService.Notify("已保存「" + (string.IsNullOrEmpty(title) ? System.IO.Path.GetFileNameWithoutExtension(savedPath) : title) + "」");
        _current = _repo.Load(savedPath);
        PopulateCategoryBox(category);
        ReloadList();
        StatusBar.Text = "提示: 已保存 | Ctrl+S 保存 | 双击列表载入";
        BodyBox.Focus();
    }

    private string ResolveSaveCategory()
    {
        if (CategoryBox.SelectedItem is string s && !string.IsNullOrEmpty(s) && s != NoteRepository.AllCategories)
            return s;
        return _current?.Category ?? NoteRepository.Unclassified;
    }

    private void Window_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.S && (Keyboard.Modifiers & ModifierKeys.Control) != 0)
        {
            SaveCurrent();
            e.Handled = true;
        }
    }
}
