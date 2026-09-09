// WPF 迁移期全局 using：开启 <UseWPF> 后 SDK 隐式 using 集合不再包含 System.IO，
// 且 WinForms 与 WPF 同名类型（Button/KeyEventArgs/MessageBox/HorizontalAlignment 等）
// 在 <UseWindowsForms> 仍为 true 的过渡期会产生歧义；此文件统一以 WPF 命名为准。
global using System.IO;

global using Application = System.Windows.Application;
global using Key = System.Windows.Input.Key;
global using KeyEventArgs = System.Windows.Input.KeyEventArgs;
global using ModifierKeys = System.Windows.Input.ModifierKeys;
global using MessageBox = System.Windows.MessageBox;
global using MessageBoxResult = System.Windows.MessageBoxResult;
global using MessageBoxButton = System.Windows.MessageBoxButton;
global using MessageBoxImage = System.Windows.MessageBoxImage;
global using Button = System.Windows.Controls.Button;
global using TextBlock = System.Windows.Controls.TextBlock;
global using HorizontalAlignment = System.Windows.HorizontalAlignment;
global using VerticalAlignment = System.Windows.VerticalAlignment;
global using FontWeights = System.Windows.FontWeights;
global using Visibility = System.Windows.Visibility;
global using MouseEventArgs = System.Windows.Input.MouseEventArgs;
global using MouseButtonEventArgs = System.Windows.Input.MouseButtonEventArgs;
global using TextChangedEventArgs = System.Windows.Controls.TextChangedEventArgs;
global using SelectionChangedEventArgs = System.Windows.Controls.SelectionChangedEventArgs;
