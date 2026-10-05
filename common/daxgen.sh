#!/system/bin/sh
# ============================================================
#  DAX 深度调音生成器  (由 x14opt.sh 调用)
#  实测结构 (odm 版 115953 B):
#    profile 0 Dynamic 317   1 Movie 423   2 Music 529
#    3 Custom 635    4-7 Mobility    8 Voice 1165
#    tuning speaker_landscape 1271 / spatilizer_90 1371
#           spatilizer_270 1470 / portrait 1569
# ============================================================

gen_dax(){
  SRC=$1; OUT=$2
  VBG=$3      # virtual-bass overall gain (0-6)
  VBH=$4      # 谐波增益微调 (0-6)
  DLM=$5      # Music 对白增强 (0-16)
  DLD=$6      # Dynamic 对白增强 (0-16)
  SRM=$7      # Music surround-boost (0-100)
  REGS=$8     # 齿音抑制 (0/1)
  MBD=$9      # 低频动态压缩 (0/1)
  VRM=${10}   # Music 虚拟化 (0/1)
  VRB=${11}   # 虚拟化起始频点 (0-20)

  [ -f "$SRC" ] || return 1
  mkdir -p "$(dirname "$OUT")" 2>/dev/null

  awk -v vbg="$VBG" -v vbh="$VBH" -v dlm="$DLM" -v dld="$DLD" \
      -v srm="$SRM" -v regs="$REGS" -v mbd="$MBD" \
      -v vrm="$VRM" -v vrb="$VRB" '
  BEGIN { prof=-1 }
  /^  <profile id=/ {
    if (match($0, /id="[0-9]+"/)) prof = substr($0, RSTART+4, RLENGTH-5) + 0
  }
  prof==2 && /<dialog-enhancer-enable value="false"/ {
    print "        <dialog-enhancer-enable value=\"true\"/>"; next }
  prof==2 && /<dialog-enhancer-amount value=/ {
    printf "        <dialog-enhancer-amount value=\"%d\"/>\n", dlm; next }
  prof==2 && /<surround-boost value="0"/ {
    printf "        <surround-boost value=\"%d\"/>\n", srm; next }
  prof==2 && /<virtualizer-enable value="false"/ {
    if (vrm==1) print "        <virtualizer-enable value=\"true\"/>"
    next }
  prof==2 && /<virtualizer-start-band value=/ {
    printf "        <virtualizer-start-band value=\"%d\"/>\n", vrb; next }
  prof==0 && /<dialog-enhancer-amount value=/ {
    printf "        <dialog-enhancer-amount value=\"%d\"/>\n", dld; next }
  /<virtual-bass-overall-gain value=/ {
    printf "      <virtual-bass-overall-gain value=\"%d\"/>\n", vbg; next }
  /<virtual-bass-harmgains value=/ {
    printf "      <virtual-bass-harmgains value=\"-2080,48,%d,48\"/>\n", 144 + vbh*24; next }
  /<regulator-sibilance-suppress-enable value=/ {
    if (regs==1) print "        <regulator-sibilance-suppress-enable value=\"true\"/>"
    else print "        <regulator-sibilance-suppress-enable value=\"false\"/>"
    next }
  /<bass-mbdrc-enable value=/ {
    if (mbd==1) print "        <bass-mbdrc-enable value=\"true\"/>"
    else print "        <bass-mbdrc-enable value=\"false\"/>"
    next }
  { print }
  ' "$SRC" > "$OUT" 2>/dev/null

  [ -s "$OUT" ] || return 1
  o=$(grep -c '<profile id=' "$OUT" 2>/dev/null)
  c=$(grep -c '</profile>' "$OUT" 2>/dev/null)
  [ "$o" = "$c" ] && [ "$o" -ge 9 ] && return 0
  return 1
}