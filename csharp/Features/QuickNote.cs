using System.Diagnostics;
using System.Text.RegularExpressions;
using CapsLockPro.Config;
using CapsLockPro.Views;

namespace CapsLockPro.Features;

/// <summary>
/// 速记（对应原版 lib/QuickNote.ahk）。CapsLock+N 切换速记窗口；
/// 保存格式：<c>## 标题</c> 首行、<c>==目标==</c> 末行（目标映射来自 CapsLock++.ini [noteTargets]）。
/// UI 见 <see cref="Views.QuickNoteWindow"/>；保存逻辑在窗口内（文件极小，UI 线程同步执行）。
/// </summary>
internal static class QuickNote
{
    private static QuickNoteWindow? _form;
    private static string? _iniPath;
    private static string _defaultDir = "";
    private static readonly Dictionary<string, string> _targets = new();

    /// <summary>启动时初始化（计算默认目录 + 加载目标）。由 App 调用。</summary>
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
            _targets["论文"] = Path.Combine(_defaultDir, "论文灵感.txt");
            _targets["日记"] = Path.Combine(_defaultDir, "日记.txt");
            _targets["工作"] = Path.Combine(_defaultDir, "工作.txt");
            _targets["想法"] = Path.Combine(_defaultDir, "想法.txt");
        }
    }

    /// <summary>CapsLock+N 切换：已打开则关闭，否则打开。</summary>
    public static void Toggle()
    {
        if (_form != null)
        {
            _form.Close();
            _form = null;
            return;
        }
        EnsureNoteDirectories();
        _form = new QuickNoteWindow(_defaultDir, _targets);
        _form.Closed += (_, _) => _form = null;
        _form.Show();
    }

    private static string ComputeDefaultDir(string? iniPath)
    {
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