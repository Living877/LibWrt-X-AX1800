# AX1800 可编译插件清单（LibWrt 25.12-nss 底座）

✓ = 旧固件（kwrt-ax1800 build-49）里有的，迁移过来基本零风险
✗ = 这套源里**没有**，要额外加 feed 才能编
⚠️ = 能编，但有已知代价（内存/冲突/定制丢失），装之前先看备注

包名都是 `CONFIG_PACKAGE_<包名>=y`；LuCI 应用的中文界面另配 `luci-i18n-<应用>-zh-cn`。

---

## 1. 代理 / 分流

| 包 | 干什么用的 | 备注 |
|---|---|---|
| `luci-app-openclash` | Clash/Meta 内核代理，订阅管理、规则分流、TUN/TPROXY 接管 | ✓ 依赖重：`dnsmasq-full`、`ruby`+`ruby-yaml`、`kmod-tun`、`kmod-nft-tproxy`；ruby 会拖一份 host 工具链 |
| `luci-app-homeproxy` | sing-box 内核代理，配置比 Clash 简洁，immortalwrt 主推 | 比 openclash 省内存；和 openclash **不要同时启用** |
| `luci-app-passwall` | 多协议聚合（xray / sing-box / haproxy），功能最全 | 配置复杂，体积大 |
| `luci-app-v2raya` | v2rayA 的 Web 前端，管 v2ray/xray 节点 | 与 openclash 二选一 |
| `luci-app-dae` | dae 的 LuCI 界面（eBPF 透明代理） | 需要内核 BTF/XDP，**只有 12M 分区装得下**；dae 本体要另装 |
| `daed` + `luci-app-daed` | daed 守护进程 + 面板（dae 的可视化调度） | 同上，吃内存 |
| `luci-app-store` | iStore 第三方应用商店，一键装插件 | ✗ 要加 kiddin9 feed；依赖 `luci-lib-taskd`、`taskd`、`curl`、`tar` |
| `luci-app-filebrowser-go` | Go 版网页文件管理器（替代 quickfile） | 轻量，无 rust 依赖 |
| `luci-app-alist` / `openlist` | 网盘聚合（阿里云盘、OneDrive…）挂载成本地目录 | 占内存，1G 机器谨慎 |

## 2. 网络

| 包 | 干什么用的 | 备注 |
|---|---|---|
| `luci-app-ddns` | DDNS 框架，配服务商脚本用 | ✓ 还要选 `ddns-scripts-aliyun` / `-cloudflare` / `-dnspod-v3` |
| `luci-app-ddns-go` | jeessy/ddns-go，多服务商 DDNS 守护 | 比 ddns-scripts 省心 |
| `luci-app-upnp` | UPnP / NAT-PMP 自动端口映射（miniupnpd） | ✓ BT/游戏用 |
| `luci-app-sqm` + `sqm-scripts-nss` | 智能队列（cake），治缓冲膨胀、压延迟 | ✓ 走 NSS 硬件加速；开代理时要关 flow offloading |
| `luci-app-usteer` | 802.11k/v 漫游引导，双频合一真正“会挑频段” | 解决智能插座赖在 2.4G 的问题 |
| `luci-app-mwan3` | 多 WAN 负载均衡与故障切换 | 单线不用 |
| `luci-app-pbr` | 策略路由：按域名/IP 指定出口 | 与代理类冲突要留意 |
| `luci-app-wol` | 网络唤醒（WOL） | ✓ |
| `luci-app-wifihistory` | 无线连接历史与信号记录 | ✓ |
| `luci-app-wifischedule` | 定时开关 WiFi | 省电/夜间关网 |
| `luci-app-adblock-fast` | DNS 层广告过滤（基于 dnsmasq 列表） | 轻量，推荐 |
| `luci-app-adguardhome` | AdGuard Home：独立 DNS 服务器 + 过滤 + 统计 | 占 50–100 MB 内存 |
| `luci-app-smartdns` | DNS 分流/缓存（国内直连、国外走代理） | 配 openclash 常见组合 |
| `luci-app-https-dns-proxy` | DoH 转发（Cloudflare/Google） | 与 adblock 可叠加 |
| `luci-app-nlbwmon` | 按 IP 统计流量 | 低开销 |
| `luci-app-vnstat2` | 接口流量统计与图表 | 低开销 |
| `luci-app-netdata` | 实时系统监控面板 | 占内存，可临时装 |
| `luci-app-msd_lite` | 组播转 HTTP（IPTV 单播化） | 家里有 IPTV 才要 |
| `luci-app-udpxy` | 同上，老牌 UDP 组播转单播 | 与 msd_lite 二选一 |
| `luci-app-travelmate` | 酒店/校园 WiFi 自动登录 | 出差用 |
| `luci-app-banip` / `crowdsec` | 入侵检测与自动封禁 | 规则库占空间 |
| `luci-app-acme` | Let's Encrypt 证书自动续期 | 要开 80/443 或 DNS 验证 |

## 3. 存储 / 文件共享 / 下载

