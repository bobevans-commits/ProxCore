# ProxCore - 单元测试套件

> 最后更新: 2026-06-04 | 测试状态: 107 / 107 通过 ✅

## Flutter UI 层测试

### 运行 Flutter 测试

```bash
cd proxcore
flutter test            # 运行全部测试
flutter test --coverage # 运行并生成覆盖率报告
flutter analyze         # 静态分析
```

### 测试文件矩阵

| 文件 | 用例 | 覆盖范围 |
|------|------|----------|
| `test/widget_test.dart` | 53 | 基础模型 / 枚举 / 序列化 / AppUtils / ConfigAdapter |
| `test/smart_router_test.dart` | 18 | NodeScore 模型 / 评分算法 / EMA / 智能选路 / 持久化 |
| `test/singbox_adapter_test.dart` | 14 | 9 种协议 outbound / TUN / LAN 共享 / Clash API |
| `test/mihomo_v2ray_adapter_test.dart` | 16 | mihomo + v2ray 协议转换 / TLS / Reality / WS / gRPC |
| `test/dns_config_builder_test.dart` | 6 | DNS 配置跨 3 内核 / 4 种模式 |
| **合计** | **107** | **全部通过** ✅ |

### 详细覆盖项

#### 1. 模型层 (`widget_test.dart`)

**KernelType 枚举**
- `KernelType.fromName` 返回正确类型
- `KernelType.fromName` 未知名返回 singbox
- `KernelType.label` 正确

**KernelStatus 状态**
- `KernelStatus.description` 非空

**ProxyProtocol 协议**
- `ProxyProtocol.fromString` 返回正确协议
- `ProxyProtocol.fromString` 大小写不敏感
- `ProxyProtocol.fromString` 未知返回 vmess
- `ProxyProtocol.label` 正确

**NodeConfig**
- `toJson` / `fromJson` 往返
- `fromJsonString` 工作正常
- `copyWith` 正常

**ProxyConfig**
- 默认值检查
- `toJson` / `fromJson` 往返

**RoutingRule**
- `toJson` / `fromJson` 往返
- `typeOptions` / `targetOptions` 非空

**SingboxConfig**
- `defaultConfig` 包含入站和出站
- `defaultConfig` 使用自定义端口
- `toJson` 生成有效 JSON 字符串
- `fromJson` 重建配置

**AppUtils**
- `formatBytes` 格式化正确
- `formatDuration` 格式化正确
- `formatTimestamp` 格式化正确
- `isValidPort` 校验正确
- `isValidAddress` 校验正确
- `isValidUrl` 校验正确
- `protocolIcon` 返回非空字符串
- `latencyLabel` 格式化正确
- `detectProtocol` 返回正确类型
- `parseProxyLink` 未知协议抛出异常

**ConfigAdapter**
- `toSingboxConfig` 生成有效 sing-box 配置
- `toSingboxConfig` 节点为 null 时使用 direct
- `toMihomoConfig` 生成有效 mihomo 配置
- `toV2rayConfig` 生成有效 v2ray 配置
- `toSingboxConfig` 包含路由规则
- `deepMerge` 空 Map 合并
- `deepMerge` 简单 key 覆盖
- `deepMerge` 嵌套 Map 递归合并
- `deepMerge` List/基本类型直接替换
- `deepMerge` 不修改原 Map
- `deepMerge` 非字符串 key 转换

#### 2. 智能路由 (`smart_router_test.dart`)

**NodeScore 模型**
- `stability`: 无连接时为 0
- `stability`: 10 成功 0 失败时为 1.0
- `stability`: 5 成功 5 失败时为 0.5
- `copyWith` 只更新指定字段
- `toJson` / `fromJson` 往返

**SmartRouter 评分算法**
- 首次成功连接：初始分 50.0
- 首次失败连接：初始分 0.0
- `recordLatency` 使用指数移动平均 (α=0.3)
- `recordSpeed` 使用指数移动平均 (α=0.3)
- 连击稳定性：连续成功累积分数

**SmartRouter.pickBest**
- 空列表返回 null
- 单节点返回该节点
- 优先选择实时延迟低的节点
- 历史评分影响选路

**SmartRouter.getRankedNodes**
- 按评分降序排序

**SmartRouter 持久化**
- `toJson` + `loadFromJson` 往返
- `loadFromJson` 空数据安全处理
- `loadFromJson` 缺少 scores 字段安全处理

#### 3. sing-box 适配器 (`singbox_adapter_test.dart`)

**节点转换（9 种协议）**
- VMess
- VLESS
- Trojan
- Shadowsocks
- Hysteria
- Hysteria2
- TUIC
- Naive
- WireGuard

**节点组合配置**
- VLESS + Reality
- VLESS + Reality + WebSocket
- VMess + TLS + WebSocket

**完整配置**
- TUN 开启时追加 tun 入站
- 有活跃节点时包含 auto (urltest) 出站
- 无活跃节点时 finalOutbound 指向 direct
- 广告屏蔽开启时插入 ads rule
- `lanSharing=true` 时 listenAddress 为 0.0.0.0
- `lanSharing=false` 时 listenAddress 为 127.0.0.1
- 包含 Clash API 实验性配置

#### 4. mihomo + v2ray 适配器 (`mihomo_v2ray_adapter_test.dart`)

**mihomo 节点→proxy**
- VMess
- VLESS
- VLESS + Reality
- Trojan
- Shadowsocks
- Hysteria2

**v2ray 节点→outbound**
- VMess
- VLESS
- VLESS + Reality
- Trojan
- Shadowsocks
- 节点带 wsPath

**完整配置**
- mihomo TUN 开启
- mihomo rules
- v2ray TUN 开启

#### 5. DNS 配置构建器 (`dns_config_builder_test.dart`)

- sing-box system 模式
- sing-box custom 模式（remote + fallback）
- mihomo system 模式
- mihomo nameserver 模式
- v2ray system 模式
- v2ray 自定义 DNS servers

## 持续集成 (CI)

### GitHub Actions (`.github/workflows/ci.yml`)

```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test
      - run: flutter analyze
```

## 测试覆盖率

```bash
flutter test --coverage
# 覆盖率文件: coverage/lcov.info
genhtml coverage/lcov.info -o coverage/html
```

## 手动测试清单

### 功能测试
- [ ] 启动/停止 sing-box 内核
- [ ] 启动/停止 mihomo 内核
- [ ] 启动/停止 v2ray 内核
- [ ] 内核热切换
- [ ] 配置文件导入 (JSON/YAML)
- [ ] 系统代理启用/禁用
- [ ] 节点延迟测试
- [ ] 流量统计显示
- [ ] 智能选路
- [ ] 订阅自动刷新
- [ ] WebDAV 云端同步

### 平台兼容性测试
- [ ] Windows 10/11
- [ ] macOS Intel/Apple Silicon
- [ ] Linux (Ubuntu/Fedora/Arch)
- [ ] Android 10+

### 性能测试
- [ ] 内存占用 < 100MB
- [ ] CPU 占用 < 5% (空闲时)
- [ ] 启动时间 < 3 秒
- [ ] 内核切换时间 < 2 秒
