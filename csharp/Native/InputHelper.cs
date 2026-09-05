using System.Runtime.InteropServices;

namespace CapsLockPro.Native;

/// <summary>
/// SendInput 封装（对应 AHK 的 Send/SendInput）。
/// 提供按键 down/up、组合键、文本输入等底层能力，供所有功能模块复用。
/// </summary>
internal static class InputHelper
{
    private const uint InputKeyboard = 1;
    private const uint KeyEventKeydown = 0x0000;
    private const uint KeyEventKeyup = 0x0002;
    private const uint KeyEventExtended = 0x0001; // 扩展键标志（方向键/Delete/Home 等）

    /// <summary>低级键盘输入结构（与 WH_KEYBOARD_LL 回调里的 KBDLLHOOKSTRUCT 一致）。</summary>
    /// <summary>x64 INPUT 布局（共 40 字节）：type@0，键盘 union@8（vk@8,scan@10,flags@12,time@16,extra@24）。</summary>
    [StructLayout(LayoutKind.Explicit, Size = 40)]
    private struct Input
    {
        [FieldOffset(0)] public int Type;
        [FieldOffset(8)] public ushort Vk;     // KEYBDINPUT.wVk（union 起始偏移 8）
        [FieldOffset(10)] public ushort Scan;  // wScan
        [FieldOffset(12)] public uint Flags;   // dwFlags
        [FieldOffset(16)] public uint Time;    // time
        [FieldOffset(24)] public IntPtr ExtraInfo; // dwExtraInfo
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint nInputs, Input[] pInputs, int cbSize);

    [DllImport("user32.dll")]
    private static extern ushort VkKeyScanW(char ch);

    [DllImport("user32.dll")]
    private static extern ushort MapVirtualKey(uint uCode, uint uMapType);

    private const uint MapvkVkToScancode = 0;

    /// <summary>用扫描码发送一次按键 down+up（绕过键盘布局，更可靠）。</summary>
    public static void Tap(ushort vk)
    {
        Down(vk);
        Up(vk);
    }

    /// <summary>按下虚拟键。</summary>
    public static void Down(ushort vk)
    {
        SendOne(vk, down: true);
    }

    /// <summary>释放虚拟键。</summary>
    public static void Up(ushort vk)
    {
        SendOne(vk, down: false);
    }

    /// <summary>发送组合键（如 Ctrl+C）：依次 down 各键，再逆序 up。</summary>
    public static void Combo(params ushort[] vks)
    {
        foreach (var vk in vks) Down(vk);
        for (int i = vks.Length - 1; i >= 0; i--) Up(vks[i]);
    }

    /// <summary>发送单字符（用 VkKeyScanW 取虚拟键 + shift 状态，模拟键盘输入）。</summary>
    public static void SendChar(char ch)
    {
        var vks = VkKeyScanW(ch);
        var vk = (ushort)(vks & 0xFF);
        var shift = (vks >> 8) != 0;
        if (shift) Down(0xA0); // VK_LSHIFT
        Tap(vk);
        if (shift) Up(0xA0);
    }

    /// <summary>发送文本字符串（逐字符 SendChar，对应 AHK SendText）。</summary>
    public static void SendText(string text)
    {
        foreach (var ch in text) SendChar(ch);
    }

    private static void SendOne(ushort vk, bool down)
    {
        uint flags = (down ? KeyEventKeydown : KeyEventKeyup);
        if (IsExtendedKey(vk)) flags |= KeyEventExtended;
        var input = new Input
        {
            Type = (int)InputKeyboard,
            Vk = vk,
            Scan = 0,
            Flags = flags,
            Time = 0,
            ExtraInfo = IntPtr.Zero,
        };
        var buf = new[] { input };
        SendInput(1, buf, Marshal.SizeOf<Input>());
    }

    /// <summary>扩展键判定（发送时需 KEYEVENTF_EXTENDEDKEY）。</summary>
    private static bool IsExtendedKey(ushort vk) => vk switch
    {
        0x21 => true,  // VK_PRIOR  (PageUp)
        0x22 => true,  // VK_NEXT   (PageDown)
        0x23 => true,  // VK_END
        0x24 => true,  // VK_HOME
        0x25 => true,  // VK_LEFT
        0x26 => true,  // VK_UP
        0x27 => true,  // VK_RIGHT
        0x28 => true,  // VK_DOWN
        0x2D => true,  // VK_INSERT
        0x2E => true,  // VK_DELETE
        0x5B => true,  // VK_LWIN
        0x5C => true,  // VK_RWIN
        0x6F => true,  // VK_DIVIDE (numpad /)
        _ => false,
    };
}
