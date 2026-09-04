using System.Drawing;
using System.Text;
using System.Windows.Forms;
using CapsLockPro.Native;

namespace CapsLockPro.Features;

/// <summary>
/// 帮助面板（对应原版 lib/ui/HelpPanel.ahk）。CapsLock+`` ` ``（扫描码 SC029）切换。
/// 无边框置顶工具窗口 + 只读 TextBox 展示热键速查表（9 分类）；
/// Esc / 失焦 / 再次按 CapsLock+`` ` `` 关闭。
/// </summary>
/// <remarks>
/// 翻译助手(CapsLock+T)按用户决定不复刻，故速查表不列该项。
/// 阶段5 的杂项热键(放大镜/双引号/花括号/速记/搜索/配置助手)在原版速查表中列出，
/// 本表一并列出（前瞻性，阶段5 落地后即生效）。
/// </remarks>
internal static class HelpPanel
{
    private static HelpForm? _form;

    /// <summary>切换显示/关闭（钩子在 CapsLock+SC029 时调用）。</summary>
    public static void Toggle()
    {
        if (_form != null && !_form.IsDisposed)
        {
            Close();
            return;
        }
        _form = new HelpForm(BuildHelpText());
        _form.FormClosed += (_, _) => _form = null;
        _form.Show();
    }

    public static void Close()
    {
        if (_form != null && !_form.IsDisposed)
        {
            try { _form.Close(); } catch { /* 静默 */ }
        }
        _form = null;
    }

    // —— 热键速查表（对应 BuildHelpText）——

    private static readonly (string Name, (string Key, string Desc)[] Items)[] Categories =
    {
        ("基本功能", new[]
        {
            ("CapsLock (单击, <0.3s)", "发送 Esc"),
            ("CapsLock (长按, >=0.3s)", "犹豫操作，无动作"),
            ("CapsLock + Esc", "禁用 / 启用 CapsLock++"),
            ("Ctrl + CapsLock", "手动切换大写锁定状态"),
            ("Ctrl + Alt + I", "显示调试信息"),
        }),
        ("光标移动", new[]
        {
            ("CapsLock + E", "上移一行"),
            ("CapsLock + D", "下移一行"),
            ("CapsLock + S", "左移一个字符"),
            ("CapsLock + F", "右移一个字符"),
            ("CapsLock + A", "左移一个单词"),
            ("CapsLock + G", "右移一个单词"),
            ("CapsLock + W", "移动到行首"),
            ("CapsLock + R", "移动到行尾"),
            ("CapsLock + Alt + A", "移动到文件开头"),
            ("CapsLock + Alt + G", "移动到文件末尾"),
        }),
        ("文本选择", new[]
        {
            ("CapsLock + H", "向左选择一个单词"),
            ("CapsLock + ;", "向右选择一个单词"),
            ("CapsLock + J", "向左选择一个字符"),
            ("CapsLock + L", "向右选择一个字符"),
            ("CapsLock + I", "向上选择一行"),
            ("CapsLock + K", "向下选择一行"),
            ("CapsLock + U", "选择到行首"),
            ("CapsLock + O", "选择到行尾"),
            ("CapsLock + Alt + H", "选择到文件开头"),
            ("CapsLock + Alt + ;", "选择到文件末尾"),
        }),
        ("删除操作", new[]
        {
            ("CapsLock + ,", "向左删除一个字符 (Backspace)"),
            ("CapsLock + .", "向右删除一个字符 (Delete)"),
            ("CapsLock + M", "删除到行首"),
            ("CapsLock + /", "删除到行尾"),
            ("CapsLock + Backspace", "删除整行"),
            ("CapsLock + Alt + M", "删除到文件开头"),
            ("CapsLock + Alt + /", "删除到文件末尾"),
        }),
        ("编辑操作", new[]
        {
            ("CapsLock + Z", "撤销"),
            ("CapsLock + Y", "重做"),
            ("CapsLock + X", "剪切 (独立剪切板)"),
            ("CapsLock + C", "复制 (独立剪切板)"),
            ("CapsLock + V", "粘贴 (独立剪切板)"),
            ("CapsLock + B", "任务视图 (Win+Tab)"),
            ("CapsLock + Enter", "行尾插入换行"),
            ("CapsLock + RShift", "行首上方插入空行"),
            ("CapsLock + [", "输入左花括号 { "),
            ("CapsLock + ]", "输入右花括号 } "),
            ("CapsLock + '", "输入双引号 \" "),
            ("CapsLock + 9 (空组)", "输入左圆括号 ( "),
            ("CapsLock + 0 (空组)", "输入右圆括号 ) "),
        }),
        ("窗口管理", new[]
        {
            ("CapsLock + 右键", "置顶 / 取消置顶窗口"),
            ("CapsLock + 左键", "文件重命名 (资源管理器)"),
            ("屏幕底部滚轮", "鼠标在底部5px → 调音量"),
        }),
        ("鼠标模式 (CapsLock+Space 进入)", new[]
        {
            ("E / D / S / F", "上 / 下 / 左 / 右 移动光标"),
            ("Q / A", "提高 / 降低移动速度"),
            ("W", "鼠标左键点击"),
            ("R", "鼠标右键点击"),
            ("J / K", "向下 / 向上 滚轮"),
            ("H / L", "向左 / 向右 水平滚轮"),
            ("Esc / CapsLock+Space", "退出鼠标模式"),
        }),
        ("快捷菜单", new[]
        {
            ("CapsLock + 1 ~ 0", "打开菜单组 1 ~ 10"),
            ("菜单内 1 ~ 0", "执行对应菜单项"),
            ("菜单内 Esc / 关闭按钮", "关闭菜单"),
            ("菜单外点击", "自动关闭菜单"),
        }),
        ("实用工具", new[]
        {
            ("CapsLock + Q", "搜索选中文本 / 打开URL / 打开路径"),
            ("CapsLock + Tab", "放大镜 开/关"),
            ("CapsLock + N", "打开速记窗口"),
            ("CapsLock + P", "符号跳转 (配对括号等)"),
            ("CapsLock + \\", "配置助手"),
            ("CapsLock + `", "帮助面板 (本窗口)"),
        }),
    };

