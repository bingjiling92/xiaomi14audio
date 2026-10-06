#!/system/bin/sh
# WebUI 后端
MODDIR=/data/adb/modules/audio_x14_opt
ENG=$MODDIR/common/x14opt.sh
CONF=$MODDIR/x14.conf
[ -s "$ENG" ] || { echo "引擎缺失"; exit 1; }
[ -s "$CONF" ] || { sh "$ENG" init >/dev/null 2>&1; }

KEYS="master daptune bass clarity stage dialog asym t_gain b_gain t_vol b_vol playchain vol comp hph_hifi dax dax_vbass dax_harm dax_dialog dax_dyn dax_surr dax_virt dax_vband dax_sib dax_mbdrc call_on call_fluence mic rec_paths rec_on bt_on usb_on hifi_on lowpower hires"

# V3.3: 取值加 "&" 边界锚定。
# 原写法 .*$k= 是贪婪匹配且没有边界, 而 vol 是 t_vol/b_vol 的子串 ->
# 参数顺序不利时会把 t_vol 的值当成 vol 读走。
QS="&$QUERY_STRING"
cmd=$(echo "$QS" | sed -n 's/.*[&]cmd=\([^&]*\).*/\1/p' | head -1)

case "$cmd" in
  get)
    for k in $KEYS; do
      echo "$k=$(grep "^$k=" "$CONF" 2>/dev/null | head -1 | cut -d= -f2)"
    done
    # 守护状态不在 x14.conf 里, 必须实时查, 否则页面重开永远显示关闭
    pgrep -f 'audio_x14_opt/service.sh' >/dev/null 2>&1 && echo "wdog=1" || echo "wdog=0"
    ;;
  setonly)
    for k in $KEYS; do
      v=$(echo "$QS" | sed -n "s/.*[&]$k=\([^&]*\).*/\1/p" | head -1)
      [ -z "$v" ] && continue
      sh "$ENG" set "$k" "$v" >/dev/null 2>&1
    done
    sh "$ENG" tonly >/dev/null 2>&1
    echo "已保存(仅补写控件, 未重启音频栈)"
    sh "$ENG" status
    ;;
  apply)
    for k in $KEYS; do
      v=$(echo "$QS" | sed -n "s/.*[&]$k=\([^&]*\).*/\1/p" | head -1)
      [ -z "$v" ] && continue
      sh "$ENG" set "$k" "$v" >/dev/null 2>&1
    done
    sh "$ENG" apply >/dev/null 2>&1
    echo "已应用"
    sh "$ENG" status
    ;;
  watchdog)
    # 手动/自动切换: off=守护退出不再自动补写, on=恢复守护
    W=$(echo "$QUERY_STRING" | sed -n 's/.*state=\([^&]*\).*/\1/p' | head -1)
    if [ "$W" = "off" ]; then
      pkill -f 'audio_x14_opt/service.sh' 2>/dev/null
      sleep 1
      echo "守护已关闭 (手动模式)"
    elif [ "$W" = "on" ]; then
      pgrep -f 'audio_x14_opt/service.sh' >/dev/null 2>&1 || {
        # 必须 nohup + 后台, 否则守护的父进程是本次 WebUI 请求,
        # 请求结束即被连带杀掉(实测踩过).
        # PPID=1 表示已成功脱离到 init 下.
        nohup sh "$MODDIR/service.sh" >/dev/null 2>&1 &
        sleep 2
      }
      echo "守护已开启"
    fi
    echo "守护状态: $(pgrep -f 'audio_x14_opt/service.sh' >/dev/null 2>&1 && echo 运行中 || echo 已停止)"
    ;;
  probe)
    sh "$ENG" probe
    ;;
  restore)
    sh "$ENG" restore >/dev/null 2>&1
    echo "已还原原厂"
    sh "$ENG" status
    ;;
  status|*)
    sh "$ENG" status
    ;;
esac