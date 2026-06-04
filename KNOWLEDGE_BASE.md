# ProxCore 知识库索引

> 生成时间: 2026-06-04 | 版本: 1.2.0

## 项目元信息

- **类型**: Flutter 多平台代理客户端
- **内核**: sing-box / mihomo / v2ray
- **平台**: Windows / macOS / Linux / Android
- **状态管理**: Provider + ChangeNotifier
- **Dart SDK**: >=3.0.0 <4.0.0
- **Flutter SDK**: >=3.24.0

## 文件索引

### 入口
| 文件 | 职责 |
|------|------|
| `lib/main.dart` | 应用入口, MultiProvider(7个服务), MaterialApp, 主导航(4页), 节点列表(排序/筛选/分组) |

### 模型层 (models/)
| 文件 | 核心类 | 说明 |
|------|--------|------|
| `config.dart` | KernelType, KernelStatus, ProxyProtocol, NodeConfig, ProxyConfig, RoutingRule, DnsConfig, DnsMode | 全局配置模型 |
| `kernel_info.dart` | KernelInfo, KernelReleaseInfo, KernelAssetInfo | 内核信息模型 |
| `singbox_config.dart` | SingboxConfig, SingboxInbound, SingboxOutbound, SingboxRoute, SingboxRouteRule | sing-box JSON 配置 |

### 服务层 (services/)
| 文件 | 核心类 | 模式 | 说明 |
|------|--------|------|------|
| `proxy_service.dart` | ProxyService, ProxyState | ChangeNotifier | 中央状态管理, 代理启停(Process.start), 崩溃自启, 节点/规则/流量 |
| `kernel_manager.dart` | KernelManager | ChangeNotifier | 内核下载/安装/版本检测/GitHub API |
| `clash_api_service.dart` | ClashApiService | ChangeNotifier | WebSocket 流量/日志/节点, RESTful API |
| `config_storage_service.dart` | ConfigStorageService, SubscriptionInfo | — | SharedPreferences 持久化, 导入导出 |
| `subscription_service.dart` | SubscriptionService | ChangeNotifier | 订阅 CRUD/刷新/解析 (调用 AppUtils) |
| `smart_router.dart` | SmartRouter, NodeScore | ChangeNotifier | 智能节点评分/自动选路 |
| `system_proxy_service.dart` | SystemProxyService | 静态工具类 | Windows 注册表/macOS networksetup |
| `admin_service.dart` | AdminService | 静态工具类 | 管理员权限检测/UAC提权 |
| `geo_data_service.dart` | GeoDataService | ChangeNotifier | GeoSite/GeoIP 下载管理 |
| `tray_service.dart` | TrayService | TrayListener | 系统托盘图标/菜单 |
| `webdav_sync_service.dart` | WebDavSyncService | ChangeNotifier | WebDAV 云端备份/恢复 |

### 工具层 (utils/)
| 文件 | 核心方法 | 说明 |
|------|----------|------|
| `app_utils.dart` | formatBytes, formatDuration, latencyLabel, detectProtocol, parseProxyLink, getArchName | 通用工具 + 统一链接解析 |
| `config_adapter.dart` | toSingboxConfig, toMihomoConfig, toV2rayConfig | 多内核配置适配 |

### UI 层 (screens/)
| 文件 | 页面 | 说明 |
|------|------|------|
| `home_screen.dart` | HomeScreen | 仪表板: 状态/网速/概要/快捷设置/内核安装 |
| `kernel_settings_screen.dart` | KernelSettingsScreen | 内核管理: 版本/下载/安装 |
| `log_screen.dart` | LogScreen | 日志查看: 级别过滤/实时流 |
| `node_editor_screen.dart` | NodeEditorScreen | 节点编辑: 9种协议表单 |
| `routing_editor_screen.dart` | RoutingEditorScreen | 路由编辑: 9种匹配/14预设/拖拽 |
| `settings_screen.dart` | SettingsScreen | 设置: 内核/网络/规则/DNS/端口/数据/外观 |
| `subscriptions_screen.dart` | SubscriptionsScreen | 订阅管理: CRUD/刷新/概要 |

