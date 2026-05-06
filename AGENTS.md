# AGENTS.md - 项目智能体指南

## 项目概述

**项目名称**: ProxCore (proxcore)
**项目类型**: 多平台代理客户端
**项目描述**: 基于 Flutter 的多内核代理客户端 UI，支持 sing-box、mihomo (Clash Meta)、v2ray (Xray) 三种代理内核，覆盖 Windows、macOS、Linux、Android 平台。

## 技术栈

| 层级 | 技术 | 版本 |
|------|------|------|
| UI 框架 | Flutter | >=3.24.0 |
| 语言 | Dart | ^3.11.5 |
| 状态管理 | Provider | ^6.1.2 |
| HTTP 客户端 | Dio | ^5.7.0 |
| 本地存储 | shared_preferences | ^2.3.4 |
| 文件选择 | file_picker | ^11.0.2 |
| 系统托盘 | tray_manager | ^0.5.2 |
| 窗口管理 | bitsdojo_window | ^0.1.6 |
| 路径管理 | path_provider | ^2.1.5 |
| WebSocket | web_socket_channel | ^3.0.1 |
| 压缩解压 | archive | ^4.0.9 |
| UUID 生成 | uuid | ^4.5.1 |
| 分享 | share_plus | ^10.1.4 |
| SVG 渲染 | flutter_svg | ^2.0.17 |
| URL 启动 | url_launcher | ^6.3.1 |
| 测试 | flutter_test / flutter_lints | SDK / ^6.0.0 |

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
│   │   ├── settings_screen.dart               # 设置页面 (内核/网络/规则/DNS/端口/数据/外观/关于)
│   │   └── log_screen.dart                    # 日志查看器
│   ├── services/                              # 服务层 (核心业务逻辑)
│   │   ├── proxy_service.dart                 # 代理核心服务 (内核启停/节点管理/流量统计/系统代理/TUN/智能选路)
│   │   ├── kernel_manager.dart                # 内核管理器 (下载/更新/切换，ChangeNotifier)
│   │   ├── config_storage_service.dart        # 配置持久化存储
│   │   ├── subscription_service.dart          # 订阅服务 (解析/更新/管理)
│   │   ├── clash_api_service.dart             # Clash API 服务 (WebSocket流量/日志/节点/代理模式切换)
│   │   ├── smart_router.dart                  # 智能路由 (节点评分/自动选路)
│   │   ├── admin_service.dart                 # 管理员权限服务 (UAC提权/权限检测，静态工具类)
│   │   ├── system_proxy_service.dart          # 系统代理服务 (Windows注册表/macOS networksetup/Linux环境变量，静态工具类)
│   │   ├── geo_data_service.dart              # 地理数据服务 (GeoIP/GeoSite下载管理)
│   │   ├── tray_service.dart                  # 系统托盘服务 (最小化/状态图标/右键菜单)
│   │   └── webdav_sync_service.dart           # WebDAV同步服务 (云端备份/恢复)
│   ├── utils/                                 # 工具层
│   │   ├── app_utils.dart                     # 通用工具函数
│   │   └── config_adapter.dart                # 配置格式适配器 (sing-box/mihomo/v2ray)
│   └── widgets/                               # 可复用组件
│       ├── glass_theme.dart                   # 毛玻璃主题组件 (GlassTheme/GlassCard/GlassButton/GlassSwitch)
│       └── proxy_link_importer.dart           # 代理链接导入器
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
平台层 (Process.start / 系统命令 / FFI)
```

### 核心设计模式

1. **ChangeNotifier + Provider**: 所有服务继承 `ChangeNotifier`，通过 `MultiProvider` 注入 UI 层，UI 通过 `context.watch<T>()` / `context.read<T>()` 响应状态变化。
2. **静态工具类**: `AdminService` 和 `SystemProxyService` 使用私有构造函数 + 静态方法模式，无需实例化。
3. **适配器模式**: `ConfigAdapter` 将通用配置转换为 sing-box / mihomo / v2ray 三种内核格式。
4. **观察者模式**: `StreamController.broadcast()` 用于日志流、速度历史的事件流；ClashApiService 通过 WebSocket 实时监听流量和日志。
5. **注入模式**: ProxyService 通过 `setClashApi()` / `setSmartRouter()` 注入依赖，由 main.dart 统一组装。

### 数据流

```
用户操作 → Screen (StatefulWidget)
    → context.read<ProxyService>().start(node)
        → ProxyService._state = ProxyState.starting
        → Process.start(binaryPath, args) 启动内核进程
        → notifyListeners()
            → UI 自动重建 (context.watch<ProxyService>())
