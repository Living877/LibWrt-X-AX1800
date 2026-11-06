# LibWrt X AX1800

京东云亚瑟 AX1800 Pro（IPQ6000 / `ipq6018-jdcloud_re-ss-01`）的自编固件仓库。

底座是 [LiBwrt/LibWrt](https://github.com/LiBwrt/LibWrt) `25.12-nss`（**apk** 包管理，内核 6.12），
本仓库是它的 fork：上游源码原样保留，所有定制集中在 `ax1800/` 下，同步上游用 merge 而不是强推。

> 上游 README（NSS 功能矩阵、设备支持范围）见 [LiBwrt/LibWrt](https://github.com/LiBwrt/LibWrt)。
> 本仓库关心的只有这一台机器。

---

## 这台机器

| 项 | 值 |
|---|---|
| 机型 | 京东云亚瑟 AX1800 Pro，`ipq6018-jdcloud_re-ss-01` |
| SoC | IPQ6000（qualcommax / ipq60xx），ath11k 无线 + NSS 硬件加速 |
| 运存 | **1 GiB（硬改）**，`free` 显示 ~878 MiB 正常（Q6 保留区 85 MiB） |
| eMMC | 30,212,096 扇区 = 14.41 GiB，扇区 512 B |
| 分区表 | GPT，**12M 布局**：`0:HLOS` 12 MiB、rootfs 2 GiB、`p27` 数据盘 11.42 GiB |
| U-Boot | chenxin527 版；网页只有 `/firmware.html`、`/ptable.html`、`/backup.html` 等 |

完整分区表、设备号换算（`mmcblk0pN` 的 N = 表里 `#` − 1）、偏移与刷机顺序：
**[ax1800/device-partitions.md](ax1800/device-partitions.md)** —— 动分区前必须先看。

---

## 固件里有什么

- **NSS 全套硬件加速**：`kmod-qca-nss-drv*` / `-ecm`，PPPoE、L2TP、GRE、VLAN 走 NSS 核心
- **代理**：OpenClash（含 dnsmasq-full / ruby / kmod-tun / kmod-nft-tproxy）
- **网络**：usteer（双频合一频段引导）、ddns + 阿里云/Cloudflare/DNSPod 脚本、sqm-scripts-nss、UPnP、WOL、无线连接历史
- **全锥 NAT1**：`firewall4` fullcone（LibWrt 自带补丁 + `kmod-nft-fullcone`）
- **存储**：Samba4、diskman、automount、USB 与 ext4/vfat/exfat/ntfs3/btrfs 驱动、nls（含 cp936）
- **远程**：WireGuard
- **系统**：ttyd、commands、autoreboot、zram-swap、iStore（`luci-app-store`）、argon 3.x 主题
- **中文界面**：常用 LuCI 应用的中文语言包
- **dae**：只开了内核能力（BTF / XDP / kprobe / bpf 事件），**dae 本体不装**，以后单独装

插件全表（用途 / 依赖 / 注意事项）见 **[ax1800/plugin-catalog.md](ax1800/plugin-catalog.md)**。

## 开箱默认值

| 项 | 值 |
|---|---|
| 管理地址 | `192.168.1.1` |
| 账号 / 密码 | `root` / `root`（可用仓库 Secret `ROOT_PASSWORD` 覆盖） |
| WiFi | 双频合一，SSID `CLI`，加密 `sae-mixed`（WPA2-PSK + WPA3-SAE 混合），密码 `12345678` |
| 无线参数 | 2.4G `HT20`、5G `HE80`、`channel=auto`、`country=CN`、11k/11v 开、11r 关 |
| WAN | **DHCP**（拨号命令见下） |
| IPv6 | LAN 侧已开（`ip6assign=60` + RA/DHCPv6 server），`wan6=dhcpv6` |
| 主题 | argon 3.x |

> ⚠️ 默认口令（root/root、WiFi 12345678）只适合内网自用。固件会自动发布到公开 Release，
> 介意的话把仓库转私有，或在 `99-ax1800` 里改掉默认值。

### 改拨号

```sh
uci set network.wan.proto='pppoe'
uci set network.wan.username='宽带账号'
uci set network.wan.password='宽带密码'
uci set network.wan.ipv6='1'
uci commit network && /etc/init.d/network restart
```

---

## 自动构建与发布

```
每天 03:00  sync-upstream.yml   比对上游 HEAD → 有变化就 merge 并触发构建
      ↓
        build.yml               装依赖 → feeds → argon 3.x → 合并配置 → 编 12M
                                → 校验 FIT/hsqs/manifest → 发 Release
```

- **同步是 merge，不是 `gh repo sync`** —— 后者会把 `ax1800/` 下的提交冲掉。
- 上游提交只增不改，冲突只可能出现在根 `README.md`（本地版本优先）。
- `.upstream-state` 记录「已成功构建的上游 SHA」；构建失败不写，第二天自动重试。
- Release 正文自动生成三段：上游更新（`git log prev..HEAD -- target package include config toolchain`）、
  本次固件体积与包数、刷写说明。

### 手动触发

Actions → **Build AX1800 12M** → Run workflow，`kernel_size` 默认 `12288`（12M 表）。

### 本地编译

```sh
git clone --depth 1 -b 25.12-nss https://github.com/Living877/LibWrt-X-AX1800.git
cd LibWrt-X-AX1800

cp feeds.conf.default feeds.conf
./scripts/feeds update -a && ./scripts/feeds install -a
echo 'src-git istore https://github.com/linkease/istore.git' >> feeds.conf
./scripts/feeds update -p istore
./scripts/feeds install -p istore luci-app-store luci-lib-taskd taskd luci-lib-xterm

./scripts/feeds uninstall luci-theme-argon luci-app-argon-config || true
rm -rf package/luci-theme-argon
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

产物 `bin/targets/qualcommax/ipq60xx/*factory.bin`（U-Boot `/firmware.html`）与 `*sysupgrade.bin`。

---

## 软件源

固件是 **apk**（LibWrt 默认 `CONFIG_USE_APK=y`），内置 `openwrt-25.12.pem` 与 `immortalwrt-25.12.pem`。

| 源 | 包数（aarch64_cortex-a53） |
|---|---:|
| **immortalwrt 25.12-SNAPSHOT**（已选） | **10,157** |
| openwrt `releases/packages-25.12` | 8,596 |
| openwrt snapshots | 9,798 |
| `dl.openwrt.ai` | 只有 `.ipk`，apk 固件用不了 |

约束：**kmod 不能在线装**（apk 卡 `kernel (= 完整版本串)`，自编固件 vermagic 不同）；
`nss_packages` / `sqm_scripts_nss` 是 CI 现编的，没有在线镜像。

---

## 目录

```
ax1800/
  README.md              构建与首启说明
  device-partitions.md   设备与分区事实底稿
  plugin-catalog.md      插件清单（用途/依赖/注意事项）
  config/                配置片段（机型、包、iStore、dae 内核、软件源）
  files/                 rootfs 覆盖层（首启脚本 / apk world 裁剪）
  scripts/               12M 内核分区改写
.github/workflows/
  build.yml              构建 + 校验 + 自动发布
  sync-upstream.yml      每天同步上游并触发构建
```

## 已知坑

- 6M / 12M 固件**不能互刷**，`sysupgrade` 不检查分区边界
- **别装 `owut` / `luci-app-attendedsysupgrade`**：ASU 用官方 ImageBuilder 重建，定制全丢
- `luci-i18n-*` 是 HIDDEN 符号，直接写 `.config` 会被 `defconfig` 静默丢弃
- 跑代理前别开软件卸载（`flow_offloading`），否则部分流量绕过 TUN/TPROXY
- 路由器上没有 `od`、`timeout`、`partx`、`sgdisk`、`fdisk`；有 `parted`、`blkid`、`mkfs.ext4`
- busybox ash **不认 `$'...'`**
- **`apk` 每次事务都报 `1 error`（未解决）**：镜像里 452 个包全被写进 `/etc/apk/world`，其中 166 个 `kmod-*` 绑死本机编译哈希 `kernel=6.12.112~7b482d99…`，公共源里是 `cf8cd0bb…`，任何已配置仓库都找不到它们。注意 apk 的检查对象是**已安装包集合**（`/lib/apk/db/installed`），不是 world：实测把 world 里的 kmod 全删掉，`apk add -s luci-base` 退出码仍是 1，反而把这些包变成孤儿，`apk upgrade` 会计划 Purging 78 个（含 `kmod-mac80211`/`kmod-ath11k`，WiFi 当场没了）。**所以不要裁 world**。根治只有一条路：把自编译产物 `bin/targets/qualcommax/ipq60xx/packages/` 和 `kmods/<内核版本>/` 发布成一个 apk 源，让 apk 真的找得到这 166 个包。在那之前，`1 error` 只影响退出码，装包本身是成功的（iStore / OpenClash 会误判成失败）。
- **别 `apk upgrade` 整个系统**：源里的内核是另一个编译哈希，升级内核会让现有全部 kmod 失配（无线、NSS、文件系统模块全挂）。装单个包用 `apk add 包名` 就行。
- **别照着 apk 的 `NOTE: Consider running apk upgrade with --prune and/or --available` 做**：`--prune` 会把 90 个包当孤儿清掉（`kmod-fs-f2fs`、`kmod-leds-gpio`、`kmod-gpio-button-hotplug`、`kmod-dsa`/`kmod-dsa-qca8k`、`kmod-thermal`、`kmod-qcom-qmi-helpers`、`kmod-qrtr`、`kmod-mhi-bus`、`kmod-phylink`、`kmod-regmap-core` …），`--available` 会把 99 个包替换成源里的版本。这台机器的内核是打 NSS 补丁自编译的，两条跑下去当场失能。那条 NOTE 是 apk 的通用建议，在「内核非官方」的场景下是陷阱。
- **包源被换成 `mirrors.vsean.net`（已处理）**：`default-settings-chn` 首启会把 `/etc/apk/repositories.d/distfeeds.list` 里的 `downloads.immortalwrt.org` 全换成 `system.@imm_init[0].apk_mirror`，它的默认值是 `https://mirrors.vsean.net/openwrt`。这个域名现在只回一个跟不过去的 302（日志里是 `wget: exited with error 8` / `unexpected end of file`），六个源索引全刷不下来，`apk update` 就又凑出 1 个 error —— 和 world 那 175 条是两回事。固件里做了双保险：`/etc/uci-defaults/99-ax1800` 先把 `apk_mirror` 钉成官方源（它排在 `99-default-settings-chinese` 前面，对方的 sed 变成空操作），`/etc/rc.local` 每次开机再把残留的 vsean 地址改回来。

## 自建 apk 源（apk-repo 分支）

固件里 166 个 `kmod-*` 绑死本机内核哈希（`kernel=6.12.112~7b482d99…`），公共源里永远没有这一份，
apk 每次事务都会记 1 个 error。根治办法是自己发源：

- CI 编译完后，把 `bin/targets/qualcommax/ipq60xx/packages/` 和 `kmods/<内核版本>/` 里的 `.apk`
  用 `apk mkndx` 重新打索引，force-push 到本仓库的 `apk-repo` 分支。每次一个孤儿提交，
  历史永远只有 1 个 commit，不会把仓库撑爆。
- 固件构建时自动生成 `/etc/apk/repositories.d/00-ax1800.list`，指向
  `https://raw.githubusercontent.com/<owner>/<repo>/apk-repo/target/packages.adb` 和
  `.../apk-repo/kmods/packages.adb`。
- 用 raw 不用 Release：Releases 会 302 到 `objects.githubusercontent.com`，apk 不跟跨域跳转，
  会重演 `mirrors.vsean.net` 那个 `wget: exited with error 8`。

**签名**：apk 只信任 `/etc/apk/keys/` 里的公钥。固件开了 `CONFIG_SIGNED_PACKAGES=y`，
构建时用 `private-key.pem` 给索引签名，公钥由 base-files 装进镜像。私钥放仓库 Secret：

```sh
openssl ecparam -name prime256v1 -genkey -noout -out private-key.pem
gh secret set APK_SIGNING_KEY --repo <owner>/<repo> < private-key.pem
```

没配 Secret 时构建会现生成一把，镜像和源仍然自洽；但下次重新构建后，之前刷的旧镜像就不认新源了
（表现为 `apk update` 报 UNTRUSTED signature）。

验证：`apk update` 应看到多出两条 raw 源、退出码 0；`apk add -s luci-base` 退出码 0，
不再出现 `The following packages are no longer available from a repository`。

## 许可

上游 LibWrt / OpenWrt 均为 GPL-2.0，本仓库继承。
