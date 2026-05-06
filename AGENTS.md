# AGENTS.md - 项目智能体指南

## 项目概述

**项目名称**: singbox-pro-max-ultra (proxy_client_ui)
**项目类型**: 多平台代理客户端
**项目描述**: 基于 Flutter 的多内核代理客户端 UI，支持 sing-box、mihomo (Clash Meta)、v2ray (Xray) 三种代理内核，覆盖 Windows、macOS、Linux、Android 平台。

## 技术栈

| 层级 | 技术 | 版本 |
|------|------|------|
| UI 框架 | Flutter | >=3.24.0 |
| 语言 | Dart | >=3.0.0 <4.0.0 |
| 状态管理 | Provider | ^6.0.0 |
| HTTP 客户端 | http | ^1.1.0 |
| 序列化 | json_annotation / json_serializable | ^4.8.0 / ^6.7.0 |
| 本地存储 | shared_preferences | ^2.2.0 |
| 文件选择 | file_picker | ^6.0.0 |
| 系统托盘 | system_tray | ^2.0.0 |
| 窗口管理 | window_manager | ^0.3.0 |
| FFI 互操作 | ffi | ^2.1.0 |
| 路径管理 | path_provider | ^2.1.0 |
| 进程管理 | process_run | ^0.12.0 |
| YAML 解析 | yaml | ^3.1.0 |
| 压缩解压 | archive | ^3.4.0 |
| 图表 | fl_chart | ^0.65.0 |
| 测试 | flutter_test / mockito | SDK / ^5.4.0 |
| 代码生成 | build_runner | ^2.4.0 |

## 项目结构

```
proxcore/
├── lib/
│   ├── main.dart                              # 应用入口，MultiProvider + MaterialApp
│   ├── models/                                # 数据模型层
│   │   ├── config.dart                        # KernelType/KernelStatus/NodeConfig/ProxyConfig
│   │   ├── kernel_info.dart                   # KernelInfo/KernelRelease/DownloadProgress
│   │   └── singbox_config.dart                # SingBoxConfig 完整配置模型 (600+ 行)
│   ├── screens/                               # 页面层
│   │   ├── home_screen.dart                   # 主页 (Dashboard/Nodes/Routing/DNS/Settings)
│   │   ├── subscriptions_screen.dart          # 订阅管理
│   │   ├── kernel_settings_screen.dart        # 内核管理
│   │   ├── node_editor_screen.dart            # 节点编辑器
│   │   ├── routing_editor_screen.dart         # 路由规则编辑器
│   │   └── log_screen.dart                    # 日志查看器
│   ├── services/                              # 服务层 (核心业务逻辑)
│   │   ├── proxy_service.dart                 # 代理状态管理 (ChangeNotifier)
│   │   ├── kernel_manager.dart                # 内核管理器 (下载/更新/切换，单例)
│   │   ├── kernel_executor.dart               # 内核进程执行器 (启动/停止/重启)
│   │   ├── kernel_downloader.dart             # 内核下载器 (下载/解压/安装，单例)
│   │   ├── kernel_config_generator.dart       # 内核配置生成器 (多内核格式适配)
│   │   ├── config_storage_service.dart        # 配置持久化存储
│   │   ├── subscription_service.dart          # 订阅服务 (解析/更新/管理)
│   │   ├── connection_state_manager.dart      # 全局连接状态管理器 (单例)
│   │   ├── traffic_statistics_service.dart    # 流量统计服务 (单例)
│   │   └── tun_service.dart                   # TUN 模式服务 (单例)
│   ├── platform/                              # 平台通道
│   │   └── kernel_platform_channel.dart       # MethodChannel/EventChannel 原生通信
│   ├── utils/                                 # 工具层
│   │   ├── app_exceptions.dart                # 异常体系 (Proxy/Kernel/Config/Network/File)
│   │   ├── app_utils.dart                     # 通用工具函数
│   │   ├── config_adapter.dart                # 配置格式适配器 (sing-box/mihomo/v2ray)
│   │   └── platform_detector.dart             # 平台/架构检测
│   └── widgets/                               # 可复用组件
│       ├── connection_status_floating_button.dart  # 连接状态浮动按钮
│       ├── proxy_link_importer.dart           # 代理链接导入器
│       └── traffic_chart_widget.dart          # 流量图表组件
├── android/                                   # Android 原生代码
│   └── app/src/main/kotlin/.../               # MainActivity/ProxyService/VpnServiceImpl
├── assets/
│   ├── bin/                                   # 内核二进制文件目录
│   └── icons/                                 # 图标资源
├── scripts/                                   # 构建脚本
│   ├── build_linux.sh                         # Linux 构建
│   ├── build_windows.ps1                      # Windows 构建
│   ├── create_dmg.sh                          # macOS DMG 打包
│   └── download_kernels.sh                    # 内核下载脚本
├── test/                                      # 测试
│   ├── proxy_service_test.dart                # 服务层 + 模型层单元测试
│   └── widget_test.dart                       # Widget 测试
├── .github/workflows/                         # CI/CD 工作流
│   ├── ci.yml                                 # 主 CI (分析/测试/构建/安全扫描)
│   ├── android-build.yml                      # Android 构建
│   ├── windows-build.yml                      # Windows 构建
│   ├── macos-build.yml                        # macOS 构建
│   ├── linux-build.yml                        # Linux 构建
│   ├── multi-platform-build.yml               # 多平台构建
│   ├── release.yml                            # 发布工作流
│   ├── code-quality.yml                       # 代码质量
│   └── stale.yml                              # Issue 过期管理
├── pubspec.yaml                               # Flutter 依赖配置
└── build.ps1                                  # Windows 构建脚本
```

