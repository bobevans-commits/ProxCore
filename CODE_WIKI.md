# ProxCore Code Wiki

> 版本: 1.0.0 | 最后更新: 2026-05-06

---

## 目录

- [1. 项目概览](#1-项目概览)
- [2. 技术栈与依赖](#2-技术栈与依赖)
- [3. 项目结构](#3-项目结构)
- [4. 整体架构](#4-整体架构)
- [5. 模型层 (models/)](#5-模型层-models)
- [6. 服务层 (services/)](#6-服务层-services)
- [7. UI 层 (screens/ & widgets/)](#7-ui-层-screens--widgets)
- [8. 工具层 (utils/)](#8-工具层-utils)
- [9. 依赖关系图](#9-依赖关系图)
- [10. 数据流详解](#10-数据流详解)
- [11. 设计模式](#11-设计模式)
- [12. 协议支持矩阵](#12-协议支持矩阵)
- [13. 构建与运行](#13-构建与运行)
- [14. 扩展指南](#14-扩展指南)
- [15. 已知限制与注意事项](#15-已知限制与注意事项)

---

## 1. 项目概览

**ProxCore** 是一个基于 Flutter 的多平台代理客户端 UI，支持三种主流代理内核：

| 内核 | GitHub 仓库 | 说明 |
|------|-------------|------|
| sing-box | SagerNet/sing-box | 通用代理平台，协议支持最全 |
| mihomo | MetaCubeX/mihomo | Clash Meta 内核，兼容 Clash 生态 |
| v2ray (Xray) | XTLS/Xray-core | Xray 内核，支持 VMess/VLESS |

**支持平台**: Windows / macOS / Linux / Android

**核心能力**:
- 多内核管理与切换
- 多协议节点配置 (VMess/VLESS/Trojan/SS/Hysteria2/TUIC/WireGuard/Naive)
- 订阅链接管理与自动更新
- 路由规则编辑
- DNS 配置管理 (系统/自定义/DoH/DoT)
- TUN 模式 (全局透明代理)
- 系统代理设置 (Windows注册表/macOS networksetup/Linux环境变量)
- Clash API 实时流量/日志/节点监听
- 智能路由 (节点评分/自动选路)
- GeoIP/GeoSite 数据管理
- WebDAV 云同步
- 管理员权限请求 (UAC/osascript)
- 系统托盘 (tray_manager)
- 毛玻璃主题 (Glassmorphism)

---

## 2. 技术栈与依赖

### 运行时依赖

| 包名 | 版本 | 用途 |
|------|------|------|
| `flutter` | SDK | UI 框架 |
| `provider` | ^6.0.0 | 状态管理 (ChangeNotifier + Provider) |
| `dio` | ^5.0.0 | HTTP 客户端 (订阅获取/内核下载/Clash API/WebDAV) |
| `json_annotation` | ^4.8.0 | JSON 序列化注解 |
| `shared_preferences` | ^2.2.0 | 本地键值存储 (配置持久化) |
| `file_picker` | ^6.0.0 | 文件选择器 |
| `url_launcher` | ^6.1.0 | 打开外部链接 |
| `tray_manager` | ^0.2.0 | 系统托盘管理 |
| `bitsdojo_window` | ^0.1.0 | 窗口管理 (自定义标题栏/无边框窗口) |
| `path_provider` | ^2.1.0 | 应用目录路径 |
| `archive` | ^3.4.0 | 压缩解压 (tar.gz/zip/gz) |
| `yaml` | ^3.1.0 | YAML 解析 (mihomo 配置) |
| `collection` | ^1.18.0 | 集合操作扩展 |
| `web_socket_channel` | ^2.4.0 | WebSocket 通信 (Clash API 实时流量/日志) |
| `share_plus` | ^7.0.0 | 系统分享 (配置导出) |

### 开发依赖

| 包名 | 版本 | 用途 |
|------|------|------|
| `flutter_test` | SDK | Widget 与单元测试 |
| `mockito` | ^5.4.0 | Mock 对象生成 |
| `build_runner` | ^2.4.0 | 代码生成运行器 |
| `json_serializable` | ^6.7.0 | JSON 序列化代码生成 |

---

## 3. 项目结构

```
proxcore/
├── lib/
│   ├── main.dart                                    # 应用入口 (MultiProvider + MyApp)
│   ├── models/                                      # 数据模型层
│   │   ├── config.dart                              # KernelType/KernelStatus/ProxyProtocol/NodeConfig/ProxyConfig/DnsConfig/RoutingRule
│   │   ├── kernel_info.dart                         # KernelInfo 内核信息模型
│   │   └── singbox_config.dart                      # SingBoxConfig 完整配置模型
│   ├── services/                                    # 服务层 (核心业务逻辑)
│   │   ├── proxy_service.dart                       # 核心代理服务 (启停/节点/流量/系统代理)
│   │   ├── kernel_manager.dart                      # 内核管理器 (下载/安装/版本/生命周期)
│   │   ├── config_storage_service.dart              # 配置持久化存储 (SharedPreferences)
│   │   ├── subscription_service.dart                # 订阅服务 (解析/更新/自动刷新)
│   │   ├── clash_api_service.dart                   # Clash API 服务 (WebSocket流量/日志/节点)
│   │   ├── smart_router.dart                        # 智能路由 (节点评分/自动选路)
│   │   ├── geo_data_service.dart                    # 地理数据服务 (GeoIP/GeoSite下载)
│   │   ├── webdav_sync_service.dart                 # WebDAV 云同步服务
│   │   ├── admin_service.dart                       # 管理员权限服务 (UAC/osascript)
│   │   ├── system_proxy_service.dart                # 系统代理服务 (注册表/networksetup)
│   │   └── tray_service.dart                        # 系统托盘服务 (tray_manager)
│   ├── screens/                                     # 页面层
│   │   ├── home_screen.dart                         # 主页 (仪表板)
│   │   ├── subscriptions_screen.dart                # 订阅管理
│   │   ├── kernel_settings_screen.dart              # 内核管理
│   │   ├── node_editor_screen.dart                  # 节点编辑器
│   │   ├── routing_editor_screen.dart               # 路由规则编辑器
│   │   ├── log_screen.dart                          # 日志查看器
│   │   └── settings_screen.dart                     # 设置页面
│   ├── widgets/                                     # 可复用组件
│   │   ├── glass_theme.dart                         # 毛玻璃主题 (GlassTheme/GlassCard/GlassButton/GlassSwitch)
│   │   └── proxy_link_importer.dart                 # 代理链接导入器
│   └── utils/                                       # 工具层
│       ├── app_utils.dart                           # 通用工具函数
│       └── config_adapter.dart                      # 配置格式适配器 (sing-box/mihomo/v2ray)
├── android/                                         # Android 原生代码
│   └── app/src/main/kotlin/.../
│       ├── MainActivity.kt                          # Activity
│       ├── ProxyService.kt                          # 代理服务
│       └── VpnServiceImpl.kt                        # VPN 服务实现
├── assets/
│   ├── bin/                                         # 内核二进制文件目录
│   └── icons/                                       # 图标资源
├── scripts/                                         # 构建脚本
│   ├── build_linux.sh
│   ├── build_windows.ps1
│   ├── create_dmg.sh
│   └── download_kernels.sh
├── test/                                            # 测试
│   ├── proxy_service_test.dart
│   └── widget_test.dart
├── .github/workflows/                               # CI/CD 工作流
└── pubspec.yaml                                     # Flutter 依赖配置
```

---

## 4. 整体架构

### 4.1 分层架构

```
┌─────────────────────────────────────────────────────────┐
│                    UI 层 (screens/widgets)               │
│         StatefulWidget / StatelessWidget                │
│         context.watch<T>() / context.read<T>()          │
├─────────────────────────────────────────────────────────┤
│                  服务层 (services)                       │
│         ChangeNotifier + Provider 注入                   │
│         核心业务逻辑、状态管理                            │
├─────────────────────────────────────────────────────────┤
│                  模型层 (models)                         │
│         纯数据类，toJson()/fromJson() 序列化             │
├─────────────────────────────────────────────────────────┤
│              系统层 (Process / Dio / WebSocket)          │
│         Process.start / Dio HTTP / WebSocket Channel    │
└─────────────────────────────────────────────────────────┘
```

### 4.2 Provider 注入

在 [main.dart](file:///c:/www/ProxCore/lib/main.dart) 中通过 `MultiProvider` 注入全局服务：

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: kernelManager),
    ChangeNotifierProvider.value(value: proxyService),
    ChangeNotifierProvider.value(value: subscriptionService),
    ChangeNotifierProvider.value(value: clashApi),
    ChangeNotifierProvider.value(value: smartRouter),
    ChangeNotifierProvider.value(value: geoDataService),
    ChangeNotifierProvider.value(value: webdavService),
  ],
  child: const MyApp(),
)
```

### 4.3 导航结构

```
MainNavigation (底部导航: 仪表板/订阅/日志/设置)
├── HomeScreen — 仪表板: 代理状态/流量/快捷操作
├── SubscriptionsScreen — 订阅管理: 添加/编辑/更新/删除/导入
├── LogScreen — 日志查看器: 过滤/自动滚动/导出
├── SettingsScreen — 设置: 内核/网络/规则/DNS/订阅/端口/数据/外观/关于
├── NodeEditorScreen — 节点编辑器: 协议/服务器/认证/TLS/传输/REALITY
├── RoutingEditorScreen — 路由规则编辑器: 规则类型/出站/条件/预设
└── KernelSettingsScreen — 内核管理: 下载/切换/更新/删除
```

---

## 5. 模型层 (models/)

### 5.1 config.dart

[config.dart](file:///c:/www/ProxCore/lib/models/config.dart) 定义了内核类型、协议、节点和核心配置模型。

| 类/枚举 | 说明 | 关键字段 |
|---------|------|----------|
| `KernelType` | 内核类型枚举: `singbox` / `mihomo` / `v2ray` | label, repo |
| `KernelStatus` | 内核状态枚举: notInstalled/downloading/installing/installed/running/stopping/error | description |
| `ProxyProtocol` | 代理协议枚举: vmess/vless/trojan/shadowsocks/hysteria/hysteria2/tuic/naive/wireguard | label |
| `NodeConfig` | 节点配置 | id, name, protocol, address, port, extra, latencyMs, downloadSpeed |
| `DnsMode` | DNS 模式枚举: system/custom/doh/dot | value, label |
| `DnsConfig` | DNS 配置 | mode, servers, fallbackServers, remoteResolve, dohUrl, dotServer |
| `ProxyConfig` | 代理配置 | kernelType, localAddress, localPort, socksPort, httpPort, tunEnabled, systemProxy, lanSharing, adBlocking, smartNode, subRefreshMinutes, nodes, dnsConfig |
| `RoutingRule` | 路由规则 | id, name, type, match, target, enabled |

**预设路由规则**: `RoutingRule.presetRules` 包含 14 条常用规则 (国内直连/广告屏蔽/Google/GitHub/Telegram 等)

### 5.2 kernel_info.dart

[kernel_info.dart](file:///c:/www/ProxCore/lib/models/kernel_info.dart) 定义了内核信息模型。

| 类 | 说明 | 关键字段 |
|----|------|----------|
| `KernelInfo` | 已安装内核信息 | type, version, binaryPath, isInstalled |

### 5.3 singbox_config.dart

[singbox_config.dart](file:///c:/www/ProxCore/lib/models/singbox_config.dart) 是完整的 sing-box 配置数据模型，包含 15 个类：

| 类 | 说明 | 关键字段 |
|----|------|----------|
| `SingBoxConfig` | 根配置 | logLevel, inbounds, outbounds, route, dns, experimental |
| `Inbound` | 入站配置 | type, tag, listen, listenPort, users, options |
| `Outbound` | 出站/协议配置 | type, tag, server, serverPort, uuid, password, tls, reality, transport |
| `TlsConfig` | TLS 配置 | enabled, serverName, insecure, alpn, utls |
| `RealityConfig` | REALITY 配置 | enabled, publicKey, shortId |
| `TransportConfig` | 传输层配置 | type (ws/grpc/http/quic), path, serviceName, headers |
| `RouteConfig` | 路由配置 | autoDetectInterface, rules, geosite, geoip |
| `RuleConfig` | 路由规则 | outbound, domain, domainSuffix, ipCidr, protocol, sourcePort, inbound |
| `GeoSiteEntry` | GeoSite 规则 | tag, url, downloadDetour |
| `GeoIpEntry` | GeoIP 规则 | tag, url, downloadDetour |
| `DnsConfig` | DNS 配置 | servers, rules, finalServer, disableCache, client |
| `DnsServer` | DNS 服务器 | tag, address, addressResolver, strategy, detour |
| `DnsRule` | DNS 规则 | server, domain, domainSuffix, ipCidr, outbound, protocol, type |
| `TunConfig` | TUN 配置 | enabled, device, stack (system/gvisor/mixed), autoRoute, strictRoute |
| `ClashApiConfig` | Clash API | externalController, externalUi, secret |

**不可变设计**: 所有模型均为不可变对象，修改时通过构造函数创建新实例。

---

## 6. 服务层 (services/)

### 6.1 ProxyService

[proxy_service.dart](file:///c:/www/ProxCore/lib/services/proxy_service.dart) — 核心代理服务，全局唯一状态源

| 项目 | 说明 |
|------|------|
| 继承 | `ChangeNotifier` |
| Provider | 全局注入，UI 通过 `context.watch<ProxyService>()` 响应 |
| 状态枚举 | `ProxyState { stopped, starting, running, stopping }` |
| 依赖 | `KernelManager`, `ConfigStorageService`, `ClashApiService?`, `SmartRouter?` |

**关键属性**:

| 属性 | 类型 | 说明 |
|------|------|------|
| `_state` | `ProxyState` | 当前代理状态 |
| `_config` | `ProxyConfig` | 当前代理配置 |
| `_activeNode` | `NodeConfig?` | 当前活跃节点 |
| `_process` | `Process?` | 内核进程实例 |
| `_uploadBytes` / `_downloadBytes` | `int` | 累计流量 |
| `_uploadSpeed` / `_downloadSpeed` | `int` | 实时速度 |
| `_speedHistory` | `List<SpeedRecord>` | 速度历史 (60秒窗口) |
| `_logs` | `List<String>` | 日志列表 (最多1000条) |
| `_crashCount` | `int` | 崩溃计数器 (最多3次自启) |
| `_routingRules` | `List<RoutingRule>` | 路由规则 |
| `_nodes` | `List<NodeConfig>` | 节点列表 |

**关键方法**:

| 方法 | 说明 |
|------|------|
| `init()` | 从持久化存储加载配置、节点和路由规则 |
| `start(NodeConfig)` | 启动代理 (智能选路→获取内核→生成配置→Process.start→ClashApi连接) |
| `stop()` | 停止代理 (SIGTERM→5秒→SIGKILL→清理系统代理) |
| `restart(NodeConfig)` | 重启代理 (先停后启) |
| `toggleTun(bool)` | 切换 TUN 模式 (运行中自动重启) |
| `setSystemProxy(bool)` | 设置系统代理开关 (即时生效) |
| `testLatency(NodeConfig)` | TCP 延迟测试 (5秒超时) |
| `testAllLatency(List)` | 批量延迟测试 (并发) |
| `testDownloadSpeed(NodeConfig)` | 下载速度测试 (cachefly 1MB) |
| `findBestNode(List)` | 选择最低延迟节点 |
| `addNode/addNodes/updateNode/deleteNode/clearNodes` | 节点增删改查 (自动去重: address:port:protocol) |
| `updateRoutingRules/addRoutingRule/deleteRoutingRule` | 路由规则管理 |
| `exportConfig()` / `importConfig(String)` | 配置导入导出 |

**辅助类**: `SpeedRecord` — 速度记录 (time, upload, download)

**崩溃自启**: 进程异常退出时自动重启，最多 3 次 (`_maxCrashAutoRestart`)

### 6.2 KernelManager

[kernel_manager.dart](file:///c:/www/ProxCore/lib/services/kernel_manager.dart) — 内核生命周期管理

| 项目 | 说明 |
|------|------|
| 继承 | `ChangeNotifier` |
| Provider | 全局注入 |

**关键属性**:

| 属性 | 类型 | 说明 |
|------|------|------|
| `_kernels` | `Map<KernelType, KernelInfo>` | 各内核的安装信息 |
| `_statusMap` | `Map<KernelType, KernelStatus>` | 各内核的状态 |
| `_versionMap` | `Map<KernelType, String>` | 各内核的版本 |
| `_error` | `String?` | 最近一次错误 |

**关键方法**:

| 方法 | 说明 |
|------|------|
| `init()` | 检测本地已安装内核 |
| `isInstalled(KernelType)` | 检查内核是否已安装 |
| `getBinaryPath(KernelType)` | 获取内核二进制路径 |
| `downloadKernel(KernelType)` | 下载并安装内核 (GitHub Releases) |
| `deleteKernel(KernelType)` | 删除已安装内核 |

**GitHub 发布源**:

| 内核 | 仓库 |
|------|------|
| sing-box | `SagerNet/sing-box` |
| mihomo | `MetaCubeX/mihomo` |
| v2ray | `XTLS/Xray-core` |

### 6.3 ConfigStorageService

[config_storage_service.dart](file:///c:/www/ProxCore/lib/services/config_storage_service.dart) — 配置持久化存储

| 项目 | 说明 |
|------|------|
| 实现 | 基于 `SharedPreferences` 的 JSON 序列化存储 |

**存储键**:

| 键 | 说明 |
|----|------|
| `proxy_config` | 代理配置 (ProxyConfig JSON) |
| `nodes` | 节点列表 (NodeConfig JSON Array) |
| `routing_rules` | 路由规则 (RoutingRule JSON Array) |
| `active_kernel` | 当前内核类型 (KernelType.name) |
| `subscriptions` | 订阅列表 (SubscriptionInfo JSON Array) |

**关键方法**:

| 方法 | 说明 |
|------|------|
| `init()` | 初始化 SharedPreferences |
| `initSync()` | 异步初始化 (不阻塞启动) |
| `loadProxyConfig()` / `saveProxyConfig()` | 加载/保存代理配置 |
| `loadNodes()` / `saveNodes()` | 加载/保存节点列表 |
| `loadRoutingRules()` / `saveRoutingRules()` | 加载/保存路由规则 |
| `loadActiveKernel()` / `saveActiveKernel()` | 加载/保存当前内核 |
| `loadSubscriptions()` / `saveSubscriptions()` | 加载/保存订阅列表 |
| `exportConfig()` / `importConfig(String)` | 全量导入导出 |
| `saveConfigFile()` / `readConfigFile()` | 配置文件读写 |

**辅助类**: `SubscriptionInfo` — 订阅信息模型 (id, name, url, updateIntervalMinutes, lastUpdated)

### 6.4 SubscriptionService

[subscription_service.dart](file:///c:/www/ProxCore/lib/services/subscription_service.dart) — 订阅管理服务

| 项目 | 说明 |
|------|------|
| 继承 | `ChangeNotifier` |
| 依赖 | `ConfigStorageService`, `Dio` |

**支持的链接格式**:

| 协议 | 链接格式 | 解析方法 |
|------|----------|----------|
| VMess | `vmess://` (Base64 JSON) | `_parseVmess()` |
| VLESS | `vless://` (URI) | `_parseVless()` |
| Trojan | `trojan://` (URI) | `_parseTrojan()` |
| Shadowsocks | `ss://` (URI) | `_parseShadowsocks()` |
| Hysteria2 | `hysteria2://` (URI) | `_parseHysteria2()` |

**订阅格式**: Base64 编码列表 / JSON (sing-box / Clash 格式)

**关键方法**:

| 方法 | 说明 |
|------|------|
| `init()` | 从存储加载订阅列表 |
| `addSubscription(SubscriptionInfo)` | 添加订阅 |
| `updateSubscription(String)` | 更新指定订阅 (下载+解析) |
| `deleteSubscription(String)` | 删除订阅 |
| `setupAutoRefresh(int minutes)` | 配置自动刷新定时器 |
| `onNodesRefreshed` | 节点刷新回调 (通知 ProxyService) |

### 6.5 ClashApiService

[clash_api_service.dart](file:///c:/www/ProxCore/lib/services/clash_api_service.dart) — Clash API 服务

| 项目 | 说明 |
|------|------|
| 继承 | `ChangeNotifier` |
| 依赖 | `Dio` (RESTful), `WebSocketChannel` (实时流) |

**关键属性**:

| 属性 | 类型 | 说明 |
|------|------|------|
| `_liveUpload` / `_liveDownload` | `int` | 实时上传/下载速度 (字节/秒) |
| `_connections` | `List<ClashConnection>` | 当前活跃连接列表 |
| `_realtimeLogs` | `List<ClashLogEntry>` | 实时日志 (最多500条) |
| `_currentProxyMode` | `String` | 代理模式: rule/global/direct |

**关键方法**:

| 方法 | 说明 |
|------|------|
| `configure(apiUrl, secret)` | 配置 API 地址和认证密钥 |
| `connect()` | 连接 WebSocket 流量/日志流 (自动重连3秒) |
| `disconnect()` | 断开 WebSocket 连接 |
| `getProxies()` | 获取代理节点列表 (GET /proxies) |
| `switchProxy(group, name)` | 切换代理组节点 (PUT /proxies/:group) |
| `setProxyMode(mode)` | 切换代理模式 (PATCH /configs) |
| `fetchConnections()` | 获取活跃连接 (GET /connections) |
| `closeAllConnections()` | 关闭所有连接 (DELETE /connections) |

**辅助类**:

| 类 | 说明 |
|----|------|
| `ClashProxy` | 代理节点/代理组 (name, type, now, delay, all, isGroup) |
| `ClashConnection` | 活跃连接 (id, host, destinationIP, chain, upload, download, start) |
| `ClashLogEntry` | 日志条目 (type, payload) |

### 6.6 SmartRouter

[smart_router.dart](file:///c:/www/ProxCore/lib/services/smart_router.dart) — 智能路由服务

| 项目 | 说明 |
|------|------|
| 继承 | `ChangeNotifier` |

**评分算法** (总分 0~90):

| 维度 | 分值 | 公式 |
|------|------|------|
| 稳定性分 | 0~40 | successConnects / total × 40 |
| 延迟分 | 0~20 | max(0, 20 - avgLatency / 50) |
| 速度分 | 0~30 | min(30, avgSpeed / 1MB × 3) |

**选路策略**: 综合评分 = 历史评分 × 0.6 + 实时延迟评分 × 0.4

**关键方法**:

| 方法 | 说明 |
|------|------|
| `recordConnect(node, success)` | 记录连接结果 |
| `recordLatency(node, latencyMs)` | 记录延迟 (指数移动平均 α=0.3) |
| `recordSpeed(node, bytesPerSec)` | 记录速度 (指数移动平均 α=0.3) |
| `pickBest(nodes)` | 智能选择最优节点 |
| `getRankedNodes(nodes)` | 获取节点排名列表 |
| `toJson()` / `loadFromJson()` | 序列化/反序列化评分数据 |

**辅助类**: `NodeScore` — 节点评分 (nodeId, successfulConnects, failedConnects, avgLatencyMs, avgDownloadSpeed, lastUsed, score, stability)

### 6.7 GeoDataService

[geo_data_service.dart](file:///c:/www/ProxCore/lib/services/geo_data_service.dart) — 地理数据服务

| 项目 | 说明 |
|------|------|
| 继承 | `ChangeNotifier` |
| 依赖 | `Dio`, `path_provider` |

**关键方法**:

| 方法 | 说明 |
|------|------|
| `init()` | 检查本地 geoip.db / geosite.db 版本 |
| `checkLocalVersions()` | 使用文件修改日期作为版本标识 |
| `updateAll()` | 从 GitHub SagerNet 下载最新 geoip.db 和 geosite.db |
| `getGeoipPath()` / `getGeositePath()` | 获取数据文件路径 |

**数据来源**:
- GeoIP: `https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db`
- GeoSite: `https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db`

**存储路径**: `{应用支持目录}/geo/`

### 6.8 WebDavSyncService

[webdav_sync_service.dart](file:///c:/www/ProxCore/lib/services/webdav_sync_service.dart) — WebDAV 云同步服务

| 项目 | 说明 |
|------|------|
| 继承 | `ChangeNotifier` |
| 依赖 | `Dio` (WebDAV HTTP 方法) |

**关键方法**:

| 方法 | 说明 |
|------|------|
| `configure(serverUrl, username, password, remotePath)` | 配置连接参数 (Basic Auth) |
| `testConnection()` | 测试连接 (PROPFIND / MKCOL) |
| `uploadConfig(configJson)` | 上传备份 (带时间戳 + latest 双文件) |
| `downloadLatestConfig()` | 下载最新配置 (proxcore_latest.json) |
| `toJson()` / `loadFromJson()` | 序列化/反序列化连接配置 |

**远程存储路径**: 默认 `/proxcore/`

**备份文件**:
- `proxcore_backup_{timestamp}.json` — 带时间戳的备份
- `proxcore_latest.json` — 最新配置 (覆盖写入)

### 6.9 AdminService

[admin_service.dart](file:///c:/www/ProxCore/lib/services/admin_service.dart) — 管理员权限服务

| 项目 | 说明 |
|------|------|
| 模式 | 静态工具类 (私有构造函数) |

**关键方法**:

| 方法 | 说明 |
|------|------|
| `requestAdminPrivileges()` | 请求管理员权限 |
| `hasAdminPrivileges()` | 检测是否拥有管理员权限 |

**平台差异**:

| 平台 | 请求方式 | 检测方式 |
|------|----------|----------|
| Windows | PowerShell UAC (`Start-Process -Verb RunAs`) → 退出当前进程 | `net session` |
| macOS | `osascript` 弹出系统授权对话框 | `id` 命令检测 root |
| Linux | 直接返回 true | 直接返回 true |

### 6.10 SystemProxyService

[system_proxy_service.dart](file:///c:/www/ProxCore/lib/services/system_proxy_service.dart) — 系统代理服务

| 项目 | 说明 |
|------|------|
| 模式 | 静态工具类 (私有构造函数) |

**关键方法**:

| 方法 | 说明 |
|------|------|
| `enable(host, httpPort, socksPort)` | 启用系统代理 |
| `disable()` | 禁用系统代理 |

**平台差异**:

| 平台 | 启用方式 | 禁用方式 |
|------|----------|----------|
| Windows | `reg add` 修改注册表 Internet Settings (ProxyEnable=1, ProxyServer, ProxyOverride) | ProxyEnable=0 |
| macOS | `networksetup` 设置 Web/HTTPS/SOCKS 代理 + 绕过域名 | 关闭代理状态 |
| Linux | 生成 `proxy_env.sh` 环境变量脚本 (http_proxy/https_proxy) | 删除脚本 |

**绕过列表**: localhost, 127.*, 10.*, 172.16.*~172.31.*, 192.168.*

### 6.11 TrayService

[tray_service.dart](file:///c:/www/ProxCore/lib/services/tray_service.dart) — 系统托盘服务

| 项目 | 说明 |
|------|------|
| 模式 | 普通类 (mixin `TrayListener`) |
| 依赖 | `tray_manager`, `ProxyService` |
| 平台 | 仅 Windows / macOS / Linux |

**托盘菜单项**:

| 菜单 Key | 标签 | 说明 |
|----------|------|------|
| `status` | ● 代理运行中 / ○ 代理未运行 | 状态显示 (禁用项) |
| `proxy_mode` | 代理模式 (子菜单) | 规则/全局/直连 |
| `toggle` | 启动代理 / 停止代理 | 代理启停 |
| `show` | 显示主窗口 | 显示窗口 |
| `exit` | 退出 | 停止代理→销毁托盘→exit(0) |

**关键方法**:

| 方法 | 说明 |
|------|------|
| `init()` | 设置图标 + 构建菜单 + 注册监听器 |
| `update()` | 代理状态变化时重建菜单 |
| `destroy()` | 移除监听器 + 销毁托盘图标 |

---

## 7. UI 层 (screens/ & widgets/)

### 7.1 页面一览

| 页面 | 文件 | 说明 |
|------|------|------|
| `MainNavigation` | [main.dart](file:///c:/www/ProxCore/lib/main.dart) | 主框架，底部导航 (仪表板/订阅/日志/设置) + 侧边抽屉 + 节点列表弹窗 |
| `HomeScreen` | [home_screen.dart](file:///c:/www/ProxCore/lib/screens/home_screen.dart) | 仪表盘: 代理状态卡片/流量统计/快捷操作 |
| `SubscriptionsScreen` | [subscriptions_screen.dart](file:///c:/www/ProxCore/lib/screens/subscriptions_screen.dart) | 订阅管理: 添加/编辑/更新/删除/导入 |
| `LogScreen` | [log_screen.dart](file:///c:/www/ProxCore/lib/screens/log_screen.dart) | 日志查看器: 过滤/自动滚动/导出 |
| `SettingsScreen` | [settings_screen.dart](file:///c:/www/ProxCore/lib/screens/settings_screen.dart) | 设置: 内核/网络/规则/DNS/订阅/端口/数据/外观/关于 |
| `KernelSettingsScreen` | [kernel_settings_screen.dart](file:///c:/www/ProxCore/lib/screens/kernel_settings_screen.dart) | 内核管理: 下载/切换/更新/删除 |
| `NodeEditorScreen` | [node_editor_screen.dart](file:///c:/www/ProxCore/lib/screens/node_editor_screen.dart) | 节点编辑器: 协议/服务器/认证/TLS/传输/REALITY |
| `RoutingEditorScreen` | [routing_editor_screen.dart](file:///c:/www/ProxCore/lib/screens/routing_editor_screen.dart) | 路由规则编辑器: 规则类型/出站/条件/预设 |

**SettingsScreen 分组**:

| 分组 | 图标 | 功能 |
|------|------|------|
| 内核 | memory | 内核管理 (跳转 KernelSettingsScreen) |
| 网络 | language | TUN 模式 / 系统代理 / 局域网共享 |
| 规则 | shield_outlined | 广告屏蔽 / 智能节点 |
| DNS | dns | DNS 模式/服务器/DoH/DoT/远程解析 |
| 订阅 | sync | 自动刷新间隔 |
| 端口 | swap_vert | 监听地址 / SOCKS 端口 / HTTP 端口 |
| 数据 | storage | 导出配置 / 导入配置 / 清除所有数据 |
| 外观 | palette | 主题模式切换 |
| 关于 | info_outline | 版本信息 |

### 7.2 可复用组件

| 组件 | 文件 | 说明 |
|------|------|------|
| `GlassTheme` | [glass_theme.dart](file:///c:/www/ProxCore/lib/widgets/glass_theme.dart) | 毛玻璃主题配置 (亮色/暗色 ThemeData) |
| `GlassCard` | glass_theme.dart | 毛玻璃卡片 (BackdropFilter + 自定义模糊/透明度/圆角) |
| `GlassButton` | glass_theme.dart | 毛玻璃按钮 (BackdropFilter + InkWell 水波纹) |
| `GlassSwitch` | glass_theme.dart | 毛玻璃开关 (AnimatedContainer + AnimatedAlign) |
| `ProxyLinkImporter` | [proxy_link_importer.dart](file:///c:/www/ProxCore/lib/widgets/proxy_link_importer.dart) | 代理链接导入器，支持多协议解析 |

**GlassTheme 色彩体系**:

| 名称 | 色值 | 用途 |
|------|------|------|
| primaryColor | `#6C5CE7` | 主色调 (紫色) |
| accentColor | `#00CEFF` | 强调色 (青色) |
| successColor | `#00E676` | 成功色 (绿色) |
| warningColor | `#FFB300` | 警告色 (琥珀色) |
| errorColor | `#FF5252` | 错误色 (红色) |

**主题背景色**:
- 亮色: `#F0F2F5` (浅灰)
- 暗色: `#0A0E27` (深蓝黑)

---

## 8. 工具层 (utils/)

### 8.1 app_utils.dart

[app_utils.dart](file:///c:/www/ProxCore/lib/utils/app_utils.dart) — 通用工具函数

| 方法 | 说明 |
|------|------|
| `formatBytes(int)` | 格式化字节为可读字符串 (B/KB/MB/GB) |
| `formatDuration(Duration)` | 格式化时长 (h/m/s) |
| `protocolIcon(ProxyProtocol)` | 获取协议对应的 emoji 图标 |
| `latencyColor(int)` | 获取延迟对应的颜色值 |

### 8.2 config_adapter.dart

[config_adapter.dart](file:///c:/www/ProxCore/lib/utils/config_adapter.dart) — 配置格式适配器

| 项目 | 说明 |
|------|------|
| 模式 | 静态工具类 (私有构造函数) |

| 方法 | 输出格式 | 说明 |
|------|----------|------|
| `toSingboxConfig(ProxyConfig, NodeConfig, List<RoutingRule>)` | sing-box JSON | 生成 sing-box 配置 (inbounds/outbounds/route/DNS/TUN) |
| `toMihomoConfig(ProxyConfig, NodeConfig, List<RoutingRule>)` | mihomo JSON | 生成 mihomo (Clash) 配置 (proxies/rules/DNS/TUN) |
| `toV2rayConfig(ProxyConfig, NodeConfig, List<RoutingRule>)` | v2ray JSON | 生成 v2ray (Xray) 配置 (inbounds/outbounds/routing/DNS/TUN) |

**支持 9 种代理协议转换**: VMess / VLESS / Trojan / Shadowsocks / Hysteria / Hysteria2 / TUIC / Naive / WireGuard

---

## 9. 依赖关系图

### 9.1 模块依赖

```
main.dart
├── ProxyService ──┬── KernelManager
│                  ├── ConfigStorageService
│                  ├── ClashApiService (可选注入)
│                  ├── SmartRouter (可选注入)
│                  ├── SystemProxyService (静态调用)
│                  ├── ConfigAdapter (静态调用)
│                  ├── ProxyConfig / NodeConfig / RoutingRule (models)
│                  └── ChangeNotifier
├── KernelManager ─┬── KernelInfo (models)
│                  ├── KernelType (models/config)
│                  ├── archive (解压)
│                  └── ChangeNotifier
├── SubscriptionService ──┬── ConfigStorageService
│                         ├── SubscriptionInfo (models)
│                         ├── AppUtils (utils)
│                         ├── Dio (HTTP)
│                         └── ChangeNotifier
├── ClashApiService ──┬── Dio (RESTful)
│                     ├── WebSocketChannel (实时流)
│                     └── ChangeNotifier
├── SmartRouter ──┬── NodeConfig / NodeScore (models)
│                 └── ChangeNotifier
├── GeoDataService ──┬── Dio (下载)
│                    ├── path_provider
│                    └── ChangeNotifier
├── WebDavSyncService ──┬── Dio (WebDAV)
│                       └── ChangeNotifier
├── TrayService ──┬── tray_manager
│                 └── ProxyService
├── HomeScreen ────┬── ProxyService (Provider)
│                  └── ProxyLinkImporter (widget)
├── SubscriptionsScreen ── SubscriptionService (Provider)
├── SettingsScreen ──┬── ProxyService (Provider)
│                    ├── SubscriptionService (Provider)
│                    └── KernelSettingsScreen
└── LogScreen ── ProxyService (Provider)
```

### 9.2 服务间依赖

```
ProxyService (核心状态)
    ↑ 被 UI 层直接 watch
    ├── 使用 KernelManager (内核二进制路径)
    ├── 使用 ConfigStorageService (持久化)
    ├── 使用 ClashApiService (实时流量/日志)
    ├── 使用 SmartRouter (智能选路)
    ├── 使用 SystemProxyService (系统代理设置)
    └── 使用 ConfigAdapter (配置生成)

KernelManager (内核管理)
    ↑ 被 ProxyService / KernelSettingsScreen 调用
    ├── 使用 KernelInfo 模型
    ├── 使用 archive (解压)
    └── 使用 http (GitHub API)

SubscriptionService (订阅)
    ↑ 被 SubscriptionsScreen / SettingsScreen watch
    ├── 使用 ConfigStorageService (持久化)
    ├── 使用 AppUtils (链接解析)
    └── 使用 Dio (订阅获取)

ClashApiService (Clash API)
    ↑ 被 ProxyService 调用
    ├── 使用 Dio (RESTful API)
    └── 使用 WebSocketChannel (实时流)

SmartRouter (智能路由)
    ↑ 被 ProxyService 调用
    └── 使用 NodeConfig / NodeScore 模型

GeoDataService (地理数据)
    ↑ 被 UI 层 watch
    ├── 使用 Dio (下载)
    └── 使用 path_provider (文件路径)

WebDavSyncService (云同步)
    ↑ 被 UI 层 watch
    └── 使用 Dio (WebDAV)

AdminService (管理员权限)
    ↑ 被 UI 层静态调用
    └── 使用 Process (UAC/osascript)

SystemProxyService (系统代理)
    ↑ 被 ProxyService 静态调用
    └── 使用 Process (reg/networksetup)

TrayService (系统托盘)
    ↑ 被 main.dart 创建
    ├── 使用 tray_manager
    └── 使用 ProxyService (状态监听)
```

### 9.3 包依赖关系

```
provider ──────── 全局状态管理 (7个 ChangeNotifier)
dio ───────────── SubscriptionService, ClashApiService, GeoDataService, WebDavSyncService
shared_preferences ── ConfigStorageService
path_provider ─── GeoDataService, ConfigStorageService
archive ───────── KernelManager (解压)
tray_manager ──── TrayService (系统托盘)
bitsdojo_window ─ main.dart (窗口管理/自定义标题栏)
web_socket_channel ── ClashApiService (实时流量/日志)
share_plus ────── SettingsScreen (配置导出分享)
yaml ──────────── ConfigAdapter (mihomo 配置)
```

---

## 10. 数据流详解

### 10.1 代理启停流程

```
用户点击 "Start"
  → HomeScreen / NodeListSheet
    → ProxyService.start(node)
      → 智能节点模式? → _pickSmartNode() → 自动选路
      → _state = ProxyState.starting, notifyListeners()
      → _getKernelBinaryPath() → KernelManager.getBinaryPath()
      → _writeKernelConfig() → ConfigAdapter.toXxxConfig() → 写入临时文件
      → Process.start(binaryPath, args)
      → 监听 stdout/stderr → _addLog() / _parseTrafficLine()
      → 等待2秒确认进程未退出
      → 成功:
          → _state = ProxyState.running, _startedAt = now
          → testLatency(node)
          → systemProxy? → SystemProxyService.enable()
          → ClashApiService.connect() → WebSocket 流量/日志
          → SmartRouter.recordConnect(success: true)
      → 崩溃:
          → SystemProxyService.disable()
          → SmartRouter.recordConnect(success: false)
          → ClashApiService.disconnect()
          → crashCount < 3? → 自动重启
```

### 10.2 配置修改流程

```
用户修改设置 (如 TUN 开关)
  → SettingsScreen
    → ProxyService.updateConfig() / toggleTun()
      → 更新 _config
      → ConfigStorageService.saveProxyConfig() → 持久化
      → 运行中? → restart() → 应用新配置
      → notifyListeners() → UI 自动重建
```

### 10.3 内核下载流程

```
用户点击 "下载"
  → KernelSettingsScreen / SettingsScreen
    → KernelManager.downloadKernel(type)
      → _statusMap[type] = KernelStatus.downloading, notifyListeners()
      → GitHub API 查询最新版本
      → HTTP 下载压缩包
      → archive 解压 (.zip / .gz)
      → Unix: chmod +x
      → _statusMap[type] = KernelStatus.installed
      → notifyListeners() → UI 更新状态
```

### 10.4 订阅更新流程

```
用户点击 "Update"
  → SubscriptionsScreen
    → SubscriptionService.updateSubscription(id)
      → _isLoading = true, notifyListeners()
      → Dio.get(subscription.url)
      → _parseSubscription(body)
        → 尝试 Base64 解码
        → 尝试 JSON 解析 (sing-box/Clash 格式)
        → 逐行解析代理链接
      → onNodesRefreshed?.call(nodes) → ProxyService.addNodes()
      → _isLoading = false, notifyListeners()
```

### 10.5 Clash API 实时数据流

```
ProxyService.start() 成功后
  → ClashApiService.configure(apiUrl: 'http://127.0.0.1:9090')
  → ClashApiService.connect()
    → WebSocket /traffic → _liveUpload / _liveDownload → notifyListeners()
    → WebSocket /logs → _realtimeLogs (最多500条) → notifyListeners()
    → 异常/断开 → 3秒后自动重连
```

---

## 11. 设计模式

### 11.1 ChangeNotifier + Provider

所有服务继承 `ChangeNotifier`，通过 `MultiProvider` 注入 UI 层。UI 通过以下方式响应状态变化：

```dart
// 监听变化 (自动重建)
final service = context.watch<ProxyService>();

// 读取不监听 (不重建)
final service = context.read<ProxyService>();

// Consumer 局部重建
Consumer<KernelManager>(builder: (ctx, manager, _) => ...)
```

### 11.2 静态工具类模式

以下服务使用私有构造函数 + 静态方法，无需实例化：

| 服务 | 原因 |
|------|------|
| `AdminService` | 无状态，仅调用系统命令 |
| `SystemProxyService` | 无状态，仅调用系统命令 |
| `ConfigAdapter` | 无状态，纯函数转换 |
| `AppUtils` | 无状态，纯函数工具 |

### 11.3 适配器模式

`ConfigAdapter` 将应用内部数据模型转换为三种内核格式：

```
ProxyConfig + NodeConfig + List<RoutingRule>
    ├── toSingboxConfig() → sing-box JSON
    ├── toMihomoConfig()  → mihomo JSON
    └── toV2rayConfig()   → v2ray JSON
```

### 11.4 观察者模式

`StreamController.broadcast()` 用于以下事件流：

| 服务 | Stream | 用途 |
|------|--------|------|
| `ProxyService` | `logStream` | 内核日志广播 |
| `ClashApiService` | WebSocket /traffic | 实时流量数据 |
| `ClashApiService` | WebSocket /logs | 实时日志流 |

### 11.5 回调模式

| 回调 | 所在服务 | 用途 |
|------|----------|------|
| `onNodesRefreshed` | `SubscriptionService` | 订阅刷新后通知 ProxyService 更新节点 |
| `TrayListener` | `TrayService` | 托盘菜单点击事件处理 |

### 11.6 崩溃自启模式

`ProxyService` 实现内核进程崩溃自动重启：

```
进程退出 → exitCode.then()
  → 清理系统代理
  → SmartRouter.recordConnect(success: false)
  → ClashApiService.disconnect()
  → crashCount < 3? → 延迟2秒 → start(activeNode)
  → crashCount >= 3? → _state = stopped
```

---

## 12. 协议支持矩阵

| 协议 | sing-box | mihomo | v2ray | 链接格式 |
|------|----------|--------|-------|----------|
| VMess | ✅ | ✅ | ✅ | `vmess://` (Base64 JSON) |
| VLESS | ✅ | ✅ | ❌ | `vless://` (URI) |
| VLESS+REALITY | ✅ | ✅ | ❌ | `vless://...?security=reality` |
| Trojan | ✅ | ✅ | ✅ | `trojan://` (URI) |
| Shadowsocks | ✅ | ✅ | ✅ | `ss://` (URI) |
| Hysteria | ✅ | ✅ | ❌ | `hysteria://` (URI) |
| Hysteria2 | ✅ | ✅ | ❌ | `hysteria2://` (URI) |
| TUIC | ✅ | ✅ | ❌ | `tuic://` (URI) |
| Naive | ✅ | ❌ | ❌ | — |
| WireGuard | ✅ | ❌ | ❌ | — |

---

## 13. 构建与运行

### 13.1 环境要求

- Flutter SDK >= 3.24.0
- Dart SDK >= 3.0.0 < 4.0.0
- Android SDK (Android 构建)
- Visual Studio / Build Tools (Windows 构建)
- Xcode (macOS 构建)

### 13.2 常用命令

```bash
# 安装依赖
flutter pub get

# 运行应用 (调试模式)
flutter run

# 运行测试
flutter test

# 运行测试 (带覆盖率)
flutter test --coverage

# 代码格式化检查
dart format --set-exit-if-changed .

# 静态分析
flutter analyze --no-pub

# 构建 Windows
flutter build windows --release

# 构建 macOS
flutter build macos --release

# 构建 Linux
flutter build linux --release

# 构建 Android APK
flutter build apk --release
```

### 13.3 CI/CD

项目使用 GitHub Actions 进行持续集成，工作流定义在 `.github/workflows/` 下：

| 工作流 | 文件 | 说明 |
|--------|------|------|
| CI | `ci.yml` | 主 CI: 分析/测试/构建/安全扫描 |
| Android | `android-build.yml` | Android 构建 |
| Windows | `windows-build.yml` | Windows 构建 |
| macOS | `macos-build.yml` | macOS 构建 |
| Linux | `linux-build.yml` | Linux 构建 |
| 多平台 | `multi-platform-build.yml` | 多平台联合构建 |
| 发布 | `release.yml` | 版本发布 |
| 代码质量 | `code-quality.yml` | 格式化 + 分析 |
| Issue 过期 | `stale.yml` | 自动关闭过期 Issue |

---

## 14. 扩展指南

### 14.1 添加新内核支持

1. 在 [config.dart](file:///c:/www/ProxCore/lib/models/config.dart) 的 `KernelType` 枚举中添加新类型
2. 在 `KernelType` 构造函数中添加 `label` 和 `repo` 映射
3. 在 [kernel_manager.dart](file:///c:/www/ProxCore/lib/services/kernel_manager.dart) 中添加:
   - 下载 URL 模板
   - 文件名规则
   - 解压逻辑
4. 在 [proxy_service.dart](file:///c:/www/ProxCore/lib/services/proxy_service.dart) 的 `_buildKernelArgs()` 中添加启动参数
5. 在 [config_adapter.dart](file:///c:/www/ProxCore/lib/utils/config_adapter.dart) 中添加配置转换方法

### 14.2 添加新协议支持

1. 在 [config.dart](file:///c:/www/ProxCore/lib/models/config.dart) 的 `ProxyProtocol` 枚举中添加新协议
2. 在 [singbox_config.dart](file:///c:/www/ProxCore/lib/models/singbox_config.dart) 的 `Outbound` 中添加协议特定字段
3. 在 [config_adapter.dart](file:///c:/www/ProxCore/lib/utils/config_adapter.dart) 中添加三种内核格式的协议转换
4. 在 [subscription_service.dart](file:///c:/www/ProxCore/lib/services/subscription_service.dart) 中添加链接解析方法 (`_parseXxx`)
5. 在 [app_utils.dart](file:///c:/www/ProxCore/lib/utils/app_utils.dart) 中添加协议图标映射
6. 在 [proxy_link_importer.dart](file:///c:/www/ProxCore/lib/widgets/proxy_link_importer.dart) 中添加解析和图标映射
7. 在 [node_editor_screen.dart](file:///c:/www/ProxCore/lib/screens/node_editor_screen.dart) 中添加编辑界面

### 14.3 添加新页面

1. 在 `lib/screens/` 下创建新 Screen 文件
2. 如需状态管理，创建对应 Service (继承 `ChangeNotifier`)
3. 在 [main.dart](file:///c:/www/ProxCore/lib/main.dart) 的 `MultiProvider.providers` 中注册
4. 在对应导航入口添加跳转

### 14.4 添加新服务

1. 在 `lib/services/` 下创建新 Service 文件 (继承 `ChangeNotifier`)
2. 在 [main.dart](file:///c:/www/ProxCore/lib/main.dart) 中初始化并注册到 `MultiProvider`
3. 如需与 ProxyService 交互，通过 `setXxx()` 注入或回调

---

## 15. 已知限制与注意事项

| 限制 | 说明 | 影响 |
|------|------|------|
| 内核二进制 | 首次使用需下载，存放在应用支持目录 | 下载失败时无法启动代理 |
| TUN 权限 | TUN 模式需要管理员/root 权限 | Windows 需 UAC 提权，Android 需 VPN 权限 |
| 进程终止差异 | Windows 使用 `Process.kill()`，Unix 使用 SIGTERM/SIGKILL | 需注意跨平台兼容性 |
| 配置不可变 | `SingBoxConfig` 及子模型均为不可变对象 | 修改时需创建新实例 |
| Clash API 依赖 | 实时流量/日志依赖内核的 Clash API (端口 9090) | 非 mihomo/sing-box 内核可能不支持 |
| Linux 系统代理 | 仅生成环境变量脚本，需用户手动 source | 无法自动设置系统代理 |
| WebDAV 密码 | 密码以 Base64 明文存储在本地 | 安全性较低，建议使用专用密码 |
| GeoData 版本 | 使用文件修改日期作为版本标识 | 无法精确判断是否为最新版本 |
| SmartRouter 默认分 | 无历史数据时默认评分 25.0 | 新节点可能被低估或高估 |
| 临时配置文件 | 内核配置写入系统临时目录 | 应用异常退出时可能残留临时文件 |