```

## 关键模块详解

### 1. ProxyService (lib/services/proxy_service.dart)

核心代理服务，管理代理内核的完整生命周期。

- **状态枚举**: `ProxyState { stopped, starting, running, stopping }`
- **核心配置**: `ProxyConfig _config` — 当前生效的代理配置
- **内核进程**: `Process? _process` — 通过 `Process.start` 启动内核二进制
- **关键方法**:
  - `init()` — 从持久化存储加载配置、节点和路由规则
  - `start(NodeConfig)` — 启动代理内核（智能选路→生成配置→Process.start→连接ClashApi→设置系统代理）
  - `stop()` — 停止代理内核（断开ClashApi→kill进程→清理系统代理）
  - `restart(NodeConfig)` — 重启代理内核
  - `toggleTun(bool)` — 切换 TUN 模式（运行中自动重启）
  - `updateConfig(ProxyConfig)` — 更新配置并自动持久化
  - `addNode(NodeConfig)` / `addNodes(List)` / `deleteNode(String)` / `updateNode(NodeConfig)` — 节点增删改查
  - `testLatency(NodeConfig)` / `testAllLatency(List)` — 节点测速
  - `updateRoutingRules(List<RoutingRule>)` — 更新路由规则
  - `exportConfig()` / `importConfig(String)` — 配置导入导出
  - `setSystemProxy(bool)` — 设置/移除系统代理
- **崩溃自启**: 进程异常退出时自动重启（最多3次），超过后停止重试
- **内核启动参数**:
  - sing-box: `run -c <configPath>`
  - mihomo: `-f <configPath>`
  - v2ray: `run -c <configPath>`

### 2. KernelManager (lib/services/kernel_manager.dart)

多内核生命周期管理，普通 ChangeNotifier（非单例）。

- **支持内核**: `KernelType { singBox, mihomo, v2Ray }`
- **GitHub 发布源**:
  - sing-box: `SagerNet/sing-box`
  - mihomo: `MetaCubeX/mihomo`
  - v2ray: `XTLS/Xray-core`
- **关键方法**:
  - `init()` — 检测已安装内核
  - `downloadKernel(KernelType)` — 下载指定类型内核（自动解压安装）
  - `isInstalled(KernelType)` — 检测内核是否已安装
  - `getBinaryPath(KernelType)` — 获取内核二进制文件路径
  - `deleteKernel(KernelType)` — 删除已下载内核

### 3. ClashApiService (lib/services/clash_api_service.dart)

Clash API 服务，通过 WebSocket 和 RESTful API 与代理内核通信。

- **WebSocket 实时监听**:
  - `/traffic` — 实时上传/下载速度
  - `/logs` — 实时日志流（保留最近500条）
- **RESTful API**:
  - `getProxies()` — 获取所有代理节点列表
  - `switchProxy(group, name)` — 切换代理组中的选中节点
  - `setProxyMode(mode)` — 切换代理模式（rule/global/direct）
  - `fetchConnections()` — 获取当前活跃连接
  - `closeAllConnections()` — 关闭所有活跃连接
- **自动重连**: WebSocket 断开后3秒自动重连
- **数据模型**: `ClashProxy`（节点/代理组）、`ClashConnection`（活跃连接）、`ClashLogEntry`（日志条目）

### 4. SmartRouter (lib/services/smart_router.dart)

智能路由服务，基于历史连接数据对节点进行评分和自动选路。

- **评分算法**:
  - 稳定性分（0~40）：成功连接数 / 总连接数 × 40
  - 延迟分（0~20）：延迟越低分越高，max(0, 20 - avgLatency/50)
  - 速度分（0~30）：速度越快分越高，min(30, speed/MB × 3)
  - 总分 = 稳定性分 + 延迟分 + 速度分（0~90）
- **选路策略**: 历史评分权重 60% + 实时延迟评分权重 40%
- **关键方法**:
  - `recordConnect(node, success)` — 记录连接结果
  - `recordLatency(node, latencyMs)` — 记录延迟数据（指数移动平均 α=0.3）
  - `recordSpeed(node, bytesPerSec)` — 记录速度数据（指数移动平均 α=0.3）
  - `pickBest(nodes)` — 智能选择最优节点
  - `getRankedNodes(nodes)` — 获取节点排名列表
- **数据模型**: `NodeScore`（节点评分，含稳定性/延迟/速度/综合评分）

### 5. AdminService (lib/services/admin_service.dart)

管理员权限服务，静态工具类（私有构造函数）。

- **关键方法**:
  - `requestAdminPrivileges()` — 请求管理员权限（Windows UAC / macOS osascript）
  - `hasAdminPrivileges()` — 检测当前是否拥有管理员权限
- **平台实现**:
  - Windows：通过 `net session` 检测权限，不足时通过 PowerShell UAC 重新启动应用
  - macOS：通过 `osascript` 弹出系统授权对话框
  - Linux：默认返回 true（需用户自行 sudo）

### 6. SystemProxyService (lib/services/system_proxy_service.dart)

系统代理服务，静态工具类（私有构造函数），跨平台设置/移除系统代理。

- **关键方法**:
  - `enable(host, httpPort, socksPort)` — 启用系统代理
  - `disable()` — 禁用系统代理
- **平台实现**:
  - Windows：通过 `reg` 命令修改注册表 Internet Settings（ProxyEnable/ProxyServer/ProxyOverride）
  - macOS：通过 `networksetup` 命令配置网络服务代理（HTTP/HTTPS/SOCKS）
  - Linux：生成 `proxy_env.sh` 环境变量脚本

### 7. SingBoxConfig (lib/models/singbox_config.dart)

完整的 sing-box 配置数据模型，600+ 行，包含:

- `SingBoxConfig` — 根配置 (log/inbounds/outbounds/route/dns/experimental)
- `Inbound` — 入站 (mixed/socks/http 等)
- `Outbound` — 出站/协议 (vmess/vless/trojan/shadowsocks/hysteria2/tuic/wireguard/selector/urltest/direct/block)
- `TlsConfig` / `RealityConfig` — TLS 和 REALITY 配置
- `TransportConfig` — 传输层 (ws/grpc/http/quic)
- `RouteConfig` / `RuleConfig` — 路由规则
- `DnsConfig` / `DnsServer` / `DnsRule` — DNS 配置
- `TunConfig` / `ClashApiConfig` — TUN 和 Clash API

### 8. SubscriptionService (lib/services/subscription_service.dart)

订阅链接管理，支持解析多种协议链接:

- **链接格式**: `vmess://`、`vless://`、`trojan://`、`ss://`、`hysteria://`、`hysteria2://`、`tuic://`
- **订阅格式**: Base64 编码列表、JSON (sing-box/Clash 格式)
- **自动更新**: 支持 `setupAutoRefresh(minutes)` 定时刷新

