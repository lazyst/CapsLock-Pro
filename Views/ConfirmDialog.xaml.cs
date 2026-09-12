using System.Windows;

namespace CapsLockPro.Views;

/// <summary>通用确认/提示对话框（Modern 风格，替代原生 MessageBox）。危险动作用红按钮。</summary>
public partial class ConfirmDialog : Window
{
    private bool _ok;

    /// <param name="title">窗口标题。</param>
    /// <param name="message">正文消息。</param>
    /// <param name="danger">危险动作（删除）→ 确认按钮用红色 BtnDanger，文案“确认删除”。</param>
    /// <param name="info">仅提示（单按钮）→ 隐藏取消，确认按钮文案“确定”。</param>
    private ConfirmDialog(string title, string message, bool danger, bool info)
    {
        InitializeComponent();
        Title = title;
        DialogTitle.Text = title;
        MessageText.Text = message;

        if (info)
        {
            CancelBtn.Visibility = Visibility.Collapsed;
            OkBtn.Style = (Style)FindResource("BtnPrimary");
            OkBtn.Content = "确定";
        }
        else if (danger)
        {
            OkBtn.Style = (Style)FindResource("BtnDanger");
            OkBtn.Content = "确认删除";
        }

        Loaded += (_, _) => OkBtn.Focus();
    }

    /// <summary>是/否确认。danger=true 时确认按钮为红色。返回是否确认。</summary>
    public static bool Confirm(Window? owner, string title, string message, bool danger = false)
    {
        var dlg = new ConfirmDialog(title, message, danger, false);
        if (owner != null) dlg.Owner = owner;
        dlg.ShowDialog();
        return dlg._ok;
    }

    /// <summary>单按钮提示。</summary>
    public static void Info(Window? owner, string title, string message)
    {
        var dlg = new ConfirmDialog(title, message, false, true);
        if (owner != null) dlg.Owner = owner;
        dlg.ShowDialog();
    }

    private void Ok_Click(object sender, RoutedEventArgs e)
    {
        _ok = true;
        DialogResult = true;
    }

    private void Cancel_Click(object sender, RoutedEventArgs e) => DialogResult = false;
}
