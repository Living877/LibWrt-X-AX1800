#!/bin/sh
# 把 jdcloud_re-ss-01 的内核分区从 6144k 改成 12288k（本机是 12M 分区表，必须改）。
#
# 在源码树根执行：  sh ax1800/scripts/set-kernel-size.sh [6144|12288]
# 默认 12288。
#
# 只改这一个设备块：同一个 ipq60xx.mk 里还有 20 多个机型也用 KERNEL_SIZE，
# 全文替换会把它们一起改掉。
set -eu

KS="${1:-12288}"
case "$KS" in
	6144|12288) ;;
	*) echo "只支持 6144 或 12288（当前 '$KS'）" >&2; exit 1 ;;
esac

IMK=target/linux/qualcommax/image/ipq60xx.mk
[ -f "$IMK" ] || { echo "找不到 $IMK —— 请在 openwrt 源码树根目录执行" >&2; exit 1; }

# 行首是 TAB（define 块内的赋值），用捕获组把缩进留回去；^KERNEL_SIZE 一行都匹配不到
sed -i -E "/^define Device\/jdcloud_re-ss-01$/,/^endef$/s/^([[:space:]]*)KERNEL_SIZE := [0-9]+k$/\1KERNEL_SIZE := ${KS}k/" "$IMK"

got=$(sed -n '/^define Device\/jdcloud_re-ss-01$/,/^endef$/p' "$IMK" \
	| sed -nE 's/^[[:space:]]*KERNEL_SIZE := ([0-9]+)k$/\1/p')
[ "$got" = "$KS" ] || { echo "KERNEL_SIZE 没改成 $KS（块内实际 '$got'）" >&2; exit 1; }

# 光改数字不够：镜像命令必须真的是 pad-to $$(KERNEL_SIZE)，否则写了也不生效
sed -n '/^define Device\/jdcloud_re-ss-01$/,/^endef$/p' "$IMK" \
	| grep -qE 'pad-to \$\$?\(KERNEL_SIZE\)' \
	|| { echo "镜像命令里没有 pad-to \$(KERNEL_SIZE)，改了也不生效" >&2; exit 1; }

echo "[+] KERNEL_SIZE=${KS}k（$((${KS} / 1024)) MiB），设备块内唯一的 KERNEL_SIZE 已确认"
