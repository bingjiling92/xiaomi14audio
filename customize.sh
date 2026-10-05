##########################################################################################
# X14 音频优化 V1.0 安装
##########################################################################################
SKIPUNZIP=0

ui_print " "
ui_print "************************************************"
ui_print "   Xiaomi 14 深度音频优化 V1.0"
ui_print "   杜比DAP实时调音 + 播放链硬件优化"
ui_print "************************************************"
ui_print " "

DEVICE=$(getprop ro.product.device)
MODEL=$(getprop ro.product.model)
ui_print "- 设备: $MODEL ($DEVICE)"

case "$DEVICE" in
  houji) ui_print "- 机型校验通过" ;;
  *) ui_print "! 警告: 非小米14(houji)，部分功能可能不适配"; sleep 2 ;;
esac

if [ -f /odm/etc/dolby/dax-default.xml ]; then
  ui_print "- 杜比 DAX 链路已识别"
else
  ui_print "! 未检测到 DAX 路径，将仅使用实时属性层"
fi

if [ -x /system/bin/tinymix ]; then
  ui_print "- tinymix 可用 ($(tinymix 2>/dev/null | grep -c '	') 个控件)"
else
  ui_print "! tinymix 不可用，硬件层将跳过"
fi

set_perm_recursive $MODPATH 0 0 0755 0644
set_perm $MODPATH/service.sh 0 0 0755
set_perm $MODPATH/post-fs-data.sh 0 0 0755
set_perm $MODPATH/action.sh 0 0 0755
set_perm $MODPATH/common/x14opt.sh 0 0 0755

# 冲突检测
for mp in /data/adb/modules/audiox14_v3 /data/adb/modules/k90pm_audio_plus /data/adb/modules/REDMI_K90_Ultra_1115X_Goertek_Acoustic; do
  if [ -d "$mp" ] && [ ! -f "$mp/disable" ]; then
    ui_print "! 检测到冲突模块: $(basename $mp)"
    ui_print "!  两者会争抢音频挂载, 建议禁用"
    sleep 2
  fi
done

ui_print " "
ui_print "- 安装完成, 重启后生效"
ui_print "- 重要: 请在设置中开启【杜比全景声】"
ui_print "- 调音: su -c 'sh /data/adb/modules/audio_x14_opt/common/x14opt.sh status'"
ui_print "- 还原: su -c 'sh /data/adb/modules/audio_x14_opt/common/x14opt.sh restore'"
ui_print " "