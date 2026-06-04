import 'dart:convert';

/// SingboxOutbound - sing-box 出站配置
///
/// 表示一个出站代理节点或出站组（如 selector、urltest、direct、block）
/// [type] 为协议类型，[tag] 为唯一标识，[options] 为协议特定参数
class SingboxOutbound {
  /// 出站类型（如 vmess / vless / trojan / shadowsocks / direct / block / selector / urltest 等）
  final String type;

  /// 出站标签（唯一标识，路由规则通过此字段引用）
  final String tag;

  /// 协议特定参数（如服务器地址、端口、UUID 等）
  final Map<String, dynamic> options;

  /// 出站配置构造函数
  const SingboxOutbound({
    required this.type,
    required this.tag,
    this.options = const {},
  });

  /// 序列化为 JSON，将 [type] 和 [tag] 与 [options] 合并输出
  Map<String, dynamic> toJson() => {'type': type, 'tag': tag, ...options};

  /// 从 JSON 反序列化，自动分离 [type]、[tag] 和其余字段到 [options]
  factory SingboxOutbound.fromJson(Map<String, dynamic> json) =>
      SingboxOutbound(
        type: json['type'] as String,
        tag: json['tag'] as String,
        options: Map.from(json)
          ..remove('type')
          ..remove('tag'),
      );
}

/// SingboxRouteRule - sing-box 路由规则
///
/// 定义流量匹配规则，支持域名、IP、GeoIP、GeoSite、进程、协议、端口等多种匹配方式
/// 匹配到的流量将转发到 [outbound] 指定的出站
class SingboxRouteRule {
  /// 目标出站标签（对应出站的 tag）
  final String outbound;

  /// 精确域名匹配列表
  final List<String> domain;

  /// 域名关键词匹配列表
  final List<String> domainKeyword;

  /// 域名后缀匹配列表
  final List<String> domainSuffix;

  /// IP/CIDR 匹配列表
  final List<String> ip;

  /// GeoIP 匹配列表（如 cn、us）
  final List<String> geoip;

  /// GeoSite 匹配列表（如 google、github）
  final List<String> geosite;

  /// 进程名匹配列表
  final List<String> process;

  /// 协议匹配列表（如 tls、http）
  final List<String> protocol;

  /// 端口匹配列表
  final List<int> port;

  /// 路由规则构造函数
  const SingboxRouteRule({
    required this.outbound,
    this.domain = const [],
    this.domainKeyword = const [],
    this.domainSuffix = const [],
    this.ip = const [],
    this.geoip = const [],
    this.geosite = const [],
    this.process = const [],
    this.protocol = const [],
    this.port = const [],
  });

  /// 序列化为 JSON，仅输出非空字段
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'outbound': outbound};
    if (domain.isNotEmpty) map['domain'] = domain;
    if (domainKeyword.isNotEmpty) map['domain_keyword'] = domainKeyword;
    if (domainSuffix.isNotEmpty) map['domain_suffix'] = domainSuffix;
    if (ip.isNotEmpty) map['ip_cidr'] = ip;
    if (geoip.isNotEmpty) map['geoip'] = geoip;
    if (geosite.isNotEmpty) map['geosite'] = geosite;
    if (process.isNotEmpty) map['process_name'] = process;
    if (protocol.isNotEmpty) map['protocol'] = protocol;
    if (port.isNotEmpty) map['port'] = port;
    return map;
  }
}

/// SingboxRoute - sing-box 路由配置
///
/// 包含路由规则列表和默认出站（final），未匹配任何规则的流量将走默认出站
class SingboxRoute {
  /// 路由规则列表
  final List<SingboxRouteRule> rules;

  /// 默认出站标签（未匹配任何规则时使用）
  final String? finalOutbound;

  /// 路由配置构造函数
  const SingboxRoute({this.rules = const [], this.finalOutbound});

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => {
    'rules': rules.map((r) => r.toJson()).toList(),
    if (finalOutbound != null) 'final': finalOutbound,
  };
}

/// SingboxInbound - sing-box 入站配置
///
/// 表示一个本地入站监听器，支持 socks、http、mixed、tun 等类型
class SingboxInbound {
  /// 入站类型（如 socks / http / mixed / tun / redirect / tproxy 等）
  final String type;

  /// 入站标签（唯一标识）
  final String tag;

  /// 监听地址（默认 127.0.0.1）
  final String listenAddress;

  /// 监听端口
  final int listenPort;

  /// 额外参数（如 TUN 配置、SOCKS 用户认证等）
  final Map<String, dynamic> extra;

