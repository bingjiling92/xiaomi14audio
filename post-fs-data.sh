#!/system/bin/sh
# 开机早期: 备份原厂 (只读分区, 需在覆盖前)
MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=/data/adb/modules/audio_x14_opt
ENG=$MODDIR/common/x14opt.sh
[ -f "$ENG" ] || exit 0

# V3.3: 原文是无上限 until 等待。本机有该文件所以没事,
# 但一旦某台机器/某次更新没有它, post-fs-data 会一直挂着(有拖死开机的风险)。
i=0
while [ ! -f /odm/etc/dolby/dax-default.xml ] && [ $i -lt 30 ]; do
  sleep 1
  i=$((i+1))
done
[ -f /odm/etc/dolby/dax-default.xml ] || exit 0
sleep 2

sh "$ENG" init