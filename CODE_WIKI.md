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
- [9. 平台层 (platform/)](#9-平台层-platform)
- [10. 依赖关系图](#10-依赖关系图)
- [11. 数据流详解](#11-数据流详解)
- [12. 设计模式](#12-设计模式)
- [13. 协议支持矩阵](#13-协议支持矩阵)
- [14. 构建与运行](#14-构建与运行)
- [15. 扩展指南](#15-扩展指南)
- [16. 已知限制与注意事项](#16-已知限制与注意事项)

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
- 多协议节点配置 (VMess/VLESS/Trojan/SS/Hysteria2/TUIC/WireGuard)
- 订阅链接管理与自动更新
- 路由规则编辑
- DNS 配置管理
- TUN 模式 (全局透明代理)
- 实时流量统计与图表
- 系统代理设置

---

## 2. 技术栈与依赖

### 运行时依赖

| 包名 | 版本 | 用途 |
|------|------|------|
| `flutter` | SDK | UI 框架 |
| `provider` | ^6.0.0 | 状态管理 (ChangeNotifier + Provider) |
| `http` | ^1.1.0 | HTTP 请求 (订阅获取/内核下载) |
| `json_annotation` | ^4.8.0 | JSON 序列化注解 |
| `shared_preferences` | ^2.2.0 | 本地键值存储 |
| `file_picker` | ^6.0.0 | 文件选择器 |
| `url_launcher` | ^6.1.0 | 打开外部链接 |
| `system_tray` | ^2.0.0 | 系统托盘 |
| `window_manager` | ^0.3.0 | 窗口管理 (桌面端) |
| `ffi` | ^2.1.0 | FFI 互操作 |
| `path_provider` | ^2.1.0 | 应用目录路径 |
| `process_run` | ^0.12.0 | 进程管理 |
| `yaml` | ^3.1.0 | YAML 解析 (mihomo 配置) |
| `collection` | ^1.18.0 | 集合操作扩展 |
| `archive` | ^3.4.0 | 压缩解压 (tar.gz/zip/gz) |
| `fl_chart` | ^0.65.0 | 图表绘制 |

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
│   ├── main.dart                                    # 应用入口
│   ├── models/                                      # 数据模型层
│   │   ├── config.dart                              # KernelType/KernelStatus/NodeConfig/ProxyConfig
│   │   ├── kernel_info.dart                         # KernelInfo/KernelRelease/DownloadProgress
│   │   └── singbox_config.dart                      # SingBoxConfig 完整配置模型
│   ├── services/                                    # 服务层 (核心业务逻辑)
│   │   ├── proxy_service.dart                       # 代理状态管理
│   │   ├── kernel_manager.dart                      # 内核管理器 (下载/更新/切换)
│   │   ├── kernel_executor.dart                     # 内核进程执行器
│   │   ├── kernel_downloader.dart                   # 内核下载器
│   │   ├── kernel_config_generator.dart             # 内核配置生成器
│   │   ├── config_storage_service.dart              # 配置持久化存储
│   │   ├── subscription_service.dart                # 订阅服务
│   │   ├── connection_state_manager.dart            # 全局连接状态管理器
│   │   ├── traffic_statistics_service.dart          # 流量统计服务
│   │   └── tun_service.dart                         # TUN 模式服务
│   ├── screens/                                     # 页面层
│   │   ├── home_screen.dart                         # 主页 (5 个子页面)
│   │   ├── subscriptions_screen.dart                # 订阅管理
│   │   ├── kernel_settings_screen.dart              # 内核管理
│   │   ├── node_editor_screen.dart                  # 节点编辑器
│   │   ├── routing_editor_screen.dart               # 路由规则编辑器
│   │   └── log_screen.dart                          # 日志查看器
│   ├── widgets/                                     # 可复用组件
│   │   ├── connection_status_floating_button.dart   # 连接状态浮动按钮
│   │   ├── proxy_link_importer.dart                 # 代理链接导入器
│   │   └── traffic_chart_widget.dart                # 流量图表组件
│   ├── utils/                                       # 工具层
│   │   ├── app_exceptions.dart                      # 异常体系
│   │   ├── app_utils.dart                           # 通用工具函数
│   │   ├── config_adapter.dart                      # 配置格式适配器
│   │   └── platform_detector.dart                   # 平台/架构检测
│   └── platform/                                    # 平台通道
│       └── kernel_platform_channel.dart             # MethodChannel/EventChannel
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
│              平台层 (platform / Process / FFI)           │
│         MethodChannel / EventChannel / Process.start    │
└─────────────────────────────────────────────────────────┘
```

### 4.2 Provider 注入

在 [main.dart](file:///c:/www/ProxCore/lib/main.dart) 中通过 `MultiProvider` 注入全局服务：

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ProxyService()),
    ChangeNotifierProvider(create: (_) => KernelManager()),
  ],
  child: MaterialApp(...),
)
```

### 4.3 导航结构

```
MainScreen (底部导航)
├── HomeScreen (底部导航: Dashboard/Nodes/Routing/DNS/Settings)
│   ├── DashboardScreen — 代理状态/流量/快捷操作
│   ├── NodesScreen — 节点列表/添加/编辑
│   ├── RoutingScreen — 路由规则列表/编辑
│   ├── DnsScreen — DNS 配置查看
│   └── SettingsScreen — 设置/导出/开发者选项
├── SubscriptionsScreen — 订阅管理
└── KernelSettingsScreen — 内核管理
```

---

## 5. 模型层 (models/)

### 5.1 config.dart

[config.dart](file:///c:/www/ProxCore/lib/models/config.dart) 定义了内核类型、状态和基础配置模型。

| 类/枚举 | 说明 |
|---------|------|
| `KernelType` | 内核类型枚举: `singBox` / `mihomo` / `v2Ray` |
| `KernelTypeExtension` | 扩展: `name` 属性和 `fromName()` 工厂方法 |
| `KernelStatus` | 内核状态枚举: `stopped` / `starting` / `running` / `stopping` / `error` |
| `KernelStatusExtension` | 扩展: `description` (中文描述) 和 `getColor()` |
| `NodeConfig` | 节点配置: name/type/server/port/uuid/password/method |
| `ProxyConfig` | 代理配置: kernelType/logLevel/httpPort/socksPort/nodes/defaultNode |

### 5.2 kernel_info.dart

[kernel_info.dart](file:///c:/www/ProxCore/lib/models/kernel_info.dart) 定义了内核信息与发布版本模型。

| 类 | 说明 | 关键字段 |
|----|------|----------|
| `KernelInfo` | 已安装内核信息 | type, version, currentPath, isDownloaded, lastUpdated, supportedProtocols |
| `KernelRelease` | GitHub 发布版本 | version, downloadUrl, changelog, publishedAt, assets |
| `DownloadProgress` | 下载进度 | received, total, progress, speed |

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

[proxy_service.dart](file:///c:/www/ProxCore/lib/services/proxy_service.dart) — 核心状态管理服务

| 项目 | 说明 |
|------|------|
| 继承 | `ChangeNotifier` |
| Provider | 全局注入，UI 通过 `context.watch<ProxyService>()` 响应 |
| 状态枚举 | `ProxyStatus { idle, starting, running, stopping, error }` |

**关键属性**:

| 属性 | 类型 | 说明 |
|------|------|------|
| `_status` | `ProxyStatus` | 当前代理状态 |
| `_currentConfig` | `SingBoxConfig?` | 当前生效的 sing-box 配置 |
| `_errorMessage` | `String?` | 错误信息 |
| `_trafficUp` / `_trafficDown` | `int` | 流量统计 |
| `_latency` | `double` | 延迟 |
| `_selectedOutbound` | `String` | 当前选中的出站标签 |

**关键方法**:

| 方法 | 说明 |
|------|------|
| `initialize()` | 初始化默认配置 |
| `startProxy()` | 启动代理 (当前为模拟实现) |
| `stopProxy()` | 停止代理 |
| `toggleTun(bool)` | 切换 TUN 模式 |
| `switchOutbound(String)` | 切换出站节点 |
| `testLatency()` | 测试所有出站延迟 |
| `importConfig(String)` | 从 JSON 字符串导入配置 |
| `exportConfig()` | 导出配置为 JSON 字符串 |
| `addOutbound(Outbound)` | 添加出站节点 |
| `removeOutbound(String)` | 删除出站节点 |
| `updateRoutingRules(List<RuleConfig>)` | 更新路由规则 |

### 6.2 KernelManager

[kernel_manager.dart](file:///c:/www/ProxCore/lib/services/kernel_manager.dart) — 多内核生命周期管理

| 项目 | 说明 |
|------|------|
| 模式 | **单例** (`static final _instance` + `factory`) |
| 继承 | `ChangeNotifier` |
| Provider | 全局注入 |

**关键属性**:

| 属性 | 类型 | 说明 |
|------|------|------|
| `_selectedKernelType` | `KernelType` | 当前选中的内核类型 |
| `_kernels` | `Map<KernelType, KernelInfo>` | 各内核的安装信息 |
| `_releases` | `Map<KernelType, List<KernelRelease>>` | GitHub 发布版本缓存 |
| `_currentDownload` | `DownloadProgress?` | 当前下载进度 |

**关键方法**:

| 方法 | 说明 |
|------|------|
| `initialize()` | 加载已安装内核 + 检查更新 |
| `downloadKernel(type, version)` | 下载指定版本内核 |
| `switchKernel(KernelType)` | 切换当前内核 |
| `deleteKernel(KernelType)` | 删除已下载内核 |

**GitHub 发布源**:

| 内核 | 仓库 |
|------|------|
| sing-box | `SagerNet/sing-box` |
| mihomo | `MetaCubeX/mihomo` |
| v2ray | `XTLS/Xray-core` |

### 6.3 KernelExecutor

[kernel_executor.dart](file:///c:/www/ProxCore/lib/services/kernel_executor.dart) — 内核进程管理器

| 项目 | 说明 |
|------|------|
| 模式 | 普通类 (非单例) |
| 进程管理 | `Process.start` 启动内核二进制 |

**启动参数映射**:

| 内核 | 命令行参数 |
|------|-----------|
| sing-box | `run -c <configPath>` |
| mihomo | `-d <dir> -f <configPath>` |
| v2ray | `run -config <configPath>` |

**停止策略**:
- **Windows**: `taskkill /F /PID <pid>`
- **Unix**: 先 `SIGTERM`，等待 5 秒后 `SIGKILL`

**日志流**: `StreamController<String>.broadcast()` → `logStream`

**静态方法**:

| 方法 | 说明 |
|------|------|
| `checkKernel(path)` | 检查内核是否可用 |
| `getVersion(path)` | 获取内核版本号 |

### 6.4 KernelDownloader

[kernel_downloader.dart](file:///c:/www/ProxCore/lib/services/kernel_downloader.dart) — 内核下载器

| 项目 | 说明 |
|------|------|
| 模式 | **单例** |
| 功能 | 下载/解压/安装内核 |

**下载流程**:
1. 构造下载 URL (基于平台+架构)
2. HTTP 流式下载，每 500ms 更新进度
3. 解压文件 (支持 .gz / .zip / .tar.gz)
4. 设置可执行权限 (Unix: `chmod +x`)
5. 发送完成进度

**辅助类**: `CancelToken` — 支持取消下载

### 6.5 KernelConfigGenerator

[kernel_config_generator.dart](file:///c:/www/ProxCore/lib/services/kernel_config_generator.dart) — 内核配置生成器

| 项目 | 说明 |
|------|------|
| 模式 | 静态工具类 |
| 功能 | 将通用配置转换为三种内核格式并写入文件 |

**核心方法**:

| 方法 | 输出格式 | 说明 |
|------|----------|------|
| `generateConfig(kernelType: singBox)` | JSON | sing-box 配置 |
| `generateConfig(kernelType: mihomo)` | YAML | mihomo (Clash) 配置 |
| `generateConfig(kernelType: v2Ray)` | JSON | v2ray (Xray) 配置 |

**配置文件存储**: `{appDir}/config/config_{kernelType}.{json|yaml}`

### 6.6 ConfigStorageService

[config_storage_service.dart](file:///c:/www/ProxCore/lib/services/config_storage_service.dart) — 配置持久化存储

| 项目 | 说明 |
|------|------|
| 继承 | `ChangeNotifier` |
| 当前实现 | **内存存储** (生产环境需接入 `shared_preferences`) |

**存储键**:

| 键 | 说明 |
|----|------|
| `subscriptions` | 订阅列表 |
| `current_config` | 当前配置 |
| `settings` | 应用设置 |

**辅助类**: `AppSettings` — 应用设置模型 (autoStart/startOnBoot/minimizeToTray/darkMode/language/defaultPort/enableTunByDefault/logLevel)

### 6.7 SubscriptionService

[subscription_service.dart](file:///c:/www/ProxCore/lib/services/subscription_service.dart) — 订阅服务

| 项目 | 说明 |
|------|------|
| 继承 | `ChangeNotifier` |

**支持的链接格式**:

| 协议 | 链接格式 | 解析方法 |
|------|----------|----------|
| VMess | `vmess://` (Base64 JSON) | `_parseVmess()` |
| VLESS | `vless://` (URI) | `_parseVless()` |
| Trojan | `trojan://` (URI) | `_parseTrojan()` |
| Shadowsocks | `ss://` (URI) | `_parseShadowsocks()` |
| Hysteria/Hysteria2 | `hysteria://` / `hysteria2://` | `_parseHysteria()` |
| TUIC | `tuic://` (URI) | `_parseTuic()` |

**订阅格式**: Base64 编码列表 / JSON (sing-box / Clash 格式)

**辅助类**: `Subscription` — 订阅模型 (id/name/url/lastUpdated/nodeCount/autoUpdate/updateInterval)

### 6.8 ConnectionStateManager

[connection_state_manager.dart](file:///c:/www/ProxCore/lib/services/connection_state_manager.dart) — 全局连接状态管理器

| 项目 | 说明 |
|------|------|
| 模式 | **单例** |
| 通信 | `StreamController<ConnectionStatus>.broadcast()` |

**状态枚举**: `ConnectionState { disconnected, connecting, connected, error }`

**ConnectionStatus 字段**: state, message, activeKernel, connectedAt, uploadSpeed, downloadSpeed, totalUpload, totalDownload

**便捷方法**: `setConnecting()`, `setConnected()`, `setDisconnected()`, `setError()`, `updateTraffic()`

### 6.9 TrafficStatisticsService

[traffic_statistics_service.dart](file:///c:/www/ProxCore/lib/services/traffic_statistics_service.dart) — 流量统计服务

| 项目 | 说明 |
|------|------|
| 模式 | **单例** |
| 数据流 | `StreamController<TrafficData>.broadcast()` |
| 历史数据 | 保留最近 60 秒 (60 个数据点) |

**辅助类**:

| 类 | 说明 |
|----|------|
| `TrafficData` | 流量数据包 (uploadSpeed/downloadSpeed/totalUpload/totalDownload/history) |
| `TrafficDataPoint` | 流量数据点 (timestamp/uploadSpeed/downloadSpeed) |

### 6.10 TunService

[tun_service.dart](file:///c:/www/ProxCore/lib/services/tun_service.dart) — TUN 模式服务

| 项目 | 说明 |
|------|------|
| 模式 | **单例** |
| 状态流 | `StreamController<bool>.broadcast()` |

**平台差异**:
- **Android**: 通过 `KernelPlatformChannel` 请求 VPN 权限 → 启动 TUN 设备
- **桌面**: 通过 `KernelPlatformChannel` 启动内核并启用 TUN

---

## 7. UI 层 (screens/ & widgets/)

### 7.1 页面一览

| 页面 | 文件 | 说明 |
|------|------|------|
| `MainScreen` | [main.dart](file:///c:/www/ProxCore/lib/main.dart) | 主框架，底部导航 (Home/Subscriptions/Kernel) |
| `HomeScreen` | [home_screen.dart](file:///c:/www/ProxCore/lib/screens/home_screen.dart) | 主页，内含 5 个子页面 |
| `DashboardScreen` | home_screen.dart | 仪表盘: 状态卡片/流量统计/快捷操作 |
| `NodesScreen` | home_screen.dart | 节点列表: 查看/添加/编辑/删除节点 |
| `RoutingScreen` | home_screen.dart | 路由规则: 查看/添加/编辑/删除规则 |
| `DnsScreen` | home_screen.dart | DNS 配置查看 |
| `SettingsScreen` | home_screen.dart | 设置: TUN/自启动/导出/日志/关于 |
| `SubscriptionsScreen` | [subscriptions_screen.dart](file:///c:/www/ProxCore/lib/screens/subscriptions_screen.dart) | 订阅管理: 添加/编辑/更新/删除/导入 |
| `KernelSettingsScreen` | [kernel_settings_screen.dart](file:///c:/www/ProxCore/lib/screens/kernel_settings_screen.dart) | 内核管理: 下载/切换/更新/删除 |
| `NodeEditorScreen` | [node_editor_screen.dart](file:///c:/www/ProxCore/lib/screens/node_editor_screen.dart) | 节点编辑器: 协议/服务器/认证/TLS/传输/REALITY |
| `RoutingEditorScreen` | [routing_editor_screen.dart](file:///c:/www/ProxCore/lib/screens/routing_editor_screen.dart) | 路由规则编辑器: 规则类型/出站/条件/预设 |
| `LogScreen` | [log_screen.dart](file:///c:/www/ProxCore/lib/screens/log_screen.dart) | 日志查看器: 过滤/自动滚动/导出 |

### 7.2 可复用组件

| 组件 | 文件 | 说明 |
|------|------|------|
| `ConnectionStatusFloatingButton` | [connection_status_floating_button.dart](file:///c:/www/ProxCore/lib/widgets/connection_status_floating_button.dart) | 连接状态悬浮球，监听 `ConnectionStateManager` |
| `ProxyLinkImporter` | [proxy_link_importer.dart](file:///c:/www/ProxCore/lib/widgets/proxy_link_importer.dart) | 代理链接导入器，支持多协议解析 |
| `TrafficChartWidget` | [traffic_chart_widget.dart](file:///c:/www/ProxCore/lib/widgets/traffic_chart_widget.dart) | 实时流量图表，使用 `CustomPaint` 绘制 |

---

## 8. 工具层 (utils/)

### 8.1 app_exceptions.dart

[app_exceptions.dart](file:///c:/www/ProxCore/lib/utils/app_exceptions.dart) — 自定义异常体系

```
AppException (基类)
├── ProxyException      — 代理服务异常
├── KernelException     — 内核管理异常
├── ConfigException     — 配置异常
├── NetworkException    — 网络异常
└── FileException       — 文件操作异常
```

每个异常类携带: `message`, `originalError`, `stackTrace`

### 8.2 app_utils.dart

[app_utils.dart](file:///c:/www/ProxCore/lib/utils/app_utils.dart) — 通用工具函数

| 方法 | 说明 |
|------|------|
| `testConnectivity(host, port)` | TCP 连通性测试，返回延迟 |
| `parseProxyLink(link)` | 解析代理链接 (7 种协议) |
| `formatBytes(bytes)` | 格式化字节为可读字符串 |
| `isValidIpCidr(ipCidr)` | 验证 IP/CIDR 格式 |
| `isValidDomain(domain)` | 验证域名格式 |

### 8.3 config_adapter.dart

[config_adapter.dart](file:///c:/www/ProxCore/lib/utils/config_adapter.dart) — 配置格式适配器

| 方法 | 输出格式 | 说明 |
|------|----------|------|
| `adaptToSingBox(Map)` | sing-box JSON | 转换为 sing-box 配置 |
| `adaptToMihomo(Map)` | mihomo YAML | 转换为 mihomo (Clash) 配置 |
| `adaptToV2Ray(Map)` | v2ray JSON | 转换为 v2ray (Xray) 配置 |

### 8.4 platform_detector.dart

[platform_detector.dart](file:///c:/www/ProxCore/lib/utils/platform_detector.dart) — 平台/架构检测

| 方法 | 说明 |
|------|------|
| `getPlatformName()` | 返回平台标识: windows/darwin/linux/android/ios |
| `getArchitecture()` | 返回架构标识: amd64/arm64/arm/386/mips64/... |
| `getTargetPlatform()` | 返回完整目标标识 (如 `android-arm64-v8a`) |

---

## 9. 平台层 (platform/)

### 9.1 KernelPlatformChannel

[kernel_platform_channel.dart](file:///c:/www/ProxCore/lib/platform/kernel_platform_channel.dart) — Flutter 与原生层通信

| 项目 | 说明 |
|------|------|
| 模式 | **单例** |
| MethodChannel | `kernel_proxy` |
| EventChannel | `kernel_proxy/events` |

**MethodChannel 方法**:

| 方法 | 参数 | 说明 |
|------|------|------|
| `startKernel` | configPath, kernelType, tunMode, tunDeviceName | 启动内核 |
| `stopKernel` | — | 停止内核 |
| `getKernelStatus` | — | 获取内核状态 |
| `setSystemProxy` | enable, host, port, bypassDomains | 设置系统代理 |
| `startTunDevice` | configPath, deviceName, ipAddress, mtu | 启动 TUN 设备 |
| `stopTunDevice` | — | 停止 TUN 设备 |
| `checkVpnPermission` | — | 检查 VPN 权限 (Android) |
| `requestVpnPermission` | — | 请求 VPN 权限 (Android) |
| `getLogs` | limit | 获取日志 |
| `clearLogs` | — | 清除日志 |

---

## 10. 依赖关系图

### 10.1 模块依赖

```
main.dart
├── ProxyService ──┬── SingBoxConfig (models)
│                  ├── AppException (utils)
│                  └── ChangeNotifier
├── KernelManager ─┬── KernelInfo (models)
│                  ├── KernelType (models/config)
│                  ├── PlatformDetector (utils)
│                  ├── AppException (utils)
│                  ├── http, path_provider
│                  └── ChangeNotifier
├── HomeScreen ────┬── ProxyService (Provider)
│                  ├── SingBoxConfig (models)
│                  ├── ProxyLinkImporter (widget)
│                  ├── LogScreen, NodeEditorScreen, RoutingEditorScreen
│                  └── Multiple sub-screens
├── SubscriptionsScreen ── SubscriptionService ── Outbound (models)
└── KernelSettingsScreen ── KernelManager (Provider), KernelDownloader
```

### 10.2 服务间依赖

```
ProxyService (核心状态)
    ↑ 被 UI 层直接 watch
    ├── 使用 SingBoxConfig 模型
    └── 使用 AppException 异常

KernelManager (内核管理)
    ↑ 被 UI 层直接 watch
    ├── 使用 KernelInfo 模型
    ├── 使用 PlatformDetector
    └── 使用 http (GitHub API)

KernelExecutor (进程管理)
    ↑ 被 ProxyService / TunService 调用
    ├── 使用 KernelType
    └── 使用 Process / ProcessSignal

KernelDownloader (下载)
    ↑ 被 KernelManager / KernelSettingsScreen 调用
    ├── 使用 archive (解压)
    └── 使用 http (下载)

KernelConfigGenerator (配置生成)
    ↑ 被 KernelExecutor 调用
    ├── 使用 KernelType
    └── 使用 path_provider

ConnectionStateManager (连接状态)
    ↑ 被 TunService / TrafficStatisticsService 调用
    └── 使用 ConnectionStatus 模型

TrafficStatisticsService (流量统计)
    ↑ 被 TrafficChartWidget 监听
    └── 调用 ConnectionStateManager

TunService (TUN 模式)
    ├── 调用 KernelPlatformChannel
    └── 调用 ConnectionStateManager

SubscriptionService (订阅)
    ↑ 被 SubscriptionsScreen watch
    ├── 使用 Outbound 模型
    └── 使用 http (订阅获取)
```

### 10.3 包依赖关系

```
provider ──────── 全局状态管理
http ──────────── SubscriptionService, KernelManager, KernelDownloader
path_provider ─── KernelManager, KernelDownloader, KernelConfigGenerator
archive ───────── KernelDownloader (解压)
ffi ───────────── 平台互操作
process_run ───── 内核进程管理
yaml ──────────── mihomo 配置解析
shared_preferences ── ConfigStorageService (待接入)
system_tray ───── 系统托盘
window_manager ── 桌面窗口管理
fl_chart ──────── 流量图表 (当前使用 CustomPaint 替代)
```

---

## 11. 数据流详解

### 11.1 代理启停流程

```
用户点击 "Start"
  → DashboardScreen.build()
    → ProxyService.startProxy()
      → _status = ProxyStatus.starting
      → notifyListeners()          ← UI 自动重建
      → Future.delayed(2s)         ← 模拟启动
      → _status = ProxyStatus.running
      → _startTrafficMonitor()     ← 启动流量监控定时器
      → notifyListeners()          ← UI 自动重建
```

### 11.2 配置修改流程

```
用户编辑节点
  → NodeEditorScreen._saveNode()
    → ProxyService.addOutbound(Outbound)
      → 创建新的 SingBoxConfig (不可变重建)
      → notifyListeners()
        → NodesScreen 自动重建
```

### 11.3 内核下载流程

```
用户点击 "下载"
  → KernelSettingsScreen._downloadKernel()
    → KernelManager.downloadKernel(type, version)
      → _currentDownload = DownloadProgress(...)
      → notifyListeners()          ← UI 显示进度
      → HTTP 流式下载
      → 每 500ms 更新 _currentDownload
      → notifyListeners()          ← UI 更新进度条
      → 下载完成 → _kernels[type] = KernelInfo(isDownloaded: true)
      → _currentDownload = null
      → notifyListeners()          ← UI 更新状态
```

### 11.4 订阅更新流程

```
用户点击 "Update"
  → SubscriptionsScreen._handleMenuAction('update')
    → SubscriptionService.updateSubscription(id)
      → _isUpdating = true, notifyListeners()
      → http.get(subscription.url)
      → _parseSubscription(body)
        → 尝试 Base64 解码
        → 尝试 JSON 解析 (sing-box/Clash 格式)
        → 逐行解析代理链接
      → _subscriptions[index] = subscription.copyWith(nodeCount: ...)
      → _isUpdating = false, notifyListeners()
```

---

## 12. 设计模式

### 12.1 ChangeNotifier + Provider

所有服务继承 `ChangeNotifier`，通过 `MultiProvider` 注入 UI 层。UI 通过以下方式响应状态变化：

```dart
// 监听变化 (自动重建)
final service = context.watch<ProxyService>();

// 读取不监听 (不重建)
final service = context.read<ProxyService>();

// Consumer 局部重建
Consumer<KernelManager>(builder: (ctx, manager, _) => ...)
```

### 12.2 单例模式

以下服务使用 `static final _instance` + `factory` 构造函数实现单例：

| 服务 | 单例原因 |
|------|----------|
| `KernelManager` | 全局唯一内核管理状态 |
| `KernelDownloader` | 防止并发下载 |
| `ConnectionStateManager` | 全局唯一连接状态 |
| `TrafficStatisticsService` | 全局唯一流量统计 |
| `TunService` | 全局唯一 TUN 状态 |
| `KernelPlatformChannel` | 全局唯一平台通道 |

### 12.3 适配器模式

`ConfigAdapter` 和 `KernelConfigGenerator` 将通用配置转换为三种内核格式：

```
通用配置 (Map<String, dynamic>)
    ├── adaptToSingBox() → sing-box JSON
    ├── adaptToMihomo()  → mihomo YAML
    └── adaptToV2Ray()   → v2ray JSON
```

### 12.4 观察者模式

`StreamController.broadcast()` 用于以下事件流：

| 服务 | Stream | 用途 |
|------|--------|------|
| `KernelExecutor` | `logStream` | 内核日志 |
| `ConnectionStateManager` | `statusStream` | 连接状态变化 |
| `TrafficStatisticsService` | `trafficStream` | 流量数据更新 |
| `TunService` | `statusStream` | TUN 启停状态 |
| `KernelDownloader` | `progressStream` | 下载进度 |
| `KernelPlatformChannel` | `eventStream` | 原生事件 |

---

## 13. 协议支持矩阵

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
| WireGuard | ✅ | ❌ | ❌ | — |

---

## 14. 构建与运行

### 14.1 环境要求

- Flutter SDK >= 3.24.0
- Dart SDK >= 3.0.0 < 4.0.0
- Android SDK (Android 构建)
- Visual Studio / Build Tools (Windows 构建)
- Xcode (macOS 构建)

### 14.2 常用命令

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

### 14.3 CI/CD

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

## 15. 扩展指南

### 15.1 添加新内核支持

1. 在 [config.dart](file:///c:/www/ProxCore/lib/models/config.dart) 的 `KernelType` 枚举中添加新类型
2. 在 `KernelTypeExtension.name` 和 `fromName` 中添加映射
3. 在 [kernel_manager.dart](file:///c:/www/ProxCore/lib/services/kernel_manager.dart) 中添加:
   - `_getGithubRepoUrl()` — GitHub 仓库 URL
   - `_getDownloadUrl()` — 下载 URL 模板
   - `_getKernelFileName()` — 文件名
   - `_getSupportedProtocols()` — 支持的协议列表
4. 在 [kernel_executor.dart](file:///c:/www/ProxCore/lib/services/kernel_executor.dart) 的 `start()` 中添加启动参数
5. 在 [config_adapter.dart](file:///c:/www/ProxCore/lib/utils/config_adapter.dart) 中添加配置转换方法
6. 在 [kernel_config_generator.dart](file:///c:/www/ProxCore/lib/services/kernel_config_generator.dart) 中添加配置生成逻辑

### 15.2 添加新协议支持

1. 在 [singbox_config.dart](file:///c:/www/ProxCore/lib/models/singbox_config.dart) 的 `Outbound` 中添加协议特定字段
2. 在 [config_adapter.dart](file:///c:/www/ProxCore/lib/utils/config_adapter.dart) 中添加三种内核格式的协议转换
3. 在 [subscription_service.dart](file:///c:/www/ProxCore/lib/services/subscription_service.dart) 中添加链接解析方法 (`_parseXxx`)
4. 在 [app_utils.dart](file:///c:/www/ProxCore/lib/utils/app_utils.dart) 中添加链接解析
5. 在 [proxy_link_importer.dart](file:///c:/www/ProxCore/lib/widgets/proxy_link_importer.dart) 中添加解析和图标映射
6. 在 [node_editor_screen.dart](file:///c:/www/ProxCore/lib/screens/node_editor_screen.dart) 中添加编辑界面

### 15.3 添加新页面

1. 在 `lib/screens/` 下创建新 Screen 文件
2. 如需状态管理，创建对应 Service (继承 `ChangeNotifier`)
3. 在 [main.dart](file:///c:/www/ProxCore/lib/main.dart) 的 `MultiProvider.providers` 中注册
4. 在对应导航入口添加跳转

---

## 16. 已知限制与注意事项

| 限制 | 说明 | 影响 |
|------|------|------|
| 模拟代理启停 | `ProxyService.startProxy()` 和 `stopProxy()` 使用 `Future.delayed` 模拟 | 实际内核启动需通过 `KernelExecutor` 或 Platform Channel |
| 内存存储 | `ConfigStorageService` 当前使用内存存储 | 应用重启后数据丢失，需接入 `shared_preferences` |
| 内核二进制 | 存放在 `assets/bin/` 目录 | 首次使用需下载 |
| TUN 权限 | TUN 模式需要管理员/root 权限 | Android 需要 VPN 权限 |
| 进程终止差异 | Windows 使用 `taskkill`，Unix 使用 `SIGTERM`/`SIGKILL` | 需注意跨平台兼容性 |
| 配置不可变 | `SingBoxConfig` 及子模型均为不可变对象 | 修改时需创建新实例 |
| 流量监控模拟 | `ProxyService._startTrafficMonitor()` 使用随机数模拟 | 需接入实际内核流量 API |
| 日志模拟 | `LogScreen` 使用 `Future.delayed` 模拟日志 | 需接入 `KernelExecutor.logStream` |
| 订阅导入 | 订阅节点导入到 ProxyService 为模拟实现 | 需完善实际导入逻辑 |
| YAML 生成 | `_convertToYaml()` 为基础实现 | 复杂 YAML 结构可能需要专业库 |
