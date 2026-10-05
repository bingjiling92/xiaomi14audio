#!/system/bin/sh
# ============================================================
#  audio_x14_opt  V3.0  核心引擎  全域音频优化
#  小米14 / houji / pineapple / Android16 / HyperOS3
# ============================================================

MODDIR=/data/adb/modules/audio_x14_opt
[ -d "$MODDIR" ] || MODDIR=${0%/*}
CONF=$MODDIR/x14.conf
BAK=/data/adb/audio_x14_opt_backup
LOG=/data/local/tmp/X14_Audio.log
RP=/data/adb/ksu/bin/resetprop
TM=/system/bin/tinymix
WORK=/data/local/tmp/x14_audio
DAXGEN=$MODDIR/common/daxgen.sh
FACTORY_SH=$MODDIR/common/factory.sh

# ---------- 实测路径 ----------
DAX_ODM=/odm/etc/dolby/dax-default.xml
DAX_VEN=/vendor/etc/dolby/dax-default.xml
DAXSP_ODM=/odm/etc/dolby/dax-default-spatializer.xml
DAXSP_VEN=/vendor/etc/dolby/dax-default-spatializer.xml
POLICY_MAIN=/vendor/etc/audio_policy_configuration.xml
POLICY_SKU=/vendor/etc/audio/sku_pineapple/audio_policy_configuration.xml
POLICY_VOL=/vendor/etc/audio_policy_volumes.xml
VOL_TABLES=/vendor/etc/default_volume_tables.xml
USB_POLICY=/vendor/etc/usb_audio_policy_configuration.xml
# PAL(libar-pal.so) 加载 base + overlay_static + overlay_dynamic
MIXER_BASE=/odm/etc/audio/sku_pineapple/mixer_paths_pineapple_mtp.xml
MIXER_OVL_S=/odm/etc/audio/sku_pineapple/mixer_paths_overlay_static.xml
MIXER_OVL_D=/odm/etc/audio/sku_pineapple/mixer_paths_overlay_dynamic.xml
FX_ODM=/odm/etc/audio/sku_pineapple/audio_effects.xml

ALL_FILES="$DAX_ODM $DAX_VEN $DAXSP_ODM $DAXSP_VEN $POLICY_MAIN $POLICY_SKU $POLICY_VOL $VOL_TABLES $USB_POLICY $MIXER_BASE $MIXER_OVL_S $MIXER_OVL_D $FX_ODM"

# ---------- 日志 ----------
[ -f "$LOG" ] && [ "$(wc -c < "$LOG" 2>/dev/null || echo 0)" -gt 65536 ] 2>/dev/null && { tail -c 32768 "$LOG" > "$LOG.t" 2>/dev/null; mv -f "$LOG.t" "$LOG"; }
log(){ echo "[$(date '+%m-%d %H:%M:%S')] $*" >> "$LOG"; }

check_device(){
  N=$(getprop ro.product.name); D=$(getprop ro.product.device)
  O=$(getprop ro.product.odm.device)
  if [ "$N" = "houji" ] || [ "$D" = "houji" ] || [ "$O" = "houji" ]; then
    log "机型校验通过 sku=$(getprop ro.boot.product.vendor.sku)"; return 0
  fi
  log "机型不匹配"; return 1
}

num(){ case "$1" in ''|*[!0-9]*) echo 0;; *) echo "$1";; esac; }

default_conf(){
  cat <<'EOF'
master=1
daptune=1
bass=62
clarity=58
stage=45
dialog=55
asym=1
t_gain=19
b_gain=18
t_vol=0
b_vol=0
playchain=1
vol=92
comp=1
hph_hifi=0
ampgain=18
volcurve=0
curve_gain=0
call_on=0
call_fluence=0
mic=0
rec_on=0
rec_gain=0
bt_on=0
usb_on=0
hifi_on=0
lowpower=0
dax=0
dax_vbass=33
dax_harm=50
dax_dialog=50
dax_dyn=30
dax_surr=30
dax_virt=1
dax_vband=6
dax_sib=1
dax_mbdrc=1
hires=0
EOF
}

KEYS="master daptune bass clarity stage dialog asym t_gain b_gain t_vol b_vol playchain vol comp hph_hifi ampgain volcurve curve_gain call_on call_fluence mic rec_on rec_gain bt_on usb_on hifi_on lowpower dax dax_vbass dax_harm dax_dialog dax_dyn dax_surr dax_virt dax_vband dax_sib dax_mbdrc hires"
DEFS="master:1 daptune:1 bass:62 clarity:58 stage:45 dialog:55 asym:1 t_gain:19 b_gain:18 t_vol:0 b_vol:0 playchain:1 vol:92 comp:1 hph_hifi:0 ampgain:18 volcurve:0 curve_gain:0 call_on:0 call_fluence:0 mic:0 rec_on:0 rec_gain:0 bt_on:0 usb_on:0 hifi_on:0 lowpower:0 dax:0 dax_vbass:33 dax_harm:50 dax_dialog:50 dax_dyn:30 dax_surr:30 dax_virt:1 dax_vband:6 dax_sib:1 dax_mbdrc:1 hires:0"

ensure_conf(){
  mkdir -p "$MODDIR" 2>/dev/null
  [ -s "$CONF" ] || default_conf > "$CONF" 2>/dev/null
  need=0
  for k in $KEYS; do grep -q "^$k=" "$CONF" 2>/dev/null || need=1; done
  [ "$need" = "0" ] && return 0
  for kv in $DEFS; do
    key=${kv%%:*}; val=${kv##*:}
    grep -q "^$key=" "$CONF" 2>/dev/null || echo "$key=$val" >> "$CONF"
  done
  log "配置已补齐"
}

cfg_get(){ grep "^$1=" "$CONF" 2>/dev/null | head -1 | cut -d= -f2; }
cfg_set(){
  [ -s "$CONF" ] || ensure_conf
  if grep -q "^$1=" "$CONF" 2>/dev/null; then
    sed -i "s|^$1=.*|$1=$2|" "$CONF"
  else
    echo "$1=$2" >> "$CONF"
  fi
}

bak_of(){ echo "$BAK/$(echo "$1" | sed 's|^/||; s|/|_|g')"; }

ensure_backup(){
  mkdir -p "$BAK/props" 2>/dev/null
  for p in $ALL_FILES; do
    [ -f "$p" ] || continue
    b=$(bak_of "$p")
    [ -f "$b" ] || cp -f "$p" "$b" 2>/dev/null
  done
  getprop 2>/dev/null | grep -E '^\[(persist\.vendor\.dolby|persist\.vendor\.audio|persist\.sys\.media_vol|persist\.bluetooth|ro\.config\.(media_vol|vc_call|alarm_vol|system_vol|enable_audio|low_volume|safe_media)|ro\.audio\.|vendor\.audio\.)' > "$BAK/props/raw.txt" 2>/dev/null
  : > "$BAK/props/audio.txt" 2>/dev/null
  while IFS= read -r line; do
    k=$(echo "$line" | cut -d']' -f1 | tr -d '[')
    v=$(getprop "$k" 2>/dev/null)
    [ -n "$k" ] && [ -n "$v" ] && echo "$k=$v" >> "$BAK/props/audio.txt"
  done < "$BAK/props/raw.txt"
  $TM > "$BAK/tinymix_all.txt" 2>/dev/null
  log "备份完成 $(ls -1 $BAK 2>/dev/null | wc -l) 项"
}

prop_set(){ [ -x "$RP" ] && "$RP" -n "$1" "$2" >/dev/null 2>&1; }
ctl_exists(){ $TM 2>/dev/null | grep -qF "$1"; }
set_ctl(){
  ctl_exists "$1" || { log "SKIP $1 不存在"; return 1; }
  $TM "$1" "$2" >/dev/null 2>&1 && log "SET $1=$2 (回读 $($TM "$1" 2>/dev/null))"
}
bind_file(){
  [ -f "$1" ] || { log "源缺失 $1"; return 1; }
  [ -f "$2" ] || { log "目标缺失 $2"; return 1; }
  chcon u:object_r:vendor_configs_file:s0 "$1" 2>/dev/null
  umount "$2" 2>/dev/null
  if mount --bind "$1" "$2" 2>/dev/null; then
    restorecon "$2" 2>/dev/null
    log "bind OK [$3]"
    return 0
  fi
  log "bind FAIL [$3]"
  return 1
}
unbind_all(){
  for t in $ALL_FILES; do
    mount | grep -qF " $t " && { umount "$t" 2>/dev/null; log "umount $t"; }
  done
}

# ============ 1. 杜比 DAP 播放调音 ============
build_geq(){
  B=$(num "$(cfg_get bass)"); C=$(num "$(cfg_get clarity)")
  S=$(num "$(cfg_get stage)"); D=$(num "$(cfg_get dialog)")
  LOW=$(( B * 5 / 100 )); MID=$(( C * 4 / 100 ))
  PRES=$(( C * 3 / 100 )); HGH=$(( S * 3 / 100 )); DLG=$(( D * 3 / 100 ))
  v1=$LOW
  [ "$LOW" -gt 0 ] && v1=$(( LOW - 1 ))
  [ "$v1" -lt 0 ] && v1=0
  v2=$(( 2 + LOW + MID / 2 )); v3=$(( 2 + LOW / 2 )); v4=$(( 1 + MID / 2 ))
  v5=0
  v6=$(( -1 - (5 - PRES) / 3 ))
  v7=$(( -1 - (5 - PRES) / 4 ))
  v8=$(( -1 )); v9=0
  v10=$(( 1 + DLG )); v11=$(( 2 + DLG )); v12=$(( 3 + PRES ))
  v13=$(( 4 + HGH / 2 )); v14=$(( 4 + HGH / 2 )); v15=2
  v16=$(( 3 + HGH )); v17=$(( 5 + HGH )); v18=$(( 5 + HGH ))
  v19=2; v20=0
  echo "$v1,$v2,$v3,$v4,$v5,$v6,$v7,$v8,$v9,$v10,$v11,$v12,$v13,$v14,$v15,$v16,$v17,$v18,$v19,$v20"
}

apply_dap(){
  [ "$(num "$(cfg_get daptune)")" = "0" ] && { log "DAP调音关闭"; return 0; }
  GEQ=$(build_geq)
  B=$(num "$(cfg_get bass)"); D=$(num "$(cfg_get dialog)"); S=$(num "$(cfg_get stage)")
  prop_set persist.vendor.dolby.dap.param.geq "$GEQ"
  log "GEQ=$GEQ"
  prop_set persist.vendor.dolby.dap.param.eq custom
  prop_set persist.vendor.dolby.dap.geq.enable 1
  prop_set persist.vendor.dolby.dap.enabled true
  prop_set persist.vendor.dolby.dap.speaker true
  prop_set persist.vendor.dolby.global.enable 1
  prop_set persist.vendor.audio.effect_global 1
  BB=$(( 2 + B * 4 / 100 )); prop_set persist.vendor.dolby.bass.boost "$BB"; prop_set persist.vendor.dolby.bass.enable 1
  DL=$(( 5 + D * 11 / 100 )); prop_set persist.vendor.dolby.dialog.enhancer.amount "$DL"; prop_set persist.vendor.dolby.dialog.enhancer.enable 1
  VA=$(( 12 + S * 4 / 100 )); [ "$VA" -gt 16 ] && VA=16
  prop_set persist.vendor.dolby.virtualizer.amount "$VA"; prop_set persist.vendor.dolby.virtualizer.enable 1
  SB=$(( 8 + B * 4 / 100 )); [ "$SB" -gt 16 ] && SB=16
  prop_set persist.vendor.dolby.spectral.boost "$SB"; prop_set persist.vendor.dolby.spectral.enable 1
  log "bass=$BB dialog=$DL virt=$VA spectral=$SB"
}

# ============ 2. 非对称扬声器平衡 ============
apply_asym(){
  if [ "$(num "$(cfg_get asym)")" = "0" ]; then
    set_ctl "T AMP PCM Gain" 18; set_ctl "B AMP PCM Gain" 18
    log "非对称关闭 T/B=18"; return 0
  fi
  TG=$(num "$(cfg_get t_gain)"); BG=$(num "$(cfg_get b_gain)")
  TV=$(num "$(cfg_get t_vol)"); BV=$(num "$(cfg_get b_vol)")
  [ "$TG" -gt 20 ] && TG=20
  [ "$BG" -gt 20 ] && BG=20
  set_ctl "T AMP PCM Gain" "$TG"
  set_ctl "B AMP PCM Gain" "$BG"
  log "非对称 T(1014)=$TG B(1115K)=$BG"
  [ "$TV" -ne 0 ] && set_ctl "T Digital PCM Volume" "$TV"
  [ "$BV" -ne 0 ] && set_ctl "B Digital PCM Volume" "$BV"
}

# ============ 3. 播放链硬件层 ============
apply_playchain(){
  [ "$(num "$(cfg_get playchain)")" = "0" ] && { log "播放链关闭"; return 0; }
  V=$(num "$(cfg_get vol)"); [ "$V" -eq 0 ] && V=84
  C=$(num "$(cfg_get comp)"); H=$(num "$(cfg_get hph_hifi)")
  A=$(num "$(cfg_get ampgain)"); [ "$A" -eq 0 ] && A=18
  set_ctl "RX_RX0 Digital Volume" "$V"
  set_ctl "RX_RX1 Digital Volume" "$V"
  set_ctl "RX_RX2 Digital Volume" "$V"
  set_ctl "RX_RX0 Mix Digital Volume" "$V"
  set_ctl "RX_RX1 Mix Digital Volume" "$V"
  set_ctl "RX_RX2 Mix Digital Volume" "$V"
  set_ctl "RX_COMP1 Switch" "$C"
  set_ctl "RX_COMP2 Switch" "$C"
  if [ "$H" = "1" ]; then set_ctl "RX_HPH_PWR_MODE" "LOHIFI"; else set_ctl "RX_HPH_PWR_MODE" "ULP"; fi
  set_ctl "B AMP PCM Gain" "$A"
  set_ctl "T AMP PCM Gain" "$A"
  set_ctl "RX_Softclip Enable" 0
}

# ============ 4. 通话 / 麦克风 ============
apply_call(){
  F=$(num "$(cfg_get call_fluence)")
  ON=false
  [ "$F" = "1" ] && ON=true
  setprop persist.vendor.audio.fluence.voicecall "$ON" 2>/dev/null
  setprop persist.vendor.audio.fluence.speaker "$ON" 2>/dev/null
  setprop persist.vendor.audio.fluence.tmic.enabled "$ON" 2>/dev/null
  setprop persist.vendor.audio.fluence.voicerec "$ON" 2>/dev/null
  log "fluence=$F ($ON)"
}

apply_mic(){
  if [ "$(num "$(cfg_get mic)")" = "0" ]; then
    for f in "$MIXER_BASE" "$MIXER_OVL_S"; do
      mount | grep -qF " $f " && { umount "$f" 2>/dev/null; log "mic bind解除 $f"; }
    done
    return 0
  fi
  mkdir -p "$WORK" 2>/dev/null
  ok=0
  b=$(bak_of "$MIXER_BASE")
  if [ -f "$b" ]; then
    awk '/<path name="handset-dmic-endfire">/ && !d {
      print
      print "        <ctl name=\"TX_AIF1_CAP Mixer DEC3\" value=\"1\" />"
      print "        <ctl name=\"TX DMIC MUX3\" value=\"DMIC2\" />"
      print "    </path>"
      s=1; d=1; next }
      s && /<\/path>/ { s=0; next } s { next }
      { print }' "$b" > "$WORK/mb.xml" 2>/dev/null
    if [ -s "$WORK/mb.xml" ] && grep -q "TX DMIC MUX3" "$WORK/mb.xml" 2>/dev/null; then
      bind_file "$WORK/mb.xml" "$MIXER_BASE" "mixer-base" && ok=1
    fi
  fi
  b2=$(bak_of "$MIXER_OVL_S")
  if [ -f "$b2" ]; then
    awk '/<path name="handset-dmic-endfire">/ && !d {
      print
      print "        <ctl name=\"TX_AIF1_CAP Mixer DEC3\" value=\"1\" />"
      print "        <ctl name=\"TX DMIC MUX3\" value=\"DMIC2\" />"
      print "    </path>"
      s=1; d=1; next }
      s && /<\/path>/ { s=0; next } s { next }
      { print }' "$b2" > "$WORK/mo.xml" 2>/dev/null
    if [ -s "$WORK/mo.xml" ] && grep -q "TX DMIC MUX3" "$WORK/mo.xml" 2>/dev/null; then
      bind_file "$WORK/mo.xml" "$MIXER_OVL_S" "mixer-overlay" && ok=1
    fi
  fi
  [ "$ok" = "1" ] && log "3麦已注入(base+overlay)" || log "3麦注入失败"
}

apply_rec(){
  R=$(num "$(cfg_get rec_gain)")
  [ "$R" -eq 0 ] && return 0
  mkdir -p "$WORK" 2>/dev/null
  ok=0
  for f in "$MIXER_BASE" "$MIXER_OVL_S"; do
    b=$(bak_of "$f"); [ -f "$b" ] || continue
    sed "s|ADC1 Volume\" value=\"[0-9]*\"|ADC1 Volume\" value=\"$R\"|g" "$b" > "$WORK/rec.xml" 2>/dev/null
    [ -s "$WORK/rec.xml" ] && { bind_file "$WORK/rec.xml" "$f" "录音增益"; ok=1; }
  done
  [ "$ok" = "1" ] && log "录音增益=$R"
}

# ============ 5. 蓝牙 / USB / HiFi / 低功耗 ============
apply_bt(){
  [ "$(num "$(cfg_get bt_on)")" = "0" ] && return 0
  prop_set persist.bluetooth.absvolume 1
  prop_set ro.bluetooth.absvolume 1
  prop_set vendor.audio.feature.hifi_audio.enable true
  prop_set vendor.audio.offload.buffer.size.kb 256
  prop_set vendor.audio.offload.multiple.enabled true
  log "蓝牙绝对音量启用"
}
apply_usb(){
  [ "$(num "$(cfg_get usb_on)")" = "0" ] && return 0
  prop_set ro.vendor.audio.soundfx.usb true
  prop_set vendor.audio.feature.usb_offload.enable true
  log "USB音频启用"
}
apply_hifi(){
  [ "$(num "$(cfg_get hifi_on)")" = "0" ] && return 0
  prop_set vendor.audio.offload.gapless.enabled true
  prop_set vendor.audio.flac.sw.decoder.24bit true
  prop_set vendor.audio.use.sw.alac.decoder true
  prop_set ro.vendor.audio.sdk.ssr false
  log "HiFi解码启用"
}
apply_lowpower(){
  [ "$(num "$(cfg_get lowpower)")" = "0" ] && return 0
  prop_set persist.vendor.audio.low_power false
  prop_set persist.vendor.audio_hal.low_power false
  prop_set ro.config.low_volume false
  prop_set persist.vendor.audio.spk.stereo true
  if command -v settings >/dev/null 2>&1; then
    settings put global audio_low_power_mode 0 2>/dev/null
    settings put system audio_low_power_mode 0 2>/dev/null
  fi
  log "低功耗限音解除"
}

# ============ 6. 高阶 (DAX 深度调音 / Hi-Res) ============
# DAX 深度调音: 从原厂备份生成调优版, 注入 /odm + /vendor 双路径
# 参数 (0-100 用户视角, 内部换算到 DAX 原生范围):
#   dax_vbass   虚拟低音强度 0-100 -> overall-gain 0-6
#   dax_harm    低频谐波     0-100 -> harmgains 第3项 144+
#   dax_dialog  Music 对白   0-100 -> 0-16
#   dax_surr    Music 环绕   0-100 -> 0-100
#   dax_virt    Music 虚拟化 0/1
#   dax_vband   虚拟化起始频点 0-20
apply_dax_tune(){
  [ "$(num "$(cfg_get dax)")" = "0" ] && { log "DAX调音关闭"; return 0; }
  [ -s "$DAXGEN" ] || { log "缺 daxgen.sh"; return 1; }
  sb=$(bak_of "$DAX_ODM"); [ -f "$sb" ] || { log "缺 DAX 备份"; return 1; }
  mkdir -p "$WORK" 2>/dev/null

  VBG=$(num "$(cfg_get dax_vbass)");  VBG=$(( VBG * 6 / 100 ))
  VBH=$(num "$(cfg_get dax_harm)");   VBH=$(( VBH * 6 / 100 ))
  DLM=$(num "$(cfg_get dax_dialog)"); DLM=$(( DLM * 16 / 100 ))
  DLD=$(num "$(cfg_get dax_dyn)");   DLD=$(( DLD * 16 / 100 ))
  SRM=$(num "$(cfg_get dax_surr)")
  VRM=$(num "$(cfg_get dax_virt)");  VRB=$(num "$(cfg_get dax_vband)")
  REGS=$(num "$(cfg_get dax_sib)");  MBD=$(num "$(cfg_get dax_mbdrc)")

  . "$DAXGEN"
  if gen_dax "$sb" "$WORK/dax_odm.xml" "$VBG" "$VBH" "$DLM" "$DLD" "$SRM" "$REGS" "$MBD" "$VRM" "$VRB"; then
    log "DAX(odm)生成 vbg=$VBG vbh=$VBH dlm=$DLM dld=$DLD srm=$SRM sib=$REGS mbd=$MBD vrm=$VRM vrb=$VRB"
    bind_file "$WORK/dax_odm.xml" "$DAX_ODM" "DAX-odm"
  else
    log "DAX(odm)生成失败"
  fi
  # vendor 版结构不同(较小), 同样生成但只改存在的键
  vb=$(bak_of "$DAX_VEN")
  if [ -f "$vb" ]; then
    . "$DAXGEN"
    if gen_dax "$vb" "$WORK/dax_ven.xml" "$VBG" "$VBH" "$DLM" "$DLD" "$SRM" "$REGS" "$MBD" "$VRM" "$VRB"; then
      bind_file "$WORK/dax_ven.xml" "$DAX_VEN" "DAX-vendor"
    else
      log "DAX(vendor)生成失败"
    fi
  fi
  # DAX 生效需要 dms 重启, 由 restart_audio 处理
}
apply_hires(){
  [ "$(num "$(cfg_get hires)")" = "0" ] && return 0
  mkdir -p "$WORK" 2>/dev/null
  for src in "$POLICY_SKU" "$POLICY_MAIN"; do
    b=$(bak_of "$src"); [ -f "$b" ] || continue
    awk '/<mixPort name="deep_buffer"/ { i=1 }
      i && /samplingRates="48000"/ && !d { sub(/samplingRates="48000"/, "samplingRates=\"48000 96000\""); d=1 }
      i && /samplingRates="44100 48000"/ && !d { sub(/samplingRates="44100 48000"/, "samplingRates=\"44100 48000 96000\""); d=1 }
      /<\/mixPort>/ && i { i=0 }
      { print }' "$b" > "$WORK/hires.xml" 2>/dev/null
    [ -s "$WORK/hires.xml" ] && bind_file "$WORK/hires.xml" "$src" "HiRes"
  done
}

restart_audio(){
  setprop ctl.restart audioserver 2>/dev/null
  sleep 3
  P=$(pidof "vendor.dolby.hardware.dms@2.0-service" 2>/dev/null)
  [ -n "$P" ] && { kill -9 "$P" 2>/dev/null; sleep 1; }
}

# 只重写 tinymix 控件, 不 bind / 不重启音频栈.
# 供守护进程使用: audioserver 被外部重启后控件会被 HAL 重置,
# 此时只需补写控件, 绝不能再调 restart_audio, 否则形成
# "守护->apply->重启->PID变->守护" 的无限反馈环.
tinymix_only(){
  check_device || return 0
  ensure_conf
  [ "$(num "$(cfg_get master)")" = "0" ] && { log "master=0, tinymix-only 跳过"; return 0; }
  [ -f "$MODDIR/.restored" ] && { log "已还原, tinymix-only 跳过"; return 0; }
  log "tinymix-only: 补写控件"
  apply_dap
  apply_playchain
  apply_asym
  [ "$(num "$(cfg_get call_on)")" = "1" ] && apply_call
  reassert_tinymix
  log "tinymix-only 完成"
}

# tinymix 值会在 HAL 重载 mixer_paths 后被覆盖,
# 因此最后做一次"校验 + 重写", 最多 3 轮
reassert_tinymix(){
  V=$(num "$(cfg_get vol)"); [ "$V" -eq 0 ] && V=84
  A=$(num "$(cfg_get ampgain)"); [ "$A" -eq 0 ] && A=18
  TG=18; BG=18
  [ "$(num "$(cfg_get asym)")" = "1" ] && { TG=$(num "$(cfg_get t_gain)"); BG=$(num "$(cfg_get b_gain)"); }
  C=$(num "$(cfg_get comp)")
  r=0
  while [ $r -lt 3 ]; do
    r=$((r+1))
    sleep 3
    cur=$(tinymix "RX_RX0 Digital Volume" 2>/dev/null | sed 's|.*: \([0-9]*\).*|\1|')
    [ "$cur" = "$V" ] || { log "重写 vol $cur->$V"; set_ctl "RX_RX0 Digital Volume" "$V"; set_ctl "RX_RX1 Digital Volume" "$V"; set_ctl "RX_RX2 Digital Volume" "$V"; }
    cur=$(tinymix "T AMP PCM Gain" 2>/dev/null | sed 's|.*: \([0-9]*\).*|\1|')
    [ "$cur" = "$TG" ] || { log "重写 T $cur->$TG"; set_ctl "T AMP PCM Gain" "$TG"; }
    cur=$(tinymix "B AMP PCM Gain" 2>/dev/null | sed 's|.*: \([0-9]*\).*|\1|')
    [ "$cur" = "$BG" ] || { log "重写 B $cur->$BG"; set_ctl "B AMP PCM Gain" "$BG"; }
    cur=$(tinymix "RX_COMP1 Switch" 2>/dev/null)
    case "$cur" in *On*) ;; *) set_ctl "RX_COMP1 Switch" "$C"; set_ctl "RX_COMP2 Switch" "$C";; esac
  done
}

apply_all(){
  check_device || exit 0
  ensure_conf
  rm -f "$MODDIR/.restored" 2>/dev/null
  [ "$(num "$(cfg_get master)")" = "0" ] && { log "master=0"; return 0; }
  # 先挂载/属性, 再重启音频栈, 最后重写 tinymix
  # 原因: audio HAL 启动时会重载 mixer_paths, 覆盖之前的 tinymix 值
  apply_hires
  apply_dax_tune
  apply_mic
  [ "$(num "$(cfg_get rec_on)")" = "1" ] && apply_rec
  apply_bt
  apply_usb
  apply_hifi
  apply_lowpower
  restart_audio
  apply_dap
  apply_playchain
  apply_asym
  [ "$(num "$(cfg_get call_on)")" = "1" ] && apply_call
  reassert_tinymix
  log "=== 全域应用完成 ==="
}

restore_all(){
  log ">>> 全域还原 <<<"
  # 先停守护, 解除挂载
  touch "$MODDIR/.restored" 2>/dev/null
  unbind_all
  # 权威还原: 使用硬编码原厂基线 (不依赖可能被污染的快照)
  if [ -s "$FACTORY_SH" ]; then
    . "$FACTORY_SH"
    restore_factory_baseline
    log "原厂基线已写入"
  fi
  # 补充: 快照里其余音频属性
  if [ -f "$BAK/props/audio.txt" ]; then
    while IFS= read -r line; do
      k=${line%%=*}; v=${line#*=}
      [ "$k" = "$line" ] && continue
      [ -n "$k" ] && [ -n "$v" ] && prop_set "$k" "$v"
    done < "$BAK/props/audio.txt"
    log "属性已还原"
  else
    log "警告: 无属性快照"
  fi
  # 先重启让原厂 mixer 生效, 再回写 tinymix 快照
  restart_audio
  if [ -f "$BAK/tinymix_all.txt" ]; then
    while IFS='	' read -r id type cnum name rest; do
      [ "$id" = "ctl" ] && continue
      [ -z "$name" ] && continue
      v=""
      case "$type" in
        BOOL) v=$(echo "$rest" | tr -d ' ') ;;
        INT)  v=$(echo "$rest" | awk '{print $1}') ;;
      esac
      [ -n "$v" ] && $TM "$name" "$v" >/dev/null 2>&1
    done < "$BAK/tinymix_all.txt"
    # 再校验一轮, 防止 HAL 重载覆盖
    sleep 3
    while IFS='	' read -r id type cnum name rest; do
      [ "$id" = "ctl" ] && continue
      [ -z "$name" ] && continue
      v=""
      case "$type" in
        BOOL) v=$(echo "$rest" | tr -d ' ') ;;
        INT)  v=$(echo "$rest" | awk '{print $1}') ;;
      esac
      [ -n "$v" ] && $TM "$name" "$v" >/dev/null 2>&1
    done < "$BAK/tinymix_all.txt"
    log "tinymix已还原"
  fi
  # 最终确认: 再写一次原厂基线, 防止 HAL 重载覆盖
  sleep 2
  if [ -s "$FACTORY_SH" ]; then
    . "$FACTORY_SH"
    restore_factory_baseline
    log "原厂基线二次确认"
  fi
  log "还原完成"
}

status(){
  echo "══════ X14 Audio V3.0 ══════"
  echo "设备: $(getprop ro.product.model) / $(getprop ro.boot.product.vendor.sku)"
  echo ""
  echo "[1] 杜比 DAP"
  for p in persist.vendor.dolby.dap.param.geq persist.vendor.dolby.bass.boost \
           persist.vendor.dolby.dialog.enhancer.amount persist.vendor.dolby.virtualizer.amount \
           persist.vendor.dolby.spectral.boost; do
    echo "  $p = $(getprop $p)"
  done
  echo ""
  echo "[2] 非对称扬声器"
  echo "  顶部1014 : $($TM 'T AMP PCM Gain' 2>/dev/null | cut -d: -f2)"
  echo "  底部1115K: $($TM 'B AMP PCM Gain' 2>/dev/null | cut -d: -f2)"
  echo ""
  echo "[3] 播放链"
  echo "  $($TM 'RX_RX0 Digital Volume' 2>/dev/null)"
  echo "  $($TM 'RX_COMP1 Switch' 2>/dev/null)"
  echo "  $($TM 'RX_HPH_PWR_MODE' 2>/dev/null)"
  echo ""
  echo "[4] bind 挂载]"
  M=$(mount | grep -E 'dax-default|audio_policy|volumes|mixer_paths|audio_effects')
  [ -n "$M" ] && echo "$M" | sed 's/^/  /' | head -10 || echo "  (无)"
  echo ""
  echo "[5] 进程"
  echo "  audioserver=$(pidof audioserver) dms=$(pidof 'vendor.dolby.hardware.dms@2.0-service')"
  echo ""
  echo "[6] 配置"
  grep -vE '^\s*#|^\s*$' "$CONF" 2>/dev/null | sed 's/^/  /'
}

case "$1" in
  init)    check_device && ensure_backup ;;
  apply)   apply_all ;;
  restore) restore_all ;;
  status)  status ;;
  set)
    check_device || exit 0
    cfg_set "$2" "$3"
    # 立即生效: 音量/增益类走 tonly 秒级生效且不重启音频栈.
    # DAX 类参数只写配置, 需 tonly/apply 才会重新生成 DAX 文件.
    case "$2" in
      dax|dax_*|mic|rec_on|bt_on|usb_on|hifi_on|lowpower|hires|call_on|call_fluence)
        echo "已保存 $2=$3 (该层需按「完整应用」生效)" ;;
      *)
        tinymix_only >/dev/null 2>&1
        echo "已保存并生效 $2=$3" ;;
    esac
    ;;
  geq)     build_geq ;;
  tonly)   tinymix_only ;;
  *) echo "用法: x14opt {init|apply|restore|status|set K V|geq|tonly}" ;;
esac