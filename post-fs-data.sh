#!/system/bin/sh
# 开机早期: 备份原厂 (只读分区, 需在覆盖前)
MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=/data/adb/modules/audio_x14_opt
ENG=$MODDIR/common/x14opt.sh
[ -f "$ENG" ] || exit 0

until [ -f /odm/etc/dolby/dax-default.xml ]; do sleep 1; done
sleep 2

sh "$ENG" init