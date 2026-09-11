// WPF 项目全局 using。
// <UseWPF>true</UseWPF> 开启后 SDK 隐式 using 集合不再包含 System.IO，故显式补回。
// WinForms 已关闭（<UseWindowsForms>false</UseWindowsForms>），原 WPF/WinForms 同名类型消歧别名不再需要。
global using System.IO;
