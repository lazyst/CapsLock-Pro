// WPF 项目全局 using。
// 消歧：WPF 与同名类型（Button/KeyEventArgs/MessageBox/Application 等）在此以 WPF 命名为准。
// 文件夹选择改用 .NET 8 WPF 原生 Microsoft.Win32.OpenFolderDialog（不再引用 WinForms）。
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
global using CheckBox = System.Windows.Controls.CheckBox;
global using TextBlock = System.Windows.Controls.TextBlock;
global using HorizontalAlignment = System.Windows.HorizontalAlignment;
global using VerticalAlignment = System.Windows.VerticalAlignment;
global using FontWeights = System.Windows.FontWeights;
global using Visibility = System.Windows.Visibility;
global using MouseEventArgs = System.Windows.Input.MouseEventArgs;
global using MouseButtonEventArgs = System.Windows.Input.MouseButtonEventArgs;
global using TextChangedEventArgs = System.Windows.Controls.TextChangedEventArgs;
global using SelectionChangedEventArgs = System.Windows.Controls.SelectionChangedEventArgs;
