// 配置适配器（统一入口）
// 将应用内部数据模型转换为各内核可识别的配置格式
// 支持 sing-box / mihomo / v2ray 三种内核配置生成
//
// 实际实现已拆分到 adapters/ 子目录：
// - SingboxAdapter (sing-box JSON 配置)
// - MihomoAdapter (mihomo 兼容的 JSON 配置)
// - V2rayAdapter (v2ray JSON 配置)
// - DnsConfigBuilder (跨内核 DNS 配置)
//
// 本文件保留 ConfigAdapter 静态方法入口以保持向后兼容

import '../models/config.dart';
import 'adapters/mihomo_adapter.dart';
import 'adapters/singbox_adapter.dart';
import 'adapters/v2ray_adapter.dart';

/// ConfigAdapter - 配置适配器统一入口（向后兼容）
///
/// 委托到 `adapters/` 目录下的具体适配器实现：
/// - [toSingboxConfig] → [SingboxAdapter.toConfig]
/// - [toMihomoConfig] → [MihomoAdapter.toConfig]
/// - [toV2rayConfig] → [V2rayAdapter.toConfig]
/// - [deepMerge] → 保留在原位置（跨内核工具）
///
/// 职责：
/// - 生成 sing-box JSON 配置（inbounds / outbounds / route / DNS / TUN）
/// - 生成 mihomo YAML 兼容的 JSON 配置（proxies / rules / DNS / TUN）
/// - 生成 v2ray JSON 配置（inbounds / outbounds / routing / DNS / TUN）
/// - 将 NodeConfig 转换为各内核的出站代理格式
/// - 支持 9 种代理协议：VMess / VLESS / Trojan / Shadowsocks / Hysteria / Hysteria2 / TUIC / Naive / WireGuard
class ConfigAdapter {
  /// 私有构造函数，防止外部实例化
  ConfigAdapter._();

  /// 生成 sing-box 内核配置
  ///
  /// 委托到 [SingboxAdapter.toConfig]
  static Map<String, dynamic> toSingboxConfig(
    ProxyConfig proxyConfig,
    NodeConfig? activeNode,
    List<RoutingRule> routingRules,
  ) => SingboxAdapter.toConfig(proxyConfig, activeNode, routingRules);

  /// 生成 mihomo 内核配置
  ///
  /// 委托到 [MihomoAdapter.toConfig]
  static Map<String, dynamic> toMihomoConfig(
    ProxyConfig proxyConfig,
    NodeConfig? activeNode,
    List<RoutingRule> routingRules,
  ) => MihomoAdapter.toConfig(proxyConfig, activeNode, routingRules);

  /// 生成 v2ray 内核配置
  ///
  /// 委托到 [V2rayAdapter.toConfig]
  static Map<String, dynamic> toV2rayConfig(
    ProxyConfig proxyConfig,
    NodeConfig? activeNode,
    List<RoutingRule> routingRules,
  ) => V2rayAdapter.toConfig(proxyConfig, activeNode, routingRules);

  /// 递归深度合并两个 Map
  ///
  /// 如果两个 key 对应的值都是 Map，则递归合并它们。
  /// 如果是 List 或基本数据类型，则使用 map2 中的值替换 map1 中的值。
  /// 如果 key 只在 map2 中存在，则将其添加到合并后的 Map 中。
  /// 返回合并后的新 Map，不修改传入的 map1 和 map2。
  static Map<String, dynamic> deepMerge(
    Map<dynamic, dynamic> map1,
    Map<dynamic, dynamic> map2,
  ) {
    final result = Map<String, dynamic>.from(
      map1.map((key, value) => MapEntry(key.toString(), value)),
    );

    map2.forEach((key, value) {
      final keyStr = key.toString();
      if (value is Map && result[keyStr] is Map) {
        result[keyStr] = deepMerge(result[keyStr] as Map, value);
      } else {
        result[keyStr] = value;
      }
    });

    return result;
  }
}
