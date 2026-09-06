using System.Drawing;
using System.Windows.Forms;
using CapsLockPro.Native;

namespace CapsLockPro.Features;

/// <summary>
/// 轻量统一 UI 主题（无第三方依赖）。提供现代浅色配色 + 按钮自适应尺寸（杜绝中文文字被遮挡）
/// + DWM 圆角 + 扁平按钮，供速记/配置助手/菜单/帮助四个窗口共用，保持视觉一致。
/// </summary>
internal static class UiTheme
{
    // —— 配色（现代浅色主题）——
    public static readonly Color Background = Color.FromArgb(0xF6, 0xF7, 0xF9);
    public static readonly Color Surface = Color.White;
    public static readonly Color Border = Color.FromArgb(0xC9, 0xCD, 0xD6);
    public static readonly Color Text = Color.FromArgb(0x1E, 0x1F, 0x2D);
    public static readonly Color SecondaryText = Color.FromArgb(0x6B, 0x70, 0x80);
    public static readonly Color HintText = Color.FromArgb(0x49, 0x4C, 0x5A);
    public static readonly Color Accent = Color.FromArgb(0x25, 0x63, 0xEB);
    public static readonly Color AccentHover = Color.FromArgb(0x1D, 0x4E, 0xD8);
    public static readonly Color Danger = Color.FromArgb(0xDC, 0x26, 0x26);
    public static readonly Color DangerHover = Color.FromArgb(0xB9, 0x1C, 0x1C);

    public static readonly Font UiFont = new("Segoe UI", 9.5f);
    public static readonly Font TitleFont = new("Segoe UI", 12f, FontStyle.Bold);
    public static readonly Font SmallFont = new("Segoe UI", 9f);

    public enum ButtonRole { Primary, Secondary, Danger }

    /// <summary>应用到窗体：背景色、默认字体、双缓冲、DWM 圆角。</summary>
    public static void Apply(Form f)
    {
        f.BackColor = Background;
        f.Font = UiFont;
        // DoubleBuffered 是 protected，用反射开启以消除闪烁
        try { typeof(Control).GetProperty("DoubleBuffered", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic)!.SetValue(f, true); }
        catch { /* 旧框架忽略 */ }
    }

    /// <summary>在窗体句柄创建后启用圆角（仅 Win11，旧系统静默）。</summary>
    public static void EnableRounded(IntPtr handle)
    {
        int pref = Win32.DwmwcpRound;
        try { Win32.DwmSetWindowAttribute(handle, Win32.DwmwaWindowCornerPreference, ref pref, sizeof(int)); }
        catch { /* 旧系统无 DWM 圆角 */ }
    }

    /// <summary>美化按钮：默认自适应尺寸（AutoSize，绝不裁剪文字）；autoSize=false 时保留调用方尺寸。
    /// 扁平风格 + 角色配色 + 悬停反馈。minWidth 控制自适应最小宽度（箭头等窄按钮传小值）。</summary>
    public static void StyleButton(Button b, ButtonRole role = ButtonRole.Secondary, bool autoSize = true, int minWidth = 92)
    {
        b.FlatStyle = FlatStyle.Flat;
        b.Font = UiFont;
        b.Cursor = Cursors.Hand;
        b.AutoSize = autoSize;
        if (autoSize)
        {
            b.AutoSizeMode = AutoSizeMode.GrowOnly;
            b.Margin = new Padding(8, 0, 8, 0);
            b.MinimumSize = new Size(minWidth, 30);
        }
        else
        {
            b.Padding = new Padding(8, 0, 8, 0);
            b.TextAlign = ContentAlignment.MiddleCenter;
        }
        b.FlatAppearance.BorderSize = 1;
        switch (role)
        {
            case ButtonRole.Primary:
                b.BackColor = Accent;
                b.ForeColor = Color.White;
                b.FlatAppearance.BorderColor = Accent;
                b.FlatAppearance.MouseOverBackColor = AccentHover;
                b.FlatAppearance.MouseDownBackColor = AccentHover;
                break;
            case ButtonRole.Danger:
                b.BackColor = Danger;
                b.ForeColor = Color.White;
                b.FlatAppearance.BorderColor = Danger;
                b.FlatAppearance.MouseOverBackColor = DangerHover;
                b.FlatAppearance.MouseDownBackColor = DangerHover;
                break;
            default: // Secondary
                b.BackColor = Surface;
                b.ForeColor = Text;
                b.FlatAppearance.BorderColor = Border;
                b.FlatAppearance.MouseOverBackColor = Color.FromArgb(0xF0, 0xF1, 0xF5);
                b.FlatAppearance.MouseDownBackColor = Color.FromArgb(0xE8, 0xEA, 0xEF);
                break;
        }
        b.Padding = new Padding(16, 7, 16, 7);
    }

    /// <summary>美化文本框：浅色边框、Surface 背景。</summary>
    public static void StyleTextBox(TextBox t)
    {
        t.BorderStyle = BorderStyle.FixedSingle;
        t.BackColor = Surface;
        t.ForeColor = Text;
    }

    /// <summary>美化列表视图：白底、行高亮、网格线。</summary>
    public static void StyleListView(ListView lv)
    {
        lv.BackColor = Surface;
        lv.ForeColor = Text;
        lv.BorderStyle = BorderStyle.FixedSingle;
        lv.OwnerDraw = false; // 用原生即可
    }

    /// <summary>美化标签：根据是否标题设置字号。</summary>
    public static void StyleLabel(Label l, bool title = false)
    {
        l.BackColor = Background;
        l.ForeColor = title ? Text : SecondaryText;
        if (title) l.Font = TitleFont;
    }
}