  /// 入站配置构造函数
  const SingboxInbound({
    required this.type,
    required this.tag,
    this.listenAddress = '127.0.0.1',
    this.listenPort = 1080,
    this.extra = const {},
  });

  /// 序列化为 JSON，将 [type]、[tag]、[listenAddress]、[listenPort] 与 [extra] 合并输出
  Map<String, dynamic> toJson() => {
    'type': type,
    'tag': tag,
    'listen': listenAddress,
    'listen_port': listenPort,
    ...extra,
  };

  /// 从 JSON 反序列化，自动分离核心字段和额外参数
  factory SingboxInbound.fromJson(Map<String, dynamic> json) => SingboxInbound(
    type: json['type'] as String,
    tag: json['tag'] as String,
    listenAddress: json['listen'] as String? ?? '127.0.0.1',
    listenPort: json['listen_port'] as int? ?? 1080,
    extra: Map.from(json)
      ..remove('type')
      ..remove('tag')
      ..remove('listen')
      ..remove('listen_port'),
  );
}

/// SingboxConfig - sing-box 完整配置
///
/// sing-box 内核的顶层配置模型，包含入站、出站、路由和实验性功能配置
/// 序列化后可直接作为 sing-box 的配置文件使用
class SingboxConfig {
  /// 入站配置列表
  final List<SingboxInbound> inbounds;

  /// 出站配置列表
  final List<SingboxOutbound> outbounds;

  /// 路由配置
  final SingboxRoute route;

  /// 实验性功能配置（如 Clash API、缓存等）
  final Map<String, dynamic> experimental;

  /// sing-box 配置构造函数
  const SingboxConfig({
    this.inbounds = const [],
    this.outbounds = const [],
    this.route = const SingboxRoute(),
    this.experimental = const {},
  });

  /// 序列化为 JSON，自动包含日志配置
  Map<String, dynamic> toJson() => {
    'log': {'level': 'info', 'timestamp': true},
    if (inbounds.isNotEmpty)
      'inbounds': inbounds.map((i) => i.toJson()).toList(),
    if (outbounds.isNotEmpty)
      'outbounds': outbounds.map((o) => o.toJson()).toList(),
    'route': route.toJson(),
    if (experimental.isNotEmpty) 'experimental': experimental,
  };

  /// 序列化为格式化的 JSON 字符串（带缩进）
  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// 从 JSON 反序列化为 SingboxConfig
  factory SingboxConfig.fromJson(Map<String, dynamic> json) => SingboxConfig(
    inbounds:
        (json['inbounds'] as List?)
            ?.map((i) => SingboxInbound.fromJson(i as Map<String, dynamic>))
            .toList() ??
        [],
    outbounds:
        (json['outbounds'] as List?)
            ?.map((o) => SingboxOutbound.fromJson(o as Map<String, dynamic>))
            .toList() ??
        [],
    route: json['route'] != null
        ? SingboxRoute(
            rules:
                (json['route']['rules'] as List?)
                    ?.map(
                      (r) => SingboxRouteRule(
                        outbound: r['outbound'] as String? ?? 'direct',
                        domain:
                            (r['domain'] as List?)
                                ?.map((d) => d as String)
                                .toList() ??
                            [],
                        ip:
                            (r['ip_cidr'] as List?)
                                ?.map((i) => i as String)
                                .toList() ??
                            [],
                      ),
                    )
                    .toList() ??
                [],
            finalOutbound: json['route']['final'] as String?,
          )
        : const SingboxRoute(),
    experimental: Map<String, dynamic>.from(json['experimental'] as Map? ?? {}),
  );

  /// 从 JSON 字符串反序列化为 SingboxConfig
  factory SingboxConfig.fromJsonString(String s) =>
      SingboxConfig.fromJson(jsonDecode(s) as Map<String, dynamic>);

  /// 生成默认的 sing-box 配置
  ///
  /// [socksPort] SOCKS5 代理监听端口，默认 1080
  /// [httpPort] HTTP 代理监听端口，默认 1081
  /// 包含一个 SOCKS 入站、一个 HTTP 入站、direct 和 block 两个基础出站
  static SingboxConfig defaultConfig({
    int socksPort = 1080,
    int httpPort = 1081,
  }) {
    return SingboxConfig(
      inbounds: [
        SingboxInbound(type: 'socks', tag: 'socks-in', listenPort: socksPort),
        SingboxInbound(type: 'http', tag: 'http-in', listenPort: httpPort),
      ],
      outbounds: [
        const SingboxOutbound(type: 'direct', tag: 'direct'),
        const SingboxOutbound(type: 'block', tag: 'block'),
      ],
      route: const SingboxRoute(finalOutbound: 'direct'),
    );
  }
}
