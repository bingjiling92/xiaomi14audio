#!/system/bin/sh
# 卸载: 还原一切
MODDIR=/data/adb/modules/audio_x14_opt
ENG=$MODDIR/common/x14opt.sh
[ -f "$ENG" ] && sh "$ENG" restore

for t in /odm/etc/dolby/dax-default.xml /vendor/etc/dolby/dax-default.xml \
         /odm/etc/dolby/dax-default-spatializer.xml /vendor/etc/dolby/dax-default-spatializer.xml \
         /vendor/etc/audio/sku_pineapple/audio_policy_configuration.xml \
         /vendor/etc/audio_policy_configuration.xml \
         /odm/etc/audio/sku_pineapple/mixer_paths_pineapple_mtp.xml; do
  mount | grep -qF " $t " && umount "$t" 2>/dev/null
done

echo "X14 音频优化 已卸载并还原"