## 架构模式

### 整体架构: 分层 + Provider 状态管理

```
UI 层 (screens/widgets)
    ↓ watch/read
服务层 (services, ChangeNotifier)
    ↓ 调用
模型层 (models, 纯数据)
    ↓ 依赖
平台层 (platform channels / FFI / Process)
```

### 核心设计模式

1. **ChangeNotifier + Provider**: 所有服务继承 `ChangeNotifier`，通过 `MultiProvider` 注入 UI 层，UI 通过 `context.watch<T>()` / `context.read<T>()` 响应状态变化。
2. **单例模式**: `KernelManager`、`KernelDownloader`、`ConnectionStateManager`、`TrafficStatisticsService`、`TunService` 使用工厂构造函数实现单例。
3. **适配器模式**: `ConfigAdapter` 和 `KernelConfigGenerator` 将通用配置转换为 sing-box / mihomo / v2ray 三种内核格式。
4. **观察者模式**: `StreamController.broadcast()` 用于流量统计、连接状态、TUN 状态的事件流。

### 数据流

```
用户操作 → Screen (StatefulWidget)
    → context.read<ProxyService>().startProxy()
        → ProxyService._status = ProxyStatus.starting
        → notifyListeners()
            → UI 自动重建 (context.watch<ProxyService>())
```

## 关键模块详解

### 1. ProxyService (lib/services/proxy_service.dart)

核心状态管理服务，管理代理连接生命周期。

- **状态枚举**: `ProxyStatus { idle, starting, running, stopping, error }`
- **核心配置**: `SingBoxConfig _currentConfig` — 当前生效的 sing-box 配置
- **关键方法**:
  - `initialize()` — 初始化默认配置
  - `startProxy()` / `stopProxy()` — 启停代理核心
  - `toggleTun(bool)` — 切换 TUN 模式
  - `switchOutbound(String)` — 切换出站节点
  - `importConfig(String)` / `exportConfig()` — 配置导入导出
  - `addOutbound(Outbound)` / `removeOutbound(String)` — 节点增删
  - `updateRoutingRules(List<RuleConfig>)` — 更新路由规则
- **注意**: 当前 `startProxy()` 为模拟实现（`Future.delayed`），实际内核启动需通过 `KernelExecutor` 或 Platform Channel。

### 2. KernelManager (lib/services/kernel_manager.dart)

多内核生命周期管理，单例模式。

- **支持内核**: `KernelType { singBox, mihomo, v2Ray }`
- **GitHub 发布源**:
  - sing-box: `SagerNet/sing-box`
  - mihomo: `MetaCubeX/mihomo`
  - v2ray: `XTLS/Xray-core`
- **关键方法**:
  - `initialize()` — 加载已安装内核 + 检查更新
  - `downloadKernel(type, version)` — 下载指定版本内核
  - `switchKernel(KernelType)` — 切换当前内核
  - `deleteKernel(KernelType)` — 删除已下载内核

### 3. KernelExecutor (lib/services/kernel_executor.dart)

内核进程管理器，通过 `Process.start` 启动内核二进制。

- **启动参数**:
  - sing-box: `run -c <configPath>`
  - mihomo: `-d <dir> -f <configPath>`
  - v2ray: `run -config <configPath>`
- **日志流**: `StreamController<String>.broadcast()` 提供 `logStream`
- **停止策略**: Windows 用 `taskkill /F /PID`，Unix 先 `SIGTERM` 再 `SIGKILL`

### 4. SingBoxConfig (lib/models/singbox_config.dart)

完整的 sing-box 配置数据模型，600+ 行，包含:

- `SingBoxConfig` — 根配置 (log/inbounds/outbounds/route/dns/experimental)
- `Inbound` — 入站 (mixed/socks/http 等)
- `Outbound` — 出站/协议 (vmess/vless/trojan/shadowsocks/hysteria2/tuic/wireguard/selector/urltest/direct/block)
- `TlsConfig` / `RealityConfig` — TLS 和 REALITY 配置
- `TransportConfig` — 传输层 (ws/grpc/http/quic)
- `RouteConfig` / `RuleConfig` — 路由规则
- `DnsConfig` / `DnsServer` / `DnsRule` — DNS 配置
- `TunConfig` / `ClashApiConfig` — TUN 和 Clash API

### 5. SubscriptionService (lib/services/subscription_service.dart)

订阅链接管理，支持解析多种协议链接:

- **链接格式**: `vmess://`、`vless://`、`trojan://`、`ss://`、`hysteria://`、`hysteria2://`、`tuic://`
- **订阅格式**: Base64 编码列表、JSON (sing-box/Clash 格式)
- **自动更新**: 支持 `autoUpdate` + `updateInterval`

### 6. ConfigAdapter (lib/utils/config_adapter.dart)

通用配置到三种内核格式的转换器:

- `adaptToSingBox(Map)` → sing-box JSON 格式
- `adaptToMihomo(Map)` → mihomo (Clash) YAML 格式
- `adaptToV2Ray(Map)` → v2ray (Xray) JSON 格式

### 7. KernelPlatformChannel (lib/platform/kernel_platform_channel.dart)

Flutter 与原生层的通信通道:

- **MethodChannel**: `kernel_proxy` — 调用原生方法 (startKernel/stopKernel/setSystemProxy/startTunDevice 等)
- **EventChannel**: `kernel_proxy/events` — 接收原生事件流

## 支持的代理协议

| 协议 | sing-box | mihomo | v2ray |
|------|----------|--------|-------|
| VMess | ✅ | ✅ | ✅ |
| VLESS | ✅ | ✅ | ❌ |
| VLESS+REALITY | ✅ | ✅ | ❌ |
| Trojan | ✅ | ✅ | ✅ |
| Shadowsocks | ✅ | ✅ | ✅ |
| Hysteria/Hysteria2 | ✅ | ✅ | ❌ |
| TUIC | ✅ | ✅ | ❌ |
| WireGuard | ✅ | ❌ | ❌ |

## 开发命令

```bash
# 安装依赖
flutter pub get

# 运行应用
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

## CI/CD

- **CI 工作流** (`.github/workflows/ci.yml`): Flutter 3.24.0，包含代码分析、单元测试、多平台构建验证、安全扫描 (Trivy)、依赖审查、许可证检查
- **发布工作流**: 支持 Android/Windows/macOS/Linux 多平台发布
- **代码质量**: 格式化检查 + `flutter analyze`

## 编码规范

1. **语言**: Dart，遵循 Flutter 官方风格指南
2. **状态管理**: 所有服务继承 `ChangeNotifier`，通过 Provider 注入
3. **命名**:
   - 文件名: `snake_case.dart`
   - 类名: `PascalCase`
   - 私有成员: `_` 前缀
   - 常量: `lowerCamelCase` (Dart 惯例)
4. **模型**: 手动实现 `toJson()` / `fromJson()`，部分使用 `json_serializable` 代码生成
5. **异常**: 使用自定义异常体系 (`AppException` 子类: `ProxyException`、`KernelException`、`ConfigException`、`NetworkException`、`FileException`)
6. **单例**: 使用 `static final _instance` + `factory` 构造函数模式
7. **资源释放**: 所有 `StreamController` 在 `dispose()` 中关闭，所有 `Timer` 在 `dispose()` 中取消

## 扩展指南

### 添加新内核支持

1. 在 `lib/models/config.dart` 的 `KernelType` 枚举中添加新类型
2. 在 `KernelTypeExtension.name` 和 `fromName` 中添加映射
3. 在 `lib/services/kernel_manager.dart` 中实现下载逻辑 (GitHub 仓库 URL、下载 URL、文件名)
4. 在 `lib/services/kernel_executor.dart` 中添加启动参数
5. 在 `lib/utils/config_adapter.dart` 中添加配置转换方法
6. 在 `lib/services/kernel_config_generator.dart` 中添加配置生成逻辑

### 添加新协议支持

1. 在 `lib/models/singbox_config.dart` 的 `Outbound` 中添加协议特定字段
2. 在 `lib/utils/config_adapter.dart` 中添加三种内核格式的协议转换
3. 在 `lib/services/subscription_service.dart` 中添加链接解析 (`_parseXxx` 方法)
4. 在 `lib/screens/home_screen.dart` 的 `_getProtocolIcon` 中添加图标映射
5. 在 `lib/screens/node_editor_screen.dart` 中添加编辑界面

### 添加新页面

1. 在 `lib/screens/` 下创建新 Screen 文件
2. 如需状态管理，创建对应 Service (继承 `ChangeNotifier`)
3. 在 `lib/main.dart` 的 `MultiProvider.providers` 中注册
4. 在对应导航入口添加跳转

## 注意事项

- **模拟状态**: `ProxyService.startProxy()` 和 `stopProxy()` 当前为模拟实现，实际内核启动需通过 `KernelExecutor` 或 Platform Channel 与原生层通信
- **ConfigStorageService**: 当前使用内存存储，生产环境需接入 `shared_preferences` 或文件系统
- **内核二进制**: 存放在 `assets/bin/` 目录，首次使用需下载
- **权限要求**: TUN 模式需要管理员/root 权限，Android 需要 VPN 权限
- **平台差异**: Windows 使用 `taskkill` 终止进程，Unix 使用 `SIGTERM`/`SIGKILL`；文件权限设置仅在 Unix 执行
- **配置不可变**: `SingBoxConfig` 及其子模型均为不可变对象，修改时需创建新实例 (通过构造函数重建)