### 组件层 (widgets/)
| 文件 | 组件 | 说明 |
|------|------|------|
| `glass_theme.dart` | GlassTheme, GlassCard, GlassButton, GlassSwitch | 毛玻璃主题 |
| `proxy_link_importer.dart` | ProxyLinkImporter | 链接导入弹窗 (调用 AppUtils) |

## 关键依赖关系

```
ProxyService (中央状态)
├── KernelManager (内核管理)
├── ConfigStorageService (持久化)
├── ClashApiService (WebSocket通信)
├── SmartRouter (智能选路)
├── SystemProxyService (系统代理)
├── ConfigAdapter (配置适配)
└── AppUtils (链接解析)

UI层 → context.watch/read<ProxyService>()
UI层 → context.watch/read<KernelManager>()
UI层 → context.watch/read<SubscriptionService>()
```

## 协议支持矩阵

| 协议 | sing-box | mihomo | v2ray | 链接解析 |
|------|----------|--------|-------|----------|
| VMess | ✅ | ✅ | ✅ | vmess:// |
| VLESS | ✅ | ✅ | ❌ | vless:// |
| Trojan | ✅ | ✅ | ✅ | trojan:// |
| Shadowsocks | ✅ | ✅ | ✅ | ss:// |
| Hysteria | ✅ | ✅ | ❌ | hysteria:// |
| Hysteria2 | ✅ | ✅ | ❌ | hysteria2:// / hy2:// |
| TUIC | ✅ | ✅ | ❌ | tuic:// |
| Naive | ✅ | ❌ | ❌ | — |
| WireGuard | ✅ | ❌ | ❌ | — |

## 优化记录

### 第一轮 (2026-05-06)
| 优化项 | 文件 | 说明 |
|--------|------|------|
| 修复冗余条件 | `app_utils.dart` | latencyLabel() 5个相同分支→2个 |
| 修复硬编码 | `app_utils.dart` | getArchName() 硬编码amd64→多级检测 |
| 修复资源泄漏 | `kernel_manager.dart` | HttpClient 3处未关闭→finally关闭 |
| 修复异步清理 | `proxy_service.dart` | dispose()异步方法→fire-and-forget+临时目录清理 |
| 修复订阅泄漏 | `clash_api_service.dart` | 日志WebSocket订阅未跟踪→跟踪+disconnect清理 |
| 消除重复代码 | `app_utils.dart` + `subscription_service.dart` + `proxy_link_importer.dart` | 链接解析3处重复→统一到AppUtils |
| 补充注释 | 全部核心文件 | 中文文档注释覆盖所有类/方法/字段 |
| 更新文档 | `README.md` | 项目结构/服务列表/开发指南同步更新 |
| 新增测试 | `widget_test.dart` | latencyLabel/detectProtocol/parseProxyLink 测试 |

### 第二轮 (2026-05-06)
| 优化项 | 文件 | 说明 |
|--------|------|------|
| 更新 AGENTS.md | `AGENTS.md` | 删除11个不存在文件引用, 新增9个实际文件, 修正架构描述 |
| 更新 CODE_WIKI.md | `CODE_WIKI.md` | 完全重写, 反映实际项目结构 |
| 修复绕过列表 | `system_proxy_service.dart` | ProxyOverride 添加 `<local>` 简化 |
| 修复密码安全 | `webdav_sync_service.dart` | toJson()密码Base64编码, loadFromJson()兼容旧版明文 |
| 修复竞态条件 | `config_storage_service.dart` | initSync()添加错误处理和使用说明 |