### 9. ConfigAdapter (lib/utils/config_adapter.dart)

通用配置到三种内核格式的转换器:

- `adaptToSingBox(Map)` → sing-box JSON 格式
- `adaptToMihomo(Map)` → mihomo (Clash) YAML 格式
- `adaptToV2Ray(Map)` → v2ray (Xray) JSON 格式

### 10. GeoDataService (lib/services/geo_data_service.dart)

GeoIP/GeoSite 地理数据文件管理服务。

- **关键方法**:
  - `init()` — 检查本地地理数据文件版本
  - `updateAll()` — 从 GitHub 下载最新 geoip.db 和 geosite.db
  - `getGeoipPath()` / `getGeositePath()` — 获取数据文件路径
- **数据来源**: `SagerNet/sing-geoip` 和 `SagerNet/sing-geosite` 的 GitHub Releases

### 11. TrayService (lib/services/tray_service.dart)

系统托盘服务，管理通知栏图标和右键菜单。

- **关键方法**:
  - `init()` — 设置托盘图标、构建菜单、注册监听器
  - `update()` — 代理状态变化时更新菜单
  - `destroy()` — 销毁托盘服务
- **菜单功能**: 代理状态显示、代理模式切换（规则/全局/直连）、启停代理、显示主窗口、退出

