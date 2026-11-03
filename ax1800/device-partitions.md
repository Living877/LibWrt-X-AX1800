# 京东云亚瑟 AX1800 Pro（JDCloud RE-SS-01）设备档案

> 用途：这台机器的硬件、分区、刷机、备份、构建知识的**唯一事实底稿**。
> 本文随本仓库维护（`Living877/LibWrt-X-AX1800`，路径 `ax1800/`）。
> 原 `Living877/kwrt-ax1800` 已归档成 git bundle 后删除；其中可复用的构建结论并入第 6 节。
> 数据采集时间：2026-11-02 / 更新：2026-11-03。三处交叉核对：路由器 Web「MMC 分区信息」页、
> `parted -s /dev/mmcblk0 unit s print`、17,408 字节 GPT 文件的本地解析。

---

## 1. 硬件与机型

| 项 | 值 |
|---|---|
| 型号 | 京东云亚瑟 **AX1800 Pro** |
| 设备 ID / DTS | `ipq6018-jdcloud_re-ss-01`，`ipq6000-re-ss-01.dts`（`target/linux/qualcommax`） |
| SoC | 高通 **IPQ6000**（ipq60xx / qualcommax，4×Cortex-A53） |
| 无线 | ath11k（2.4G + 5G 各一个 phy，分批注册：5G 约 80 秒才起），21 个 NSS 相关模块 |
| 运存 | **1 GiB（硬改）**。DTS 沿用上游文件名 `ipq6018-512m.dtsi`，真实容量由 **CDT** 决定；`free` 显示约 878 MiB 属正常 |
| 存储 | eMMC **30,212,096 扇区 = 14.41 GiB**（16 GB 标称），扇区 512 B |
| 分区表 | GPT，主表 LBA 0~33，`first_usable_lba = 34`，`last_usable_lba = 30212062` |
| U-Boot | chenxin527/uboot-qsdk12.5-build，`U-Boot 2016.01 (Dec 23 2024)`，651,600 字节，位于 `0:APPSBL`（A/B 双份） |
| 当前布局 | **12M**：`0:HLOS` = 12 MiB（原厂 6 MiB），rootfs 2 GiB，盘尾自建 `p27` 数据盘 11.42 GiB |

---

## 2. eMMC 分区表（12M 布局）

### 2.1 设备号换算（最容易出事的一条）

表里的 `#` 从 1 数，但 **`#1 0:GPT` 不是分区项**——它是保护性 MBR + GPT 头 + 分区数组所占的那 34 个扇区本身，不占分区槽。

> **`/dev/mmcblk0pN` 的 N = `#` − 1**

例：`#16 0:ART` → `mmcblk0p15`；`#19 rootfs` → `mmcblk0p18`；`#28 data` → `mmcblk0p27`。
反证：本机自建的 data 分区在实机上就是 `p27`，而它在表里是第 28 行。
**别拿 `#` 当设备号，写错一位就是往别的分区里 dd。**

### 2.2 完整分区表

| # | 名称 | 起始扇区 | 结束扇区 | 扇区数 | 大小 | 用途 / 设备 |
|---:|---|---:|---:|---:|---|---|
| 1 | `0:GPT` | 0 | 33 | 34 | 17 KiB | 保护 MBR + GPT 头 + 分区项（不占槽） |
| 2 | `0:SBL1` | 34 | 1569 | 1536 | 768 KiB | 二级引导（p1） |
| 3 | `0:BOOTCONFIG` | 1570 | 2081 | 512 | 256 KiB | p2 |
| 4 | `0:BOOTCONFIG1` | 2082 | 2593 | 512 | 256 KiB | 备份槽（p3） |
| 5 | `0:QSEE` | 2594 | 6177 | 3584 | 1.75 MiB | 安全执行环境（p4） |
| 6 | `0:QSEE_1` | 6178 | 9761 | 3584 | 1.75 MiB | 备份槽（p5） |
| 7 | `0:DEVCFG` | 9762 | 10273 | 512 | 256 KiB | **MAC/SN，不可再生**（p6） |
| 8 | `0:DEVCFG_1` | 10274 | 10785 | 512 | 256 KiB | 备份槽（p7） |
| 9 | `0:RPM` | 10786 | 11297 | 512 | 256 KiB | 资源电源管理（p8） |
| 10 | `0:RPM_1` | 11298 | 11809 | 512 | 256 KiB | 备份槽（p9） |
| 11 | `0:CDT` | 11810 | 12321 | 512 | 256 KiB | **平台参数，1G 运存改版靠这个**（p10） |
| 12 | `0:CDT_1` | 12322 | 12833 | 512 | 256 KiB | 备份槽（p11） |
| 13 | `0:APPSBLENV` | 12834 | 13345 | 512 | 256 KiB | U-Boot 环境变量（p12） |
| 14 | `0:APPSBL` | 13346 | 14625 | 1280 | 640 KiB | **U-Boot 本体**（p13） |
| 15 | `0:APPSBL_1` | 14626 | 15905 | 1280 | 640 KiB | U-Boot 备份槽（p14） |
| 16 | `0:ART` | 15906 | 16417 | 512 | 256 KiB | **无线校准，整机唯一，丢了 WiFi 报废**（p15） |
| 17 | `0:HLOS` | 16418 | 40993 | 24576 | **12 MiB** | **内核（FIT）**（p16） |
| 18 | `0:HLOS_1` | 40994 | 53281 | 12288 | 6 MiB | 内核备份槽（p17） |
| 19 | `rootfs` | 53282 | 4247585 | 4194304 | 2 GiB | 根文件系统 squashfs（p18） |
| 20 | `0:WIFIFW` | 4247586 | 4255777 | 8192 | 4 MiB | 无线固件（p19） |
| 21 | `rootfs_1` | 4255778 | 4378657 | 122880 | 60 MiB | 备用根（p20） |
| 22 | `0:WIFIFW_1` | 4378658 | 4386849 | 8192 | 4 MiB | 无线固件备份（p21） |
| 23 | `rootfs_data` | 4386850 | 4427809 | 40960 | 20 MiB | 预留（iStoreOS 没用，overlay 走 loop 文件） |
| 24 | `0:ETHPHYFW` | 4427810 | 4428833 | 1024 | 512 KiB | PHY 固件 |
| 25 | `plugin` | 4428834 | 4608033 | 179200 | 87.5 MiB | 插件区（未挂载） |
| 26 | `log` | 4608034 | 5222433 | 614400 | 300 MiB | 日志区（未挂载） |
| 27 | `swap` | 5222434 | 6271009 | 1048576 | 512 MiB | **未启用**（2026-11-02 时 `/proc/swaps` 为空） |
| 28 | `data` | 6271010 | 30212062 | 23941053 | **11.42 GiB** | **自建，ext4 → `/mnt/data`（p27）** |

前 16 个分区在 6M / 12M 两张表里完全相同，所以 `p4`–`p15` 这套编号不受换表影响；变的是 `p19` 及之后。

### 2.3 三个关键偏移

| 偏移 | 含义 |
|---|---|
| `16418` 扇区 = 8,406,016 B = **8.02 MiB** | 内核 FIT 起点（HLOS 起始），所有布局都一样 |
| `16418 + 12288 = 28706` 扇区 = **14.02 MiB** | **6M 布局**下 rootfs 起点（`hsqs` 应在此） |
| `16418 + 24576 = 40994` 扇区 = **20.02 MiB** | **12M 布局**下 rootfs 起点（`hsqs` 应在此） |
| `53282` 扇区 | 本机 rootfs 分区起点（由 GPT 表定，不是 hsqs 的位置） |

判断任意 `factory.bin` 是 6M 还是 12M，不解包，两条命令：

```sh
od -An -tu4 -j4 -N4 --endian=big factory.bin     # FIT 头里的 totalsize（大端）
od -An -tx1 -j6291456  -N4 factory.bin           # 6M  版：应输出 68 73 71 73 (hsqs)
od -An -tx1 -j12582912 -N4 factory.bin           # 12M 版：应输出 68 73 71 73
```

实测：`build-49`（6M）FIT 4,899,804 B = 4.673 MiB，`hsqs` 在 6 MiB；iStoreOS 那份 110.6 MiB 镜像 FIT 5.748 MiB，6 MiB 处全零、`hsqs` 在 12 MiB。

**装错的后果**：6M 固件刷进 12M 表 → rootfs 落在 14 MiB 附近而表指向 26 MiB → `VFS: Unable to mount root fs`。不是砖，U-Boot 还在，重刷即可。

### 2.4 这套 12M 表的来历与遗留问题

原始 GPT 文件 `gpt-JDC_AX1800_Pro_dual-boot_rootfs2048M_HLOS12M_no-last-partition.bin`（**17,408 字节 = 34 扇区**）只定义到 `swap` 为止，所以：

1. 盘尾 11.4 GiB 未分配，Linux 下不显示、不挂载；
2. 表头 `last_lba = 8,683,519`（4.14 GiB）与实际容量不符，盘尾备份 GPT 是旧 6M 表的残留：

```
GPT:Primary header thinks Alt. header is not at the end of the disk
# 主表 CRC 0xc01b4cb5 vs 盘尾备份 0x77537fc8
```

修法（`parted -s` 不会自动修，**必须交互式**）：

```sh
printf "OK\nFix\n" | parted ---pretend-input-tty /dev/mmcblk0 unit s print
```

两个提示按顺序答：`OK/Cancel?` → `OK`，`Fix/Ignore?` → `Fix`。只喂一个 `Fix` 会报 `invalid token: Fix`。

修完建数据分区（`last_usable = 30212062`）：

```sh
parted -s /dev/mmcblk0 unit s mkpart data ext4 6271010s 30212062s
mkfs.ext4 -m 0 -L data /dev/mmcblk0p27      # -m 0 省掉 5% 保留块
```

内核立刻认到 `/dev/mmcblk0p27`（devtmpfs 自动建节点，不用重启）。挂载写 `/etc/config/fstab`，按 UUID：

```
config mount 'data'
        option target '/mnt/data'
        option uuid '<blkid 出来的 UUID>'
        option options 'rw,noatime'
        option enabled '1'
```

起点 `6271010 % 2048 != 0`，parted 会报对齐警告——根源是 `swap` 起点本来就没对齐，忽略即可。

---

## 3. 刷机流程（顺序不能反）

U-Boot 网页（chenxin527 版）**只有这些页面**：

```
/firmware.html  /art.html  /cdt.html  /ptable.html
/simg.html      /uboot.html  /initramfs.html  /mibib.html  /backup.html
```

**没有 `/uimage.html`、没有 `/img.html`、没有 `/big.html`** —— 那是恩山旧版 U-Boot 的页面名，这台机器上访问是 404。

1. 断电，网线接 LAN 口，电脑设 `192.168.1.2/24`，按住 reset 上电，约 5 秒后松开，浏览器开 `http://192.168.1.1`
2. `/backup.html` 导出 **ART、DEVCFG、CDT**
3. `/ptable.html` 刷 17,408 字节的 12M GPT → **必须重启**（分区表只在开机读入内存）
4. 重新进 U-Boot → `/firmware.html` 刷 12M 版 `factory.bin`

| 场景 | 顺序 |
|---|---|
| 6M 刷 6M | `/firmware.html` 直接刷 |
| 6M 换 12M | `/backup.html` 备份 → `/ptable.html` 刷 GPT → 重启 → `/firmware.html` 刷 12M 固件 |
| 12M 刷 12M（升级） | LuCI「系统 → 备份/刷写固件」或 `sysupgrade /tmp/xxx.bin` |
| 12M 回 6M | 必须同时刷回 6M GPT + 6M 固件，否则挂不上根 |

**别碰** `/art.html`（无线校准）和 `/cdt.html`（运存参数）。分区表只写 LBA 0~33，不碰 ART、SBL1、QSEE、DEVCFG，也不碰 APPSBL（U-Boot 自己）。

U-Boot 定位内核的方式（`board/qca/arm/common/failsafe.c`）：从 HLOS 起点扫第一个 `hsqs`，偏移按 1 MiB 对齐即认为内核结束——6M / 12M 两套布局都认，不需要 `/big.html` 之类的开关。

刷完第一件事：**网络 → 接口 → WAN → 协议改 PPPoE** 填宽带账号（光猫桥接时 DHCP 拿不到地址）。

---

## 4. 备份与恢复

### 4.1 备份在哪

| 位置 | 内容 |
|---|---|
| U 盘 `路由器备份/data_mmcblk0p20/ax1800-加密备份.zip` | 9 个 `.bin` + `MANIFEST.md5`；ZipCrypto，3.23 MiB，MD5 `f3e3bba7b665d1c959bf66ba08b509ac` |
| U 盘 `路由器备份/data_mmcblk0p20/` | 10-01 旧快照（Kwrt 11.10.2025）；`mmcblk0boot0_不死uboot.bin` 是 4 MiB 全零，无价值 |
| 本地 `backups/ax1800/`（仓库外） | 9 个明文 `.bin` + `MANIFEST.md5` + `build-49/` 固件 |

### 4.2 文件清单与 MD5

| 文件 | 大小 | 目标（12M 表） | 场景 | 敏感度 |
|---|---|---|---|---|
| `art.bin` | 256 KB | `p15` | 无线校准丢失、5G 起不来 | **私密（每机唯一）** |
| `cal-from-p19.bin` | 64 KB | `/lib/firmware/...`（不进分区） | 同上，更安全的等价做法 | 私密 |
| `mibib-gpt-8m.bin` | 8 MB | `/dev/mmcblk0` 前 8 MB | 分区表被破坏（**是旧 6M 表**） | 低 |
| `p4.bin` / `p5.bin` | 1.75 MB 各 | `p4` / `p5`（QSEE A/B） | 引导损坏 | 中 |
| `devcfg-p6.bin` / `devcfg-p7.bin` | 256 KB 各 | `p6` / `p7` | MAC/SN 丢失 | **高（不可再生）** |
| `p13.bin` / `p14.bin` | 640 KB 各 | `p13` / `p14`（APPSBL A/B） | 变砖 | 低 |

```
9f05376b3989ad66014910c920d5c8f0 *art.bin
a5cb30f5f62ea7c8a08295d10b292422 *cal-from-p19.bin
ca54fb241d76a53be64fb420bcbdeb30 *devcfg-p6.bin
a7037d07b67f890b80c536b458bdb6ad *devcfg-p7.bin
f22829efb9fd2e12abb3cdd1ea9fb405 *mibib-gpt-8m.bin
1291cf11320446ba967d52fd26e294ba *p13.bin
1291cf11320446ba967d52fd26e294ba *p14.bin
c4fc2183f2331b709bb771ecec198a27 *p4.bin
0167bbc33d903cc0174d798318a1f5ae *p5.bin
```

### 4.3 恢复命令

```sh
# 最安全：只恢复校准文件，不动分区表
mkdir -p /lib/firmware/ath11k/IPQ6018/hw1.0
cp cal-from-p19.bin /lib/firmware/ath11k/IPQ6018/hw1.0/cal-ahb-c000000.wifi.bin && sync && reboot

# ART 整分区（写前先导出当前值，写完回读比对）
dd if=/dev/mmcblk0p15 of=/tmp/art-before.bin bs=512 count=512
dd if=art.bin of=/dev/mmcblk0p15 bs=512 count=512 && sync
dd if=/dev/mmcblk0p15 of=/tmp/art-check.bin bs=512 count=512 && md5sum /tmp/art-check.bin art.bin

# DEVCFG（MAC 变成 00:00:00:00:00:00 时）
dd if=devcfg-p6.bin of=/dev/mmcblk0p6 bs=512 count=512
dd if=devcfg-p7.bin of=/dev/mmcblk0p7 bs=512 count=512

# 分区表（会回到 6M 布局，盘尾 p27/swap/log/plugin 全部消失）
dd if=mibib-gpt-8m.bin of=/dev/mmcblk0 bs=512 count=16384 && sync && reboot

# 引导链（通常不需要：p13/p14 MD5 相同，A/B 一直一致）
dd if=p4.bin  of=/dev/mmcblk0p4  bs=512 count=3584
dd if=p5.bin  of=/dev/mmcblk0p5  bs=512 count=3584
dd if=p13.bin of=/dev/mmcblk0p13 bs=512 count=1280
dd if=p14.bin of=/dev/mmcblk0p14 bs=512 count=1280
```

### 4.4 六条须知

1. **`p19` 不能拿来写旧数据盘**：旧 6M 表下 `p19` 是 5 GiB 数据盘，当前 12M 表下 `p19` 是 `0:WIFIFW`（4 MiB）。按编号 dd 回去会一路盖掉 WIFIFW、rootfs_1、WIFIFW_1、rootfs_data、ETHPHYFW、plugin、log、swap。
2. **前 16 个分区两表相同**，`p4`–`p15` 编号不受换表影响。
3. `p13.bin` 与 `p14.bin` MD5 相同，U-Boot A/B 健康。
4. `devcfg` 里是带高通测试证书链的出厂数据，刷机无法重建。
5. **ART 从未被 12M 刷机动过**：10-01 快照里的 p15 与本次 `art.bin` 逐字节相同。
6. 历史提交 `0505fa6` 里有加密 zip；ZipCrypto 是 1989 年的格式，别依赖它做异地备份。

---

## 5. 固件定制要点（换任何新底座都要迁移这些）

| 目标 | 做法 | 落点 |
|---|---|---|
| 无线并发 16 VDEV / 512 peers | `qcom,ath11k-fw-memory-mode = <1>` → `<0>` | DTS `ipq6000-re-ss-01.dts` |
| NSS 无线内存 | `q6_region` `0x3700000`（55 MiB）→ `0x5500000`（85 MiB） | `ipq6018-512m.dtsi`（断言要幂等，上游可能已改默认值） |
| 默认网段 / 主机名 | `10.0.0.1`/`Kwrt` → `192.168.1.1`/`OpenWrt` | `config_generate`、`mac80211.uc`、`version.mk` 等 7 个文件 |
| 无线加密套件 | `wpad-openssl` → `wpad-mbedtls` | `target/linux/qualcommax/Makefile` |
| 设备名 | `DEVICE_MODEL := RE-SS-01 AX1800 Pro` | `target/linux/qualcommax/image/ipq60xx.mk`（补丁 hunk 上下文里带 `KERNEL_SIZE := 6144k`） |
| 内核分区 | `KERNEL_SIZE := 6144k` → `12288k`，镜像命令 `pad-to $$(KERNEL_SIZE)` | 同上，**必须在打补丁之后改** |
| 首启配置 | IPv6、双频合一、带宽 HT20/HE80、cal 提取、root 密码注入 | `uci-defaults/99-ax1800` |
| WiFi 身份守护 | 覆盖 mywifi 热插拔 + `wifi-guard` 开机校验/150s 复校 | `base-files` 的 `10-wifi-detect`、`/usr/sbin/wifi-guard` |
| NSS 固件 / cal 早于驱动 | `nss-fw-early`（START 08）、`caldata-early`（START 09），挂 preinit | `base-files` |

**两个必须理解的实现细节**

- **NSS 固件与 cal 必须早于驱动**：`request_firmware()` 只在开头同步查一次，查不到就转用户态回落、60 秒后返回 `-110`，回落窗口里再往 `/lib/firmware` 建文件不算数。NSS 包只装 `qca-nss0-retail.bin`（驱动要裸名 `qca-nss0.bin`），cal 由热插拔事后 `dd` —— 都太晚，会级联到开机 4 分半且无线全无。两支脚本把等待超时从 60s 收到 10s 兜底。
- **mywifi 会无条件重写无线身份**：kiddin9 的 `my-default-settings` 自带 `10-wifi-detect`，每次 phy 注册都跑 `/sbin/mywifi`，把 SSID 改成 `<hostname>_5G`、加密改 `none`、密码 `uci del`（2026-10-31 16:32 实机复现）。正确修法是**让这个文件只有一个包提供**——`wifi-scripts`（上游 openwrt / LibWrt 都有）自带同名安全版，把我方那份从包里删掉即可；再叠加 `wifi-guard` 兜底。

