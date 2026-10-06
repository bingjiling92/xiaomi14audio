#!/system/bin/sh
# 开机后期: 应用 + 守护 (用户还原后自动退出)
MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=/data/adb/modules/audio_x14_opt
ENG=$MODDIR/common/x14opt.sh
[ -s "$ENG" ] || exit 0
LOG=/data/local/tmp/X14_Audio.log
echo "[$(date '+%m-%d %H:%M:%S')] audio_x14_opt V3.3 守护启动" >> $LOG
FLAG=$MODDIR/.restored

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
sleep 15

if [ -f "$FLAG" ]; then
  echo "[$(date '+%m-%d %H:%M:%S')] 存在还原标记, 不自动应用" >> $LOG
  exit 0
fi

# V3.3: 先把 tinymix 原厂快照补齐。
# 原实现在 post-fs-data 阶段抓, 那时混音器还没就绪 -> tinymix_all.txt 恒为 0 字节。
# 必须放在 apply 之前(apply 会 restart_audio, 控件值会被改写)。
sh "$ENG" snapshot

sh "$ENG" apply

# 守护: 只在 audioserver/dms 被"外部"重启后补写 tinymix.
# 用 tonly 而非 apply —— apply 会调 restart_audio 重启 audioserver,
# 造成 "守护->apply->重启->PID变->守护" 无限反馈环(约43秒一轮).
LAST=""
while :; do
  sleep 20
  [ -f "$FLAG" ] && { echo "[$(date '+%m-%d %H:%M:%S')] 还原标记出现, 守护退出" >> $LOG; exit 0; }
  PID="$(pidof audioserver 2>/dev/null)|$(pidof 'vendor.dolby.hardware.dms@2.0-service' 2>/dev/null)"
  [ -z "$PID" ] && continue
  if [ "$PID" != "$LAST" ]; then
    sleep 8
    sh "$ENG" tonly
    LAST="$PID"
    echo "[$(date '+%m-%d %H:%M:%S')] 音频栈重启, 控件已补写" >> $LOG
  fi
done