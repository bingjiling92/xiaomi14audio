#!/system/bin/sh
MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=/data/adb/modules/audio_x14_opt
ENG=$MODDIR/common/x14opt.sh
[ -f "$ENG" ] || exit 0

echo "X14 音频优化 已退出"
if [ "$(grep '^master=' "$MODDIR/x14.conf" 2>/dev/null | cut -d= -f2)" = "0" ]; then
  echo "已关闭优化，保持原厂"
  exit 0
fi

echo "正在还原原厂..."
sh "$ENG" restore
echo "还原完成"