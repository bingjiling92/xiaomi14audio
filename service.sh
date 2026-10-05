#!/system/bin/sh
# 开机后期: 应用 + 守护 (用户还原后自动退出)
MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=/data/adb/modules/audio_x14_opt
ENG=$MODDIR/common/x14opt.sh
[ -s "$ENG" ] || exit 0
LOG=/data/local/tmp/X14_Audio.log
FLAG=$MODDIR/.restored

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
sleep 15

if [ -f "$FLAG" ]; then
  echo "[$(date '+%m-%d %H:%M:%S')] 存在还原标记, 不自动应用" >> $LOG
  exit 0
fi

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