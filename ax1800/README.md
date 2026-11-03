# AX1800（京东云亚瑟 Pro）构建档案

这台机器的硬件、分区、刷机、定制与插件选择都在这里，供人和智能体直接阅读。

| 文件 | 内容 |
|---|---|
| [device-partitions.md](device-partitions.md) | **设备与分区事实底稿**：机型/SoC/运存、eMMC 28 项分区逐条、6M/12M 两个边界、判断固件布局的两条 `od`、GPT 备份表修复、`p27` 数据盘、刷机顺序、备份 MD5 与恢复命令 |
| [plugin-catalog.md](plugin-catalog.md) | 可编译插件清单：每个包干什么用、依赖、哪些旧固件有、哪些别装 |
| [config/kernel-dae.config](config/kernel-dae.config) | dae 需要的**内核**符号（BTF / XDP / kprobe / bpf 事件）。**只开内核，dae 本体以后单独装** |
| [config/packages-store.config](config/packages-store.config) | iStore（`luci-app-store`）及其 kiddin9 依赖 |
| [scripts/set-kernel-size.sh](scripts/set-kernel-size.sh) | 把 `KERNEL_SIZE` 改成 12288k（**本机是 12M 分区表，必须用**） |

---

## 这台机器

| 项 | 值 |
|---|---|
| 机型 | 京东云亚瑟 **AX1800 Pro**，`ipq6018-jdcloud_re-ss-01` |
| SoC | 高通 IPQ6000（qualcommax / ipq60xx），ath11k 无线，NSS 硬件加速 |
| 运存 | **1 GiB（硬改）**；DTS 仍叫 `ipq6018-512m.dtsi`，真实容量由 CDT 决定；`free` 显示 ~878 MiB 正常 |
| eMMC | 30,212,096 扇区 = 14.41 GiB，扇区 512 B |
| 分区表 | GPT；**12M 布局**：`0:HLOS` 12 MiB、rootfs 2 GiB、`p27` 数据盘 11.42 GiB |
| U-Boot | chenxin527 版 `2016.01 (Dec 23 2024)`；网页只有 `/firmware.html`、`/ptable.html`、`/backup.html` 等，**没有** `/img.html`、`/big.html`、`/uimage.html` |

分区细节、设备号换算（`mmcblk0pN` 的 N = 表里 `#` − 1）、偏移、备份恢复命令全在
[device-partitions.md](device-partitions.md)，改动分区前必须先看。

---

## 构建（LibWrt 25.12-nss 底座）

```sh
git clone --depth 1 -b 25.12-nss https://github.com/Living877/LibWrt-X-AX1800.git
cd LibWrt-X-AX1800

./scripts/feeds update -a
./scripts/feeds install -a
# iStore 来自 kiddin9 feed：只装这几个，别整包安装（会顶掉核心包）
./scripts/feeds install -p kiddin9 luci-app-store luci-lib-taskd taskd luci-lib-xterm

# 1) 12M：把内核分区从 6144k 改成 12288k（不执行这步，产物刷不进本机）
sh ax1800/scripts/set-kernel-size.sh

# 2) 设备选择
cat >> .config <<'EOF'
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq60xx=y
CONFIG_TARGET_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=y
EOF

# 3) iStore（要编进固件）
cat ax1800/config/packages-store.config >> .config

# 4) dae：只开内核能力（本体以后另装）
cat ax1800/config/kernel-dae.config >> .config

make defconfig
make download -j8
make -j$(nproc)
```

`kiddin9` feed 需要先加进 `feeds.conf.default`（本仓库已加在最后一行）：

```
src-git kiddin9 https://github.com/kiddin9/op-packages.git
```

放在最后面是有意的：`scripts/feeds` 先装的包会被标记，后面同名包默认跳过，
所以上游 `luci` / `packages` 永远优先，kiddin9 只补它们没有的（iStore、taskd 等）。

产物在 `bin/targets/qualcommax/ipq60xx/`：

- `*squashfs-factory.bin` → U-Boot `/firmware.html`
- `*squashfs-sysupgrade.bin` → LuCI 升级或 `sysupgrade`

**12M 与 6M 不能互刷**；`sysupgrade` 不检查分区边界。

---

## iStore

`luci-app-store` 不在 immortalwrt 主源里，来自 `kiddin9/op-packages`。
依赖：`+curl +tar +libuci-lua +mount-utils +luci-lib-taskd`，
而 `luci-lib-taskd` 又依赖 `+luci-lib-xterm +taskd` —— 这四个包已在
`config/packages-store.config` 里列好。

---

## dae（现在只开内核）

dae 的依赖是 `@HAS_BPF_TOOLCHAIN +@NEED_BPF_TOOLCHAIN`，要求内核带 BTF，并需要 LLVM/BPF 工具链。
本轮只把内核能力打开，`dae` / `luci-app-dae` 本体以后单独安装。

`config/kernel-dae.config` 打开的内核能力：

| 符号 | 作用 |
|---|---|
| `CONFIG_KERNEL_DEBUG_INFO` + `DEBUG_INFO_BTF` | 生成 `/sys/kernel/btf/vmlinux`，dae 的 CO-RE 靠它 |
| `CONFIG_KERNEL_DEBUG_INFO_REDUCED`（显式关掉） | 它 `default y`，而 BTF `depends on !REDUCED`，不关永远选不上 |
| `CONFIG_KERNEL_XDP_SOCKETS` | dae 的 `DEPENDS` 用 `@KERNEL_XDP_SOCKETS` 硬卡 |
| `CONFIG_KERNEL_KPROBES` / `KPROBE_EVENTS` / `BPF_EVENTS` | 观测页与 trace（不开也能跑代理） |

BTF 段在 arm64 上未压缩约 5 MiB、进 FIT 后 +1.5~2 MiB —— **6 MiB 分区放不下，只有 12M 能带 dae**。

以后要装 dae 时，确认两件事：

1. `make defconfig` 后 `CONFIG_HAS_BPF_TOOLCHAIN` 被选中（menuconfig → Advanced configuration → LLVM/BPF 工具链）；
2. 编出来的内核 `.config`（`build_dir/target-*/linux-*/linux-*/.config`）里真的有
   `DEBUG_INFO_BTF=y` 和 `XDP_SOCKETS=y` —— 配置里写了不等于没被 depends 丢掉。

---

## 已知坑

- 路由器系统里没有 `od`、`timeout`、`partx`、`blockdev`、`sgdisk`、`fdisk`；有 `parted`、`blkid`、`mkfs.ext4`
- busybox ash **不认 `$'...'`**
- 双频合一没有 band steering：OpenWrt 原生只做"同名"，智能插座会赖在 2.4G，要引导得装 `luci-app-usteer`
- 跑代理前建议关硬件卸载，否则部分流量绕过 TUN/TPROXY
- **别装 `owut` / `luci-app-attendedsysupgrade`**：ASU 用自己的 ImageBuilder 重建，源码级定制全丢，且 `kmod-qca-nss-ecm` / `kmod-ath11k-ahb` 官方源里没有
- `luci-i18n-*` 是 HIDDEN 符号，直接写 `.config` 会被 `defconfig` 静默丢弃，要在 menuconfig 里勾
- 往 DIY 覆盖层加文件前，先确认该路径没有第二个包在装 —— apk 会因为重复文件归属整轮失败
