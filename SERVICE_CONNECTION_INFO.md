# 服务连接和 API 使用说明

## 服务连接概述

### 使用的包
- **router_os_client: ^2.0.0** - 用于连接 MikroTik RouterOS 的客户端库
- **provider: ^6.1.1** - 用于状态管理
- **shared_preferences: ^2.2.2** - 用于本地存储设置

### 服务架构

#### 1. MikroTikService (`lib/services/mikrotik_service.dart`)
- **连接方式**: 使用 `RouterOSClientV2` 类连接到 MikroTik RouterOS
- **API 通信**: 通过 `_client!.talk()` 方法调用 RouterOS API 命令
- **主要功能**:
  - 连接/断开连接
  - 获取客户端列表
  - 阻塞/解除阻塞客户端
  - 设置速度限制
  - 管理静态/动态租约
  - 社交网络过滤

#### 2. RouterOS API 命令示例
服务使用以下 RouterOS API 命令：

- **获取 DHCP 租约**: `/ip/dhcp-server/lease/print`
- **获取 ARP 表**: `/ip/arp/print`
- **获取无线客户端**: `/interface/wireless/registration-table/print`
- **获取热点用户**: `/ip/hotspot/active/print`
- **添加防火墙规则**: `/ip/firewall/raw/add`
- **删除防火墙规则**: `/ip/firewall/raw/remove`
- **设置 DHCP 阻塞**: `/ip/dhcp-server/lease/set`
- **无线访问列表**: `/interface/wireless/access-list/print`
- **队列管理**: `/queue/simple/print` 和 `/queue/simple/add`

#### 3. 阻塞操作流程

当执行阻塞操作时：

1. **调用链**:
   - `DeviceDetailScreen._banDeviceInternal()`
   - → `ClientsProvider.banClient()`
   - → `MikroTikService.banClientWithFingerprint()`
   - → `MikroTikService.banClient()`

2. **阻塞机制**:
   - 创建 Firewall Raw Prerouting 规则（基于 IP）
   - 创建 Firewall Raw Prerouting 规则（基于 MAC）
   - 设置 DHCP Block Access
   - 添加到 Wireless Access List（如果适用）
   - 保存 Device Fingerprint 用于自动识别

3. **成功后的行为**（已修改）:
   - 显示成功消息："دستگاه با موفقیت مسدود شد"
   - 关闭设备详情页面
   - 导航到主页面 (`/home`)

## 修改内容

### 修改文件: `lib/screens/device_detail_screen.dart`

**修改位置**: `_banDeviceInternal()` 方法

**修改内容**:
- 增强了成功消息的显示（添加图标和更好的样式）
- 添加了导航到主页面的逻辑
- 使用 `Navigator.pushNamedAndRemoveUntil` 确保导航到主页面

**修改后的行为**:
1. 阻塞成功后显示带有图标的成功消息
2. 关闭设备详情页面
3. 自动导航到主页面（`/home`）

## 技术细节

### RouterOSClientV2 连接参数
```dart
RouterOSClientV2(
  address: connection.host,      // 路由器 IP 地址
  user: connection.username,      // 用户名
  password: connection.password, // 密码
  useSsl: connection.useSsl,     // 是否使用 SSL
  port: connection.port,          // 端口号
)
```

### 阻塞操作的 RouterOS API 调用
1. **Firewall Raw Rule (IP)**:
   ```
   /ip/firewall/raw/add
   =chain=prerouting
   =src-address={ipAddress}
   =action=drop
   =comment={banComment} - IP
   ```

2. **Firewall Raw Rule (MAC)**:
   ```
   /ip/firewall/raw/add
   =chain=prerouting
   =src-mac-address={macAddress}
   =action=drop
   =comment={banComment} - MAC
   ```

3. **DHCP Block Access**:
   ```
   /ip/dhcp-server/lease/set
   =.id={leaseId}
   =block-access=yes
   ```

4. **Wireless Access List**:
   ```
   /interface/wireless/access-list/add
   =mac-address={macAddress}
   =action=reject
   =comment={banComment}
   ```

## 注意事项

1. **连接状态检查**: 所有操作前都会检查 `isConnected` 状态
2. **错误处理**: 每个 API 调用都有 try-catch 错误处理
3. **超时处理**: 某些操作设置了超时时间（如 5-45 秒）
4. **设备指纹**: 使用 Device Fingerprint 技术自动识别和阻塞相同设备
