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
            ClientSize = new Size(360, 120),
            MaximizeBox = false,
            MinimizeBox = false,
            Font = new Font("Segoe UI", 10f),
        };
        var lbl = new Label { Text = prompt, Bounds = new Rectangle(10, 10, 340, 22) };
        var tb = new TextBox { Text = defaultValue, Bounds = new Rectangle(10, 38, 340, 25) };
        var okBtn = new Button { Text = "确定", Bounds = new Rectangle(190, 78, 75, 28), DialogResult = DialogResult.OK };
        var cancelBtn = new Button { Text = "取消", Bounds = new Rectangle(275, 78, 75, 28), DialogResult = DialogResult.Cancel };
        f.Controls.AddRange(new Control[] { lbl, tb, okBtn, cancelBtn });
        f.AcceptButton = okBtn;
        f.CancelButton = cancelBtn;
        f.Load += (_, _) => { tb.Focus(); tb.SelectAll(); };
        var result = owner == null ? f.ShowDialog() : f.ShowDialog(owner);
        return result == DialogResult.OK ? (true, tb.Text) : (false, "");
    }
}