### 第三轮 (2026-05-06)
| 优化项 | 文件 | 说明 |
|--------|------|------|
| 消除重复代码 | `kernel_manager.dart` | _getCurrentArch/_getCurrentPlatform 委托给 AppUtils |
| 新增方法 | `app_utils.dart` | 添加 getPlatformName() 统一平台检测 |
| 修复资源泄漏 | `proxy_service.dart` | testDownloadSpeed HttpClient 未在 finally 关闭 |
| 修复竞态条件 | `proxy_service.dart` | start() exitCode.timeout onTimeout:()=>-1 不正确→try/catch TimeoutException |
| 补充协议支持 | `config_adapter.dart` | mihomo 添加 Hysteria/TUIC 协议映射，不再降级为 socks5 |
| 修复临时文件 | `kernel_manager.dart` | downloadKernel 下载失败后清理 _download 临时文件 |

### 第四轮 (2026-05-06) — 链路功能完善
| 优化项 | 文件 | 说明 |
|--------|------|------|
| 订阅解析增强 | `subscription_service.dart` | 支持 Base64 整体编码 + Clash YAML 格式订阅 |
| VLESS 链接解析 | `app_utils.dart` | 补充 Reality(pbk/sid)/TLS/WS/gRPC 字段 |
| VMess 链接解析 | `app_utils.dart` | 补充 TLS/sni/alpn/fingerprint 字段 |
| Trojan 链接解析 | `app_utils.dart` | 补充 TLS/alpn/fingerprint/WS/gRPC 字段 |
| SS 链接解析 | `app_utils.dart` | 支持 SIP002 格式 + SS2022 兼容 |
| sing-box VMess | `config_adapter.dart` | 补充 TLS/WS/gRPC/HTTP 传输层配置 |
| sing-box VLESS | `config_adapter.dart` | 修复 Reality 字段名 + 补充 WS/gRPC 传输层 |
| sing-box Trojan | `config_adapter.dart` | 补充 TLS alpn/fingerprint + WS/gRPC 传输层 |
| mihomo VMess | `config_adapter.dart` | 补充 TLS + ws-opts/grpc-opts 传输层 |
| mihomo VLESS | `config_adapter.dart` | 补充 Reality-opts + TLS + ws-opts/grpc-opts |
| mihomo Trojan | `config_adapter.dart` | 补充 ws-opts/grpc-opts 传输层 |
| v2ray VMess | `config_adapter.dart` | 补充 streamSettings TLS/WS/gRPC |
| v2ray VLESS | `config_adapter.dart` | 补充 Reality/TLS/WS/gRPC streamSettings |
| v2ray Trojan | `config_adapter.dart` | 补充 streamSettings TLS/WS/gRPC |

### 第五轮 (2026-05-06) — TUN 权限 + CI/CD 发布
| 优化项 | 文件 | 说明 |
|--------|------|------|
| TUN 权限检查 | `proxy_service.dart` | toggleTun() 开启前先检查管理员权限，拒绝提权返回 false |
| CI/CD 发布 | `.github/workflows/release.yml` | main 分支 push 自动构建4平台+创建 GitHub Release |

### 第六轮 (2026-05-12) — 编译错误修复 + 代码审查
| 优化项 | 文件 | 说明 |
|--------|------|------|
| 修复重复声明 | `app_utils.dart` | getPlatformName() 重复声明→重命名为 getPlatformDisplayName() |
| 修复缺失导入 | `proxy_service.dart` | 添加 admin_service.dart 导入 |
| 修复闭包参数 | `subscription_service.dart` | `_` 闭包参数引用→改为 `line` |
| 移除无用导入 | `proxy_service.dart` | 移除未使用的 app_utils.dart 导入 |
| 修复日志重连 | `clash_api_service.dart` | 日志流 WebSocket 断线后自动重连(与流量流一致) |
| 修复变量遮蔽 | `settings_screen.dart` | 移除重复的 kernelType 变量声明 |
| 提取公共组件 | `widgets/kernel_install_screen.dart` | _KernelInstallScreen + _SettingsKernelInstallScreen → KernelInstallScreen |
| 删除冗余方法 | `kernel_info.dart` | 移除未使用的 getPlatform()/getArch()，统一使用 AppUtils |
| 移除无用导入 | `kernel_info.dart` | 移除不再需要的 dart:io |
| 移除无用导入 | `home_screen.dart` | 移除 kernel_manager.dart 导入(已由公共组件处理) |
| 移除无用导入 | `settings_screen.dart` | 移除 kernel_manager.dart 导入(已由公共组件处理) |

