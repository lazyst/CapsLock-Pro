using System.Windows;
using System.Windows.Input;

namespace CapsLockPro.Views;

/// <summary>帮助面板窗口（无边框置顶 + 只读滚动文本）。Esc / 失焦 / 关闭按钮 关闭。</summary>
public partial class HelpPanelWindow : Window
{
    public HelpPanelWindow(string text)
    {
        InitializeComponent();
        ContentText.Text = text;
    }

    private void Window_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape) { Close(); e.Handled = true; }
    }

    private void Window_Deactivated(object sender, EventArgs e) => Close();

    private void Close_Click(object sender, RoutedEventArgs e) => Close();
}