### 12. WebDavSyncService (lib/services/webdav_sync_service.dart)

WebDAV 云同步服务，配置的云端备份与恢复。

- **关键方法**:
  - `configure(serverUrl, username, password, remotePath)` — 配置 WebDAV 连接参数
  - `testConnection()` — 测试 WebDAV 连接（PROPFIND / MKCOL）
  - `uploadConfig(configJson)` — 上传配置备份（带时间戳 + latest 双文件）
  - `downloadLatestConfig()` — 下载最新配置
- **认证**: HTTP Basic Auth

### 13. GlassTheme (lib/widgets/glass_theme.dart)

毛玻璃主题组件库，提供 Glassmorphism 风格的 UI 组件。

- **GlassTheme** — 主题配置（亮色/暗色，主色调 #6C5CE7 紫色，强调色 #00CEFF 青色）
- **GlassCard** — 毛玻璃卡片（BackdropFilter 模糊效果）
- **GlassButton** — 毛玻璃按钮（InkWell 水波纹点击效果）
- **GlassSwitch** — 毛玻璃开关（自定义动画）

### 14. SettingsScreen (lib/screens/settings_screen.dart)

应用设置页面，提供以下设置分组:

- **内核**: 内核管理入口
- **网络**: TUN 模式、系统代理、局域网共享
- **规则**: 广告屏蔽、智能节点
- **DNS**: DNS 模式/服务器/DoH/DoT/远程解析
- **订阅**: 自动刷新间隔
- **端口**: 监听地址、SOCKS 端口、HTTP 端口
- **数据**: 导出配置、导入配置、清除所有数据
- **外观**: 主题模式切换
- **关于**: 版本信息

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
5. **静态工具类**: `AdminService` 和 `SystemProxyService` 使用私有构造函数 + 静态方法模式
6. **资源释放**: 所有 `StreamController` 在 `dispose()` 中关闭，所有 `Timer` 在 `dispose()` 中取消
7. **依赖注入**: ProxyService 通过构造函数接收 `KernelManager` 和 `ConfigStorageService`，通过 setter 注入 `ClashApiService` 和 `SmartRouter`

## 扩展指南

### 添加新内核支持

1. 在 `lib/models/config.dart` 的 `KernelType` 枚举中添加新类型
2. 在 `KernelTypeExtension.name` 和 `fromName` 中添加映射
3. 在 `lib/services/kernel_manager.dart` 中实现下载逻辑 (GitHub 仓库 URL、下载 URL、文件名)
4. 在 `lib/services/proxy_service.dart` 的 `_buildKernelArgs` 方法中添加启动参数
5. 在 `lib/utils/config_adapter.dart` 中添加配置转换方法

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

- **内核启动**: `ProxyService.start()` 通过 `Process.start` 启动内核二进制，进程崩溃时自动重启（最多3次）
- **内核停止**: 先尝试 `Process.kill()`，5秒超时后强制 `SIGKILL`
- **ConfigStorageService**: 使用 `shared_preferences` 持久化存储
- **内核二进制**: 存放在应用支持目录下，首次使用需通过 KernelManager 下载
- **权限要求**: TUN 模式需要管理员/root 权限（通过 AdminService 请求），Android 需要 VPN 权限
- **系统代理**: Windows 通过注册表、macOS 通过 networksetup、Linux 通过环境变量脚本
- **配置不可变**: `SingBoxConfig` 及其子模型均为不可变对象，修改时需创建新实例 (通过构造函数重建)