### 第七轮 (2026-05-12) — P1 任务执行
| 优化项 | 文件 | 说明 |
|--------|------|------|
| 提取节点列表弹窗 | `widgets/node_list_sheet.dart` (新建) | main.dart 中 _NodeListSheet (489行) 提取为公开 NodeListSheet 公共组件 |
| 提取 TUN 切换工具 | `utils/tun_helper.dart` (新建) | 消除 _QuickSettings._onTunToggle() 与 _SettingsNetworkSection._onTunToggle() 重复 (~120行) |
| 精简 main.dart | `main.dart` | 985行 → 482行 (-503行, -51%) |
| 清理未用导入 | `main.dart` | 移除 models/config.dart / utils/app_utils.dart (随 _NodeListSheet 提取后不再使用) |
| 清理未用导入 | `override_settings_screen.dart` | 移除未引用的 ../models/config.dart |
| 文档版本同步 | `README.md` | 改为引用 pubspec.yaml 中的 environment.sdk 约束 |

### 第八轮 (2026-05-12) — P1 拆分 config_adapter
| 优化项 | 文件 | 说明 |
|--------|------|------|
| 拆分配置适配器 | `utils/config_adapter.dart` (875→91行) | 重构为统一入口(向后兼容 ConfigAdapter API) |
| DNS 配置构建器 | `utils/adapters/dns_config_builder.dart` (新建,122行) | 跨内核共享 DNS 配置(singbox/mihomo/v2ray) |
| sing-box 适配器 | `utils/adapters/singbox_adapter.dart` (新建,406行) | 9 种协议的 sing-box 出站 + 入站/路由/实验性配置 |
| mihomo 适配器 | `utils/adapters/mihomo_adapter.dart` (新建,281行) | 7 种协议的 mihomo proxies + rules + TUN |
| v2ray 适配器 | `utils/adapters/v2ray_adapter.dart` (新建,358行) | 4 种协议的 v2ray JSON + routing + TUN |

### 第九轮 (2026-06-04) — 测试覆盖提升
| 优化项 | 文件 | 说明 |
|--------|------|------|
| 修复测试断言 | `test/singbox_adapter_test.dart` | `SingboxInbound.toJson` 使用 `listen` 键 (非 `listen_address`)，修正断言 + 新增 lanSharing=false 场景 |
| 修复 EMA 期望值 | `test/smart_router_test.dart` | 持久化测试中首次 `recordConnect` 后 avgLatencyMs 默认为 0，EMA 计算 0*0.7+50*0.3=15.0（修正预期值）+ 新增空数据/缺字段容错测试 |
| 单元测试套件 | 全量 | 107 个测试全部通过：`flutter analyze` 0 issues |

## 测试矩阵（当前覆盖）

| 测试文件 | 用例数 | 覆盖范围 |
|----------|--------|----------|
| `widget_test.dart` | 53 | KernelType/ProxyProtocol/KernelStatus/NodeConfig/ProxyConfig/RoutingRule/SingboxConfig/AppUtils/ConfigAdapter 序列化+转换+deepMerge |
| `smart_router_test.dart` | 18 | NodeScore 模型+稳定性/EMA/pickBest/getRankedNodes/持久化往返+容错 |
| `singbox_adapter_test.dart` | 14 | 9 种协议 outbound + TUN/广告屏蔽/LAN共享/Clash API/路由规则 |
| `mihomo_v2ray_adapter_test.dart` | 16 | 节点→proxy/streamSettings 转换+TLS/Reality/WS/gRPC |
| `dns_config_builder_test.dart` | 6 | system/custom/DoH/DoT 四种模式跨 3 内核 |
| **合计** | **107** | 全部通过 ✅ |
