# LibWrt X AX1800

京东云亚瑟 AX1800 Pro（IPQ6000 / `ipq6018-jdcloud_re-ss-01`）的自编固件。
底座是 [LiBwrt/LibWrt](https://github.com/LiBwrt/LibWrt) `25.12-nss`（apk 包管理），本仓库是它的 fork，
所有定制都放在 `ax1800/` 下，不动上游源码。

---

## 文件

| 路径 | 内容 |
|---|---|
| `ax1800/device-partitions.md` | **设备与分区事实底稿**：eMMC 28 项分区、设备号换算、6M/12M 边界、GPT 修复、`p27` 数据盘、刷机顺序、备份 MD5 与恢复 |
| `ax1800/plugin-catalog.md` | 可编译插件清单：用途、依赖、注意事项 |
| `ax1800/config/device.config` | 机型、版本串、中文默认设置、主题 |
| `ax1800/config/packages.config` | 选中的软件包（代理/网络/存储/远程/工具/中文） |
| `ax1800/config/packages-store.config` | iStore（`luci-app-store`）及其依赖 |
| `ax1800/config/kernel-dae.config` | dae 需要的内核能力（**只开内核，dae 本体以后单独装**） |
| `ax1800/config/repos.config` | 运行时 apk 源与 feed 开关 |
| `ax1800/files/etc/uci-defaults/99-ax1800` | 首启配置：IPv6、NAT1、双频合一 WiFi、时区、主题 |
| `ax1800/scripts/set-kernel-size.sh` | 内核分区 6144k → 12288k（12M 表必须） |
| `.github/workflows/build.yml` | GitHub Actions 构建流程 |

---

## 这台机器

| 项 | 值 |
|---|---|
| 机型 | 京东云亚瑟 AX1800 Pro，`ipq6018-jdcloud_re-ss-01` |
| SoC | IPQ6000（qualcommax / ipq60xx），ath11k + NSS 硬件加速 |
| 运存 | **1 GiB（硬改）**，`free` 显示 ~878 MiB 正常（Q6 保留区 85 MiB） |
| eMMC | 30,212,096 扇区 = 14.41 GiB，扇区 512 B |
| 分区表 | GPT，**12M 布局**：`0:HLOS` 12 MiB、rootfs 2 GiB、`p27` 数据盘 11.42 GiB |
| U-Boot | chenxin527 版；网页只有 `/firmware.html`、`/ptable.html`、`/backup.html` 等 |

分区与刷机细节见 [ax1800/device-partitions.md](ax1800/device-partitions.md)。

---

## 构建

### GitHub Actions（推荐）

Actions → **Build AX1800 12M** → Run workflow：

| 参数 | 默认 | 说明 |
|---|---|---|
| `kernel_size` | `12288` | 12M 表选 12288，原厂 6M 选 6144 |
| `upload_release` | 勾 | 编译成功后自动发 Release |

流程要点：腾磁盘 → 装依赖 → feeds（上游 + 官方 iStore 四件套）
→ 用 jerrykuku 的 **argon 3.x** 替换 feed 里的 2.4.7 → 合并配置片段 → `set-kernel-size.sh`
→ `make defconfig` → `make download`（清掉 `dl/` 里 <1KB 的残骸）
→ `make -j || make -j1 || make -j1 V=s` → 校验 FIT 体积与 `hsqs` 边界 → 出 artifact / Release。

### 本地

```sh
git clone --depth 1 -b 25.12-nss https://github.com/Living877/LibWrt-X-AX1800.git
cd LibWrt-X-AX1800

cp feeds.conf.default feeds.conf
./scripts/feeds update -a && ./scripts/feeds install -a
echo 'src-git istore https://github.com/linkease/istore.git' >> feeds.conf
./scripts/feeds update -p istore
./scripts/feeds install -p istore luci-app-store luci-lib-taskd taskd luci-lib-xterm

./scripts/feeds uninstall luci-theme-argon luci-app-argon-config || true
rm -rf package/luci-theme-argon && \
  git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon

cat ax1800/config/device.config ax1800/config/repos.config \
    ax1800/config/packages.config ax1800/config/packages-store.config \
    ax1800/config/kernel-dae.config >> .config
sh ax1800/scripts/set-kernel-size.sh 12288
mkdir -p files && cp -Rf ax1800/files/. files/

make defconfig
make download -j$(nproc) && find dl -size -1024c -delete
make -j$(nproc)
```

产物：`bin/targets/qualcommax/ipq60xx/*factory.bin`（U-Boot `/firmware.html`）、`*sysupgrade.bin`（LuCI 升级）。

---

## 首启做了什么

`ax1800/files/etc/uci-defaults/99-ax1800` 在第一次开机时执行一次：

| 项 | 设置 |
|---|---|
| 主机名 / 时区 | `OpenWrt` / `Asia/Shanghai`，NTP 走阿里云 + cn.pool |
| IPv6 | LAN `ip6assign=60` + RA/DHCPv6 server（`managed-config other-config`）；`wan6=dhcpv6` |
| WAN | **默认 DHCP**（以后拨号见下） |
| 全锥 NAT | `firewall.@defaults[0].fullcone=1`（NAT1），`fullcone6=0` |
| WiFi | 双频合一，SSID `CLI`，加密 `sae-mixed`（WPA2-PSK + WPA3-SAE 混合），密码 `12345678` |
| 无线参数 | 2.4G `HT20`、5G `HE80`、`channel=auto`、`country=CN`、11k/11v 开、11r 关、PMF 可选 |
| 卸载 | `flow_offloading` 保持关闭（代理要接管流量；硬件加速由 NSS 负责） |
| 主题 | argon（`/luci-static/argon`） |

### 以后改拨号

```sh
uci set network.wan.proto='pppoe'
uci set network.wan.username='宽带账号'
uci set network.wan.password='宽带密码'
uci set network.wan.ipv6='1'
uci commit network && /etc/init.d/network restart
```

光猫桥接时 DHCP 拿不到地址，这一步不做就上不了网。

---

## 全锥 NAT

LibWrt 自带 `firewall4` 的 fullcone 补丁和 `fullconenat-nft`（提供 `kmod-nft-fullcone`），
不需要 turboacc。首启脚本已写死 `fullcone=1`，验证：

```sh
uci get firewall.@defaults[0].fullcone     # 1
lsmod | grep nft_fullcone                  # 有模块
```

---

## dae

**只开了内核能力**（BTF / XDP / kprobe / bpf 事件），dae 与 luci-app-dae 本体以后单独装。
BTF 段在 arm64 上约 5 MiB，进 FIT 后 +1.5~2 MiB —— 6 MiB 分区放不下，只有 12M 能带。

以后装 dae 时确认 `CONFIG_HAS_BPF_TOOLCHAIN` 与内核 `.config` 里的
`DEBUG_INFO_BTF=y` / `XDP_SOCKETS=y` 真的生效（配置里写了不等于没被 depends 丢掉）。

---

## 软件源

固件是 **apk**（LibWrt 默认 `CONFIG_USE_APK=y`），内置 `openwrt-25.12.pem` 与 `immortalwrt-25.12.pem` 两把钥匙。

| 源 | 包数（aarch64_cortex-a53，2026-11-03 实测） |
|---|---:|
| **immortalwrt 25.12-SNAPSHOT**（已选） | **10,157**（base 761 / packages 4753 / luci 3719 / routing 56 / telephony 868） |
| openwrt `releases/packages-25.12` | 8,596（含 video 60） |
| openwrt snapshots | 9,798 |
| `dl.openwrt.ai` | 只有 `.ipk`，apk 固件用不了 |

两个硬约束：

1. **kmod 不能在线装** —— apk 对内核模块卡 `kernel (= 完整版本串)`，自编固件的 vermagic 与任何官方源都对不上。
2. **`nss_packages` / `sqm_scripts_nss` 没有在线源** —— CI 现编，`scripts/feeds` 本来就默认不放进运行时仓库。

---

## 已知坑

- 路由器上没有 `od`、`timeout`、`partx`、`blockdev`、`sgdisk`、`fdisk`；有 `parted`、`blkid`、`mkfs.ext4`
- busybox ash **不认 `$'...'`**
- **6M / 12M 固件不能互刷**，`sysupgrade` 不检查分区边界
- **别装 `owut` / `luci-app-attendedsysupgrade`**：ASU 用官方 ImageBuilder 重建，定制全丢，且缺 NSS 内核模块
- `luci-i18n-*` 是 HIDDEN 符号，直接写 `.config` 会被 `defconfig` 静默丢弃
- 跑代理前别开软件卸载（`flow_offloading`），否则部分流量绕过 TUN/TPROXY
- 双频合一要真正引导频段得靠 `luci-app-usteer`（已编入）