    /// <summary>生成速查表文本（CJK 字符按 2 宽、ASCII 按 1 宽对齐，与 AHK 一致）。</summary>
    private static string BuildHelpText()
    {
        const int keyWidth = 32;
        const string sep = "  ";
        var sb = new StringBuilder();

        foreach (var cat in Categories)
        {
            // 标题居中（━ 填充至 68 宽）
            string title = "  " + cat.Name + "  ";
            int totalPad = 68 - DisplayWidth(title);
            int leftPad = totalPad / 2;
            int rightPad = totalPad - leftPad;
            sb.Append("\r\n");
            sb.Append(new string('━', leftPad)).Append(title).Append(new string('━', rightPad));
            sb.Append("\r\n\r\n");

            foreach (var item in cat.Items)
            {
                string paddedKey = item.Key;
                int need = keyWidth - DisplayWidth(paddedKey);
                while (need > 0) { paddedKey += " "; need--; }
                sb.Append("  ").Append(paddedKey).Append(sep).Append(item.Desc).Append("\r\n");
            }
        }

        sb.Append("\r\n").Append(new string('━', 68)).Append("\r\n");
        sb.Append("  提示: 按 Esc 或点击外部区域关闭  |  再次按 CapsLock + ` 关闭\r\n");
        return sb.ToString();
    }

    /// <summary>显示宽度：CJK(>127)=2，ASCII=1。</summary>
    private static int DisplayWidth(string s)
    {
        int w = 0;
        foreach (var ch in s)
            w += (ch > 127) ? 2 : 1;
        return w;
    }
}

/// <summary>帮助面板窗口（无边框置顶 + 只读 TextBox）。</summary>
internal sealed class HelpForm : Form
{
    public HelpForm(string text)
    {
        FormBorderStyle = FormBorderStyle.None;
        StartPosition = FormStartPosition.Manual;
        TopMost = true;
        ShowInTaskbar = false;
        KeyPreview = true;
        BackColor = Color.White;
        ClientSize = new Size(520, 500);

        var title = new Label
        {
            Text = "CapsLock++ 热键速查",
            Bounds = new Rectangle(0, 0, 520, 36),
            BackColor = Color.FromArgb(0xF5, 0xF5, 0xF5),
            Font = new Font("Segoe UI", 12f, FontStyle.Bold),
            TextAlign = ContentAlignment.MiddleCenter,
        };
        Controls.Add(title);

        var edit = new TextBox
        {
            Multiline = true,
            ReadOnly = true,
            ScrollBars = ScrollBars.Vertical,
            Bounds = new Rectangle(10, 42, 500, 410),
            Font = new Font("Consolas", 10f),
            Text = text,
            BorderStyle = BorderStyle.None,
        };
        Controls.Add(edit);

        var close = new Button
        {
            Text = "关闭 (Esc)",
            Bounds = new Rectangle(195, 460, 130, 32),
            FlatStyle = FlatStyle.Flat,
            Font = new Font("Segoe UI", 10f),
        };
        close.Click += (_, _) => Close();
        Controls.Add(close);

        var wa = Screen.PrimaryScreen!.WorkingArea;
        Location = new Point(wa.X + (wa.Width - Width) / 2, wa.Y + (wa.Height - Height) / 2);
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        int pref = Win32.DwmwcpRound;
        try { Win32.DwmSetWindowAttribute(Handle, Win32.DwmwaWindowCornerPreference, ref pref, sizeof(int)); }
        catch { /* 旧系统忽略 */ }
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        base.OnKeyDown(e);
        if (e.KeyCode == Keys.Escape)
        {
            Close();
            e.Handled = true;
        }
    }

    protected override void OnDeactivate(EventArgs e)
    {
        base.OnDeactivate(e);
        if (!IsDisposed) Close();
    }
}
