using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using CapsLockPro.Core;
using CapsLockPro.Features;

namespace CapsLockPro.Views;

/// <summary>速记 GUI（双列：左列表 + 右编辑区）。数据层见 <see cref="NoteRepository"/>。</summary>
public partial class QuickNoteWindow : Window
{
    private readonly NoteRepository _repo;
    private NoteEntry? _current;
    private bool _loading;
    private string _filter = "";

    // 列表行（供 GridView 绑定；NoteEntry 的 Mtime 是 DateTime 不便直接显示）
    private record NoteRow(string Title, string MtimeText, string Path, string Category, DateTime Mtime, string Body);

    internal QuickNoteWindow(NoteRepository repo)
    {
        InitializeComponent();
        _repo = repo;
        Loaded += (_, _) => { NewNote(); };
        PopulateCategoryBox(NoteRepository.Unclassified);
        ReloadList();
    }

    /// <summary>外部（QuickNote.Refresh）通知仓库可能变化，重刷分类+列表。</summary>
    public void ReloadFromRepository()
    {
        string? sel = CategoryBox.SelectedItem as string;
        PopulateCategoryBox(sel ?? NoteRepository.Unclassified);
        ReloadList();
    }

    // —— 顶栏 ——

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

    private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        _filter = SearchBox.Text ?? "";
        ReloadList();
    }

    private void NewNote_Click(object sender, RoutedEventArgs e) => NewNote();

    private void Save_Click(object sender, RoutedEventArgs e) => SaveCurrent();

    private void Delete_Click(object sender, RoutedEventArgs e)
    {
        if (_current == null || _current.IsNew)
        {
            MessageBox.Show("没有可删除的速记（当前是新建未保存内容）", "删除速记", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }
        var name = System.IO.Path.GetFileName(_current.Path);
        if (MessageBox.Show("确认删除「" + name + "」？", "删除速记", MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes) return;
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
        if (_loading) return;
        StatusBar.Text = "提示: 未保存改动 | Ctrl+S 保存";
    }

    private void SaveCurrent()
    {
        string title = TitleBox.Text.Trim();
        string body = BodyBox.Text;
        if (string.IsNullOrWhiteSpace(body) && string.IsNullOrWhiteSpace(title))
        {
            MessageBox.Show("标题和正文都为空，未保存", "速记", MessageBoxButton.OK, MessageBoxImage.Warning);
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
        catch (Exception ex) { MessageBox.Show("保存失败: " + ex.Message, "速记", MessageBoxButton.OK, MessageBoxImage.Error); return; }

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