---

## 6. 构建体系与踩过的坑

### 6.1 两套构建路径

| | `main`（opkg，已验证可用） | `exp/apk`（实验，未出过固件） |
|---|---|---|
| 底座 | openwrt + immortalwrt + LibWrt + kiddin9 **四源拼装** | `LiBwrt/LibWrt@25.12-nss` **单源整树** |
| 包管理 | opkg | apk |
| 外补丁 | 22 个 + 26 处 sed | 不打外补丁，改成正向断言 |
| 软件源 | `dl.openwrt.ai`（只发 `.ipk`） | `mirrors.pku.edu.cn/immortalwrt` 25.12-SNAPSHOT |
| 内核 FIT | 4.673–4.79 MiB（余量 1.3 MiB） | 6.221 MiB（12M 版） |
| 触发 | push（带 `[build]` 或上游有变）+ 每天 03:00 + 手动 | **只能手动 dispatch**（push 只监听 main） |

### 6.2 关键失败与修法（按真实 run 记）

1. **`KERNEL_SIZE` 改写早于补丁** → `jdcloud-re-ss-01.patch` hunk #1 FAILED at 360，patch 退出 123，根本没进编译。
   → 改写挪到「应用 devices 补丁」之后的独立步骤。
2. **apk 拒绝重复文件归属**（run 41415764234，第 459/479 个包）：
   ```
   ERROR: my-default-settings-2-r38: trying to overwrite
          etc/hotplug.d/ieee80211/10-wifi-detect owned by wifi-scripts-1.0-r1.
   ERROR: my-default-settings-2-r38: trying to overwrite
          etc/uci-defaults/99-default-settings owned by default-settings-29.
   ```
   → 从 `my-default-settings` 里删掉这两份；热插拔交给底座；自己的首启脚本改名 `99-my-default-settings`（ls 顺序仍在 `99-default-settings` 之后）。**opkg 会静默覆盖，所以只有 apk 分支炸。**
3. **BTF 校验读错 `.config`**：`find build_dir/target-*/linux-* -maxdepth 3 -name .config` 会同时命中内核和 `mac80211-regular/backports-*/.config`，遍历顺序不保证。
   → 显式取 `build_dir/target-*/linux-*/linux-[0-9]*/.config`。
4. **固件内容核对的两类误报**：`.config` 里 `CONFIG_PACKAGE_xxx` 大量是**包内子选项**（`ATH_DFS`、`dnsmasq_full_dhcp`、`luci-app-passwall_INCLUDE_*`），永远不进 manifest；apk 还会把库改名（`libstdcpp6`、`libcurl4`、`libubox20240120`）。
   → 先与「树里真有 Makefile 目录」的包名取交集，再对两边做尾部版本号归一化。
5. **base-files 编不过**（apk）：`REVISION=11.01.2026` 触犯 apk 版本号规则（`~` 后只认十六进制）。→ 值写成 `<YYYYMMDD>-<上游短 sha>`。
6. **luci-app-fan 版本号非法**：`PKG_VERSION=1.0.0-r3` + `PKG_RELEASE=1` → `1.0.0-r3-r1`。→ 构建时剥掉 `PKG_VERSION` 尾部 `-rN`。
7. **整站英文**：`luci-i18n-*` 是 HIDDEN 符号，往 `.config` 塞 `=y` 会被静默丢弃。→ 先摘 HIDDEN 再按真实符号强选，并用 manifest 反查语言包数量。
8. **rust 工具链被意外拉入**：`quickfile` 与 ruby 的 `RUBY_ENABLE_YJIT`（aarch64 默认 y）都声明 `rust/host`。→ 关掉 quickfile、`CONFIG_RUBY_ENABLE_YJIT is not set`。
9. **libffi 打包失败**：`Build/InstallDev` 按三胞胎名找 `fficonfig.h`，本树 `--enable-builddir=qualcommax_ipq60xx` 对不上。→ 改成深度 2 通配。

### 6.3 构建产物与校验

- 产物：`*squashfs-factory.bin`（U-Boot `/firmware.html`）、`*squashfs-sysupgrade.bin`（LuCI / `sysupgrade`）、`.manifest`、`md5sums.txt`
- 校验：编译前关键包清单 → 编译后 FIT 体积与 `hsqs` 边界 → 12M 的 BTF/XDP → manifest 反查
- 12M 版必须配 **12M U-Boot + 12M GPT**；`sysupgrade` 不做分区边界检查，6M/12M 不能互刷

---

## 7. 开机默认值

| 项 | 值 |
|---|---|
| 管理地址 | `192.168.1.1` |
| 主机名 | `OpenWrt` |
| WiFi | 双频合一，SSID `CLI` / 密码 `12345678`（WPA2-AES，11k/11v 开、11r 关） |
| 带宽 | 2.4G `HT20`，5G `HE80`（160MHz 在 IPQ6000 上干扰下反而掉速） |
| 后台账号 | `root`，密码由 Secret 注入；没配则留空，首登提示设置 |
| WAN | DHCP（PPPoE 手动改） |
| IPv6 | LAN 侧已开（`ip6assign=60` + RA/DHCPv6 server） |
| 主题 | Argon 3.x，页脚无外链、无署名 |

跑 OpenClash 前建议关硬件卸载，否则部分流量不走代理：

```sh
uci set firewall.@defaults[0].flow_offloading='0'
uci set firewall.@defaults[0].flow_offloading_hw='0'
uci commit firewall
/etc/init.d/qca-nss-ecm disable
/etc/init.d/firewall restart
```

---

## 8. 已知坑 / 不要做

- 路由器系统里**没有** `od`、`timeout`、`partx`、`blockdev`、`sgdisk`、`fdisk`；有 `parted`、`blkid`、`losetup`、`resize2fs`、`mkfs.ext4`
- busybox ash **不认 `$'...'`**
- **别装 `owut` / `luci-app-attendedsysupgrade`**：ASU 用自己的 ImageBuilder 重建，源码级定制全丢，且 `kmod-qca-nss-ecm` / `kmod-ath11k-ahb` 官方源没有
- **双频合一没有 band steering**：OpenWrt 原生只做"同名"，智能插座会赖在 2.4G；要引导得装 `usteer`
- 内存显示 878 MiB 是正常的（Q6 保留区 85 MiB + TZ/NSS + 内核）
- 风扇若是带物理开关的独立温控器（45℃ 开 / 40℃ 关），固件不负责
- `swap` 512 MiB 一直没启用，1G 运存跑 docker/openclash 时建议开
- Kwrt 系固件是 **nginx + uhttpd 双栈**，网页打不开时两边都要查
- GitHub 连续 60 天无活动会自动禁用定时任务

---

## 9. 实机当前状态（2026-11-03）

- 已刷 **12M GPT**：`0:HLOS` = 12 MiB、rootfs 2 GiB、`p27` 11.42 GiB 挂 `/mnt/data`
- 当前运行 **natserver / iStoreOS** 作为过渡，等自编 12M 固件
- ART 从未被改动，备份齐全（见第 4 节）
- `Living877/kwrt-ax1800` 的 `main` 与 `exp/apk` 均**未产出可刷的 12M 固件**：
  - `main`：12M 支持已写完但从未完整跑通一次构建（多次被取消/跳过）
  - `exp/apk`：已推进到「固件内容核对」并编出固件（FIT 6.221 MiB、12M 边界、BTF/XDP 均通过），因两类校验误报未发布；误报已修，但尚未重跑验证

---

## 10. 相关归档

| 文件 | 说明 |
|---|---|
| `kwrt-ax1800.bundle` | 原仓库完整 git 历史（main / exp/apk 两分支），`git clone kwrt-ax1800.bundle` 可恢复 |
| `部分构建日志/` | 几次关键失败的 GitHub Actions 原始日志（可选） |
