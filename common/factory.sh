#!/system/bin/sh
# ============================================================
#  原厂基线 (实测值, 2026-10-04 于小米14 houji/pineapple)
#  作用: 即使属性快照被污染, 也能保证还原到真实原厂值
#  这些值取自首次探测时的干净系统状态
# ============================================================

# 杜比 DAP
FACTORY_GEQ="2,2,-1,-1,1,2,3,4,6,7,8,9,11,12,9,7,5,4,1,0"
FACTORY_BASS=2
FACTORY_DIALOG=5
FACTORY_VIRT=12
FACTORY_SPECTRAL=8
FACTORY_DIALOG_EN=1
FACTORY_BASS_EN=1
FACTORY_SPECTRAL_EN=1
FACTORY_VIRT_EN=1

# 播放链硬件
FACTORY_VOL=84
FACTORY_COMP=0
FACTORY_TGAIN=18
FACTORY_BGAIN=18
FACTORY_SOFTCLIP=0
FACTORY_HPH=ULP

# 恢复原厂基线 (不依赖快照)
restore_factory_baseline(){
  RP=/data/adb/ksu/bin/resetprop
  TM=/system/bin/tinymix

  # --- DAP 属性 ---
  "$RP" -n persist.vendor.dolby.dap.param.geq "$FACTORY_GEQ" >/dev/null 2>&1
  "$RP" -n persist.vendor.dolby.bass.boost "$FACTORY_BASS" >/dev/null 2>&1
  "$RP" -n persist.vendor.dolby.dialog.enhancer.amount "$FACTORY_DIALOG" >/dev/null 2>&1
  "$RP" -n persist.vendor.dolby.virtualizer.amount "$FACTORY_VIRT" >/dev/null 2>&1
  "$RP" -n persist.vendor.dolby.spectral.boost "$FACTORY_SPECTRAL" >/dev/null 2>&1
  "$RP" -n persist.vendor.dolby.dialog.enhancer.enable "$FACTORY_DIALOG_EN" >/dev/null 2>&1
  "$RP" -n persist.vendor.dolby.bass.enable "$FACTORY_BASS_EN" >/dev/null 2>&1
  "$RP" -n persist.vendor.dolby.spectral.enable "$FACTORY_SPECTRAL_EN" >/dev/null 2>&1
  "$RP" -n persist.vendor.dolby.virtualizer.enable "$FACTORY_VIRT_EN" >/dev/null 2>&1

  # --- 硬件 ---
  for c in "RX_RX0 Digital Volume" "RX_RX1 Digital Volume" "RX_RX2 Digital Volume" \
           "RX_RX0 Mix Digital Volume" "RX_RX1 Mix Digital Volume" "RX_RX2 Mix Digital Volume"; do
    "$TM" "$c" "$FACTORY_VOL" >/dev/null 2>&1
  done
  "$TM" "RX_COMP1 Switch" "$FACTORY_COMP" >/dev/null 2>&1
  "$TM" "RX_COMP2 Switch" "$FACTORY_COMP" >/dev/null 2>&1
  "$TM" "RX_Softclip Enable" "$FACTORY_SOFTCLIP" >/dev/null 2>&1
  "$TM" "RX_HPH_PWR_MODE" "$FACTORY_HPH" >/dev/null 2>&1
  "$TM" "T AMP PCM Gain" "$FACTORY_TGAIN" >/dev/null 2>&1
  "$TM" "B AMP PCM Gain" "$FACTORY_BGAIN" >/dev/null 2>&1
}