using System.Drawing;
using System.Windows.Forms;

namespace CapsLockPro.Features;

/// <summary>
/// 通用单行输入对话框（对应 AHK InputBox）。模态；返回 (是否确定, 值)。
/// </summary>
internal static class InputDialog
{
    public static (bool ok, string value) Show(IWin32Window? owner, string title, string prompt, string defaultValue = "")
    {
        using var f = new Form
        {
            Text = title,
            FormBorderStyle = FormBorderStyle.FixedDialog,
            StartPosition = FormStartPosition.CenterParent,
            ClientSize = new Size(360, 130),
            MaximizeBox = false,
            MinimizeBox = false,
        };
        UiTheme.Apply(f);
        var lbl = new Label { Text = prompt, Bounds = new Rectangle(10, 12, 340, 22), ForeColor = UiTheme.HintText, Font = UiTheme.UiFont };
        var tb = new TextBox { Text = defaultValue, Bounds = new Rectangle(10, 42, 340, 27) };
        UiTheme.StyleTextBox(tb);
        var okBtn = new Button { Text = "确定", Bounds = new Rectangle(190, 82, 75, 30), DialogResult = DialogResult.OK };
        var cancelBtn = new Button { Text = "取消", Bounds = new Rectangle(275, 82, 75, 30), DialogResult = DialogResult.Cancel };
        UiTheme.StyleButton(okBtn, UiTheme.ButtonRole.Primary, false);
        UiTheme.StyleButton(cancelBtn, UiTheme.ButtonRole.Secondary, false);
        f.Controls.AddRange(new Control[] { lbl, tb, okBtn, cancelBtn });
        f.AcceptButton = okBtn;
        f.CancelButton = cancelBtn;
        f.Load += (_, _) => { tb.Focus(); tb.SelectAll(); };
        var result = owner == null ? f.ShowDialog() : f.ShowDialog(owner);
        return result == DialogResult.OK ? (true, tb.Text) : (false, "");
    }
}