| 包 | 干什么用的 | 备注 |
|---|---|---|
| `luci-app-samba4` | SMB/CIFS 共享（用户态全功能） | ✓ 依赖 samba4 全套，约 20 MB |
| `ksmbd-server` + `luci-app-ksmbd` | 内核态 SMB 服务，更快更省内存 | 只支持 SMB3，老设备兼容性略差 |
| `luci-app-diskman` | 磁盘分区、格式化、挂载管理 | ✓ |
| `luci-app-qbittorrent` | qBittorrent 下载器 | 占内存，需 `luci-app-filebrowser` 类管理 |
| `luci-app-transmission` | Transmission 下载器 | 比 qB 轻 |
| `luci-app-aria2` | Aria2 多线程下载 | 轻量 |
| `luci-app-rclone` | 云盘同步/挂载（OneDrive、Google Drive…） | 配置在命令行 |
| `luci-app-syncthing` | P2P 文件同步 | 占内存 |
| `luci-app-minidlna` | DLNA 媒体服务器，电视可直接播 | 需扫描媒体库 |
| `hd-idle` / `luci-app-hd-idle` | 硬盘空闲休眠 | 移动硬盘用户推荐 |
| `smartmontools` | 硬盘 SMART 健康检查 | ✓ |
| `luci-app-nfs` | NFS 服务端 | 内网 Linux 共享 |
| `kmod-usb-storage` / `-extras` / `-uas`、`kmod-fs-{ext4,vfat,exfat,ntfs3,f2fs,btrfs}`、`kmod-nls-*` | USB 与文件系统驱动 | ✓ **不选这些插 U 盘毫无反应**，必须带 |

## 4. 远程 / VPN / 组网

| 包 | 干什么用的 | 备注 |
|---|---|---|
| `luci-proto-wireguard` + `wireguard-tools` + `kmod-wireguard` | WireGuard VPN | ✓ 常用回家/异地组网 |
| `luci-app-openvpn` | OpenVPN 客户端/服务端 | 兼容性最好，速度一般 |
| `luci-app-tailscale-community` | Tailscale 组网 | 依赖 tailscaled，约 30 MB |
| `luci-app-zerotier` | ZeroTier 组网 | 轻量 |
| `luci-app-frpc` / `frps` | 内网穿透（frp 客户端/服务端） | 公网服务器配合 |
| `luci-app-cloudflared` | Cloudflare Tunnel 穿透 | 需要有域名托管在 CF |
| `luci-app-nps` / `luci-app-ngrokc` | 其它穿透方案 | 按需 |
| `luci-app-sshtunnel` | SSH 隧道 | 轻量 |

## 5. 系统 / 运维

| 包 | 干什么用的 | 备注 |
|---|---|---|
| `luci-app-ttyd` | 网页终端 | ✓ |
| `luci-app-commands` | 自定义命令按钮（重启服务、备份…） | ✓ |
| `luci-app-cpufreq` | CPU 调频策略 | ✓ |
| `luci-app-irqbalance` | 中断均衡到多核 | NSS 机器提升有限 |
| `luci-app-statistics` | collectd 性能图表（CPU/网络/温度） | 需选 `collectd-mod-*`，占空间 |
| `luci-app-watchcat` | 看门狗，断网自动重启网络 | 别与 autoreboot 叠加 |
| `luci-app-autoreboot` | 定时重启 | 简单 |
| `luci-app-advanced-reboot` | 重启到另一分区（A/B 双系统） | 本机 U-Boot 支持双槽，但没必要 |
| `luci-app-sysctl` / `syscontrol` | 内核参数 / 系统控制面板 | ✗ 来自 kiddin9 |
| `luci-app-timedreboot` | 定时重启（轻量版） | ✗ 来自 kiddin9 |
| `luci-app-package-manager` | 官方“软件包”页 | 用 iStore 时可选保留作后备 |
| `luci-app-dockerman` | Docker 管理 | ⚠️ 1 GiB 运存跑不动，不建议 |
| `luci-app-ramfree` | 手动释放内存 | 噱头居多 |
| `luci-app-eqos` | 简易限速 | 与 sqm 二选一 |
| `luci-app-unblockneteasemusic` | 解锁网易云灰色歌曲 | 小众 |
| `luci-app-wechatpush` | 微信推送（上线/掉线通知） | 需第三方服务 |
| `luci-app-usb-printer` / `p910nd` | USB 打印机共享 | 按需 |
| `luci-app-nut` | UPS 断电保护 | 按需 |
| `luci-app-snmpd` | SNMP 监控 | 企业环境 |
| `luci-app-splash` | 访客认证门户 | 按需 |
| `luci-app-modemband` / `sms-tool-js` | 4G/5G 模块频段与短信 | 本机无蜂窝模块，用不上 |
| **`luci-app-attendedsysupgrade` / `owut`** | 在线升级 | ⚠️ **别装**：ASU 用官方 ImageBuilder 重建，源码级定制全丢，且缺 NSS 内核模块会直接失败 |

## 6. 中文语言包

每个选中的应用配 `luci-i18n-<应用>-zh-cn`；主体界面至少要有：

```
luci-i18n-base-zh-cn      luci-i18n-firewall-zh-cn
luci-i18n-opkg-zh-cn      luci-i18n-commands-zh-cn
```

旧固件实测 20 个中文包。注意 `luci-i18n-*` 是 HIDDEN 符号，直接往 `.config` 里写 `=y` 会被静默丢掉，
要么用 menuconfig 勾，要么按“先摘 HIDDEN 再强选”的方式处理。

## 7. 与旧固件的差异（迁移时注意）

| 旧固件有、这套源没有 | 处理 |
|---|---|
| `luci-app-store`（iStore） | 加 kiddin9 feed，见 README |
| `luci-app-fan` / `oui` / `partexp` / `syscontrol` / `sysctl` / `timedreboot` / `wizard` | 都在 kiddin9/op-packages，按需加 |
| `autocore` | kiddin9 的 CPU 核心数自适应；LibWrt 可不用 |
| `my-default-settings` | kiddin9 的首启脚本；本仓库用 `uci-defaults` 自己写，别整包搬（会和 `default-settings` 抢路径） |

| 这套源有、旧固件没有 | 说明 |
|---|---|
| `luci-app-openclash` 之外的代理方案（homeproxy / passwall / v2raya） | immortalwrt 主源自带 |
| `luci-app-dae` + `daed` | 需要 12M + BTF，见 README |
| `luci-app-usteer` | 双频合一体验明显更好 |
