// WPF 项目全局 using。
// <UseWPF>true</UseWPF> 开启后 SDK 隐式 using 集合不再包含 System.IO，故显式补回。
// <UseWindowsForms>true</UseWindowsForms> 用于 FolderBrowserDialog（现代文件夹选择器，
// 内部走 IFileOpenDialog broker，带快速访问导航栏）。WinForms 与 WPF 同名类型
//（Button/KeyEventArgs/MessageBox/Application 等）在此以 WPF 命名为准消歧。
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
