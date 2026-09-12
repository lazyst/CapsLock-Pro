using System.IO;
using CapsLockPro.Config;

namespace CapsLockPro.Core;

/// <summary>
/// 配置路径定位 + 旧版 ini 一次性迁移。
/// 定位 CapsLock++.json（dev 上溯 3 级到仓库根，prod exe 同级）。
/// 首启检测：json 不存在但旧 CapsLock++.ini 存在 → 自动迁移（读 ini→写 json），
/// 旧 ini 改名 .migrated 备份，避免误用两套配置。
/// 统一此处后，App / MenuSystem / TerminalLauncher / MouseMode 不再各自拼路径
/// （原先 App 上溯 3 级、MouseMode 上溯 5 级，规则不一致）。
/// </summary>
internal static class ConfigLocator
{
    public static string FindPath()
    {
        var jsonCandidates = new[]
        {
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "CapsLock++.json"),
            Path.Combine(AppContext.BaseDirectory, "CapsLock++.json"),
        };
        foreach (var p in jsonCandidates)
            if (File.Exists(p)) return p;

        // 迁移旧 ini（与 ini 同目录生成 json）
        var iniCandidates = new[]
        {
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "CapsLock++.ini"),
            Path.Combine(AppContext.BaseDirectory, "CapsLock++.ini"),
        };
        foreach (var ini in iniCandidates)
        {
            if (!File.Exists(ini)) continue;
            var cfg = AppConfig.MigrateFromIni(ini);
            string jsonPath = Path.Combine(Path.GetDirectoryName(ini)!, "CapsLock++.json");
            cfg.Save(jsonPath);
            try { File.Move(ini, ini + ".migrated"); } catch { /* 备份失败不阻断 */ }
            return jsonPath;
        }

        return jsonCandidates[0]; // 全新：默认 dev 仓库根位置
    }
}
