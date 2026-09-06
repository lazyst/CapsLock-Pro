using System.ComponentModel;
using System.Drawing;
using System.Windows.Forms;

namespace CapsLockPro.Features;

/// <summary>
/// 菜单项添加/编辑对话框（对应 lib/ConfigHelper.ahk 的 MenuAddItem / MenuEditItem editGui）。
/// 名称 + 命令 + 终端下拉 + 保持窗口勾选 + 完整命令预览（实时刷新）。
/// </summary>
internal sealed class MenuItemEditDialog : Form
{
    private readonly TextBox _nameEdit;
    private readonly TextBox _cmdEdit;
    private readonly ComboBox _terminalDdl;
    private readonly CheckBox _keepWindowCb;
    private readonly TextBox _previewEdit;
    private string _terminalKey = "direct";

    /// <summary>结果（确定时填充）。</summary>
    public string ItemName { get; private set; } = "";
    public string Cmd { get; private set; } = "";
    public string Terminal { get; private set; } = "direct";
    public bool KeepWindow { get; private set; }

    public MenuItemEditDialog(string title, string name, string cmd, string terminal, bool keepWindow)
    {
        Text = title;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        StartPosition = FormStartPosition.CenterParent;
        ClientSize = new Size(380, 210);
        MaximizeBox = false;
        MinimizeBox = false;
        UiTheme.Apply(this);

        Controls.Add(new Label { Text = "名称:", Bounds = new Rectangle(10, 15, 80, 23) });
        _nameEdit = new TextBox { Bounds = new Rectangle(100, 12, 260, 23), Text = name };

        Controls.Add(new Label { Text = "命令:", Bounds = new Rectangle(10, 48, 80, 23) });
        _cmdEdit = new TextBox { Bounds = new Rectangle(100, 45, 260, 23), Text = cmd };

        Controls.Add(new Label { Text = "终端:", Bounds = new Rectangle(10, 80, 80, 23) });
        _terminalDdl = new ComboBox { Bounds = new Rectangle(100, 77, 150, 24), DropDownStyle = ComboBoxStyle.DropDownList };
        foreach (var (display, key) in CommandString.Terminals)
            _terminalDdl.Items.Add(display);
        _terminalKey = terminal;
        int sel = 0;
        for (int i = 0; i < CommandString.Terminals.Length; i++)
            if (CommandString.Terminals[i].key == terminal) { sel = i; break; }
        _terminalDdl.SelectedIndex = sel;

        _keepWindowCb = new CheckBox { Text = "保持窗口", Bounds = new Rectangle(260, 80, 100, 20), Checked = keepWindow };

        Controls.Add(new Label { Text = "完整命令:", Bounds = new Rectangle(10, 112, 80, 23) });
        _previewEdit = new TextBox { Bounds = new Rectangle(100, 109, 260, 23), ReadOnly = true };

        var okBtn = new Button { Text = "确定", Bounds = new Rectangle(180, 158, 80, 30), DialogResult = DialogResult.OK };
        var cancelBtn = new Button { Text = "取消", Bounds = new Rectangle(270, 158, 80, 30), DialogResult = DialogResult.Cancel };
        UiTheme.StyleButton(okBtn, UiTheme.ButtonRole.Primary, false);
        UiTheme.StyleButton(cancelBtn, UiTheme.ButtonRole.Secondary, false);

        Controls.AddRange(new Control[] { _nameEdit, _cmdEdit, _terminalDdl, _keepWindowCb, _previewEdit, okBtn, cancelBtn });
        AcceptButton = okBtn;
        CancelButton = cancelBtn;

        _cmdEdit.TextChanged += (_, _) => UpdatePreview();
        _terminalDdl.SelectedIndexChanged += (_, _) => { _terminalKey = CommandString.Terminals[_terminalDdl.SelectedIndex].key; UpdatePreview(); };
        _keepWindowCb.CheckedChanged += (_, _) => UpdatePreview();

        UpdatePreview();
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        UiTheme.EnableRounded(Handle);
    }

    private void UpdatePreview() =>
        _previewEdit.Text = CommandString.Build(_cmdEdit.Text, _terminalKey, _keepWindowCb.Checked);

    protected override void OnLoad(EventArgs e)
    {
        base.OnLoad(e);
        _nameEdit.Focus();
        _nameEdit.SelectAll();
    }

    protected override void OnClosing(CancelEventArgs e)
    {
        base.OnClosing(e);
        if (DialogResult == DialogResult.OK)
        {
            if (string.IsNullOrWhiteSpace(_nameEdit.Text)) { e.Cancel = true; return; }
            ItemName = _nameEdit.Text;
            Cmd = _cmdEdit.Text;
            Terminal = _terminalKey;
            KeepWindow = _keepWindowCb.Checked;
        }
    }
}
