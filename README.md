# 小米14 全域音频优化 (Xiaomi 14 Audio Optimization)

针对 **小米 14 (houji / pineapple)** 的 KernelSU 音频调优模块。

七层可独立开关的调音能力，核心是针对小米14 **非对称分频硬件**的深度适配 —— 顶部小高音单元与底部大低音单元分别由独立功放驱动，必须分别控制增益才能得到平衡的听感。

> 作者：[bingjiling92](https://github.com/bingjiling92)
> 许可：MIT + 附加署名要求（允许二改，但必须保留原作者署名）
> 适配：小米14 / Android 16 / 澎湃OS 3 / KernelSU
> 当前版本：**V3.3**（改动见 [V3.3 修复了什么](#v33-修复了什么全部为实机复现)）

---

## 适配机型

| 项目 | 参数 |
|---|---|
| 机型 | 小米14 |
| 代号 | `houji` / SKU `pineapple` |
| 系统 | Android 16 / 澎湃OS 3 |
| root 方案 | KernelSU |

**扬声器硬件（非对称分频）**

```
顶部:  AAC 1014 小高音单元（瑞声科技），同时兼任听筒
      由独立 TF/TB 功放驱动
底部:  2 x AAC 1115K 低音单元（同 13/14Pro）
```

**麦克风（4 麦）**
```
top-mic / main-mic / bot-main-mic / bot-aux-mic
```

> ⚠️ 模块内置机型校验，非 `pineapple` SKU 会拒绝安装。

---

## 七层功能

| # | 层 | 默认 | 说明 |
|---|---|---|---|
| 1 | 杜比 DAP 实时调音 | 开 | 20 段 GEQ + 低音/清晰度/声场/对白 4 项增强，全局生效 |
| 2 | 非对称扬声器平衡 | 开 | 顶部 / 底部独立功放增益补偿 |
| 3 | 播放链硬件层 | 开 | RX 数字音量 / 动态压缩 / 功放增益 |
| 4 | DAX 深层调音 | 关 | 9 项参数，动态生成 DAX 调音文件（开启后需「完整应用」） |
| 5 | 3 麦通话阵列 | 关 | 原厂 2 麦 **追加** 第 3 路；V3.2 曾误实现为「替换」使听筒变单麦，见陷阱 9 |
| 6 | 外接解码 | 关 | 蓝牙绝对音量 / USB / HiFi / 解除限音 |
| 7 | Hi-Res 96kHz | 关 | 采样率提升至 96000Hz |

### 1. 杜比 DAP 实时调音

走杜比算法，作用于所有 App。

| 参数 | 范围 | 建议 |
|---|---|---|
| 低音 | 0-100 | 60-65 丰满 / 50 接近原厂 |
| 清晰度 | 0-100 | 55-60 听歌人声清楚 |
| 声场 | 0-100 | 40-50 日常舒适 |
| 对白 | 0-100 | 50-60 看视频人声突出 |

> ⚠️ **与 MIUI 自带均衡器冲突**
> 两者共用同一系统属性 `persist.vendor.dolby.dap.param.geq`
> 同时调整会互相覆盖，建议只使用本模块。

### 2. 非对称扬声器平衡

**这是本模块与通用调音模块的核心区别。**

小米14 的顶部与底部是两套独立单元 + 独立功放，原厂把两边增益都设为 18，但顶部小单元实际偏弱。不做补偿会导致听感闷、或底部破音。

| 参数 | 范围 | 原厂 | 默认 |
|---|---|---|---|
| 顶部 1014 | 0-20 | 18 | **19** |
| 底部 1115K | 0-20 | 18 | 18 |

> 调节建议：一次只改 1 格，改完等 2 秒再判断。
> 觉得闷 → 顶部加到 20；觉得刺耳 → 底部减到 17。

### 3. 播放链硬件层

在 HAL 层直接控制硬件音量，绕过系统音量策略。

| 参数 | 范围 | 原厂 | 默认 |
|---|---|---|---|
| 数字音量 | 0-124 | 84 | **92** |
| 功放增益 | 0-20 | 18 | 18 |
| 动态压缩 | 开/关 | 关 | **开** |
| 听筒 LOHIFI | 开/关 | 关 | 关 |

> 数字音量不建议超过 100，超过后音质会劣化。

### 4. DAX 深层调音

直接改写杜比 DAX 调音文件，效果最细腻。

| 参数 | 作用 |
|---|---|
| 虚拟低音 | 低频下潜感 |
| 低频谐波 | 低音泛音厚度 |
| 人声 Music | 音乐模式人声突出 |
| 动态人声 | 人声动态范围 |
| 空间感 | 环绕 / 空间感强度 |
| 虚拟化 | Music 模式虚拟声场开关 |

> 单项建议不超过 60，容易失真。
> 本层需重写文件并重载服务，生效约需 2 秒。

### 5. 3 麦通话阵列

原厂通话只启用 2 路数字麦（`handset-dmic-endfire` = 顶部 DMIC1 + 底部 DMIC3 双麦降噪），开启后**追加**第 3 路（`DEC3` + `DMIC MUX3 = DMIC2`）。

> ⚠️ 必须**同时注入** `mixer_paths_pineapple_mtp.xml` 与
> `mixer_paths_overlay_static.xml`。原因见下方「已知陷阱」第 1 条。
>
> ⚠️ **本机 4 麦的物理通道**（从 mixer_paths 反推）：`dmic1→DMIC0`、`dmic2→DMIC1`、`dmic3→DMIC2`、`dmic4→DMIC3`。
> 而 4 麦的 AEC / beamforming 由 DSP 的 voice 拓扑决定，**不通过 mixer_paths 暴露**，本模块管不到 ——
> 这一层能做的只是让通话上行多一路原始数字麦。
>
> ⚠️ V3.3 起默认**关闭**。它确实会改变通话上行链路，请先在安静环境试一次通话再决定是否长期开启。
> 生成后模块会回读校验：若路径内 ctl 条数 < 3（说明原厂内容被丢弃）则判定失败、不挂载。

### 6-7. 外接解码 / Hi-Res

默认关闭，按需开启。解除限音与 Hi-Res 会增加耗电。

---

## 安装

1. 下载 `Xiaomi14全域音频优化_V3.3.zip`
2. KernelSU → 模块 → 安装模块 → 选择该ZIP
3. 重启手机
4. 开机约 15 秒后生效（属正常延迟）
5. 3 麦 / DAX / Hi-Res 默认关闭，需要时在 WebUI 里打开

---

## WebUI

KernelSU 模块页点击 WebUI 打开。

界面特性：
- 多层径向渐变彩色背景
- `backdrop-filter` 毛玻璃卡片
- 渐变小块按钮、滑动开关
- 分组联动（关闭某层时该层控件自动置灰不可调）

**按钮语义**

| 按钮 | 作用 | 耗时 |
|---|---|---|
| 完整应用 | 重挂文件 + 重启音频栈 + 应用全部参数 | 约 2 秒，声音短暂停顿 |
| 仅保存参数 | 保存配置 + 只重写 tinymix 控件 | 秒级，声音不中断 |
| 读取 | 从配置文件拉取当前值 | — |
| 状态 | 查看实时生效情况 | — |
| 还原 | 回原厂 + 停止守护 | — |

> 还原后守护自动退出，重启手机也不会自动应用，需手动重开守护开关。

---

## 参数持久化

所有参数保存在 `x14.conf`。

```
WebUI 拖滑块 / 切开关
   ├─→ 立即写入 x14.conf（持久保存，重启不丢）
   ├─→ 音量/增益类参数立即生效（秒级）
   └─→ DAX 类参数提示需「完整应用」

守护运行期间，音频栈被系统或第三方 App 重启后，
守护会按 x14.conf 自动补写你设定的值。
```

**手动修改的参数不会被覆盖，它们就是最终值。**

命令行同样支持（音量/增益类秒级生效）：

```bash
su -c 'sh /data/adb/modules/audio_x14_opt/common/x14opt.sh set t_gain 20'
```

---

## 命令参考

| 操作 | 命令 |
|---|---|
| 状态 | `su -c 'sh .../common/x14opt.sh status'` |
| 改参数 | `su -c 'sh .../common/x14opt.sh set t_gain 20'` |
| 仅补写控件 | `su -c 'sh .../common/x14opt.sh tonly'` |
| 完整应用 | `su -c 'sh .../common/x14opt.sh apply'` |
| 还原原厂 | `su -c 'sh .../common/x14opt.sh restore'` |
| 预览 GEQ | `su -c 'sh .../common/x14opt.sh geq'` |
| 硬件能力自检 | `su -c 'sh .../common/x14opt.sh probe'` |
| 补 tinymix 快照 | `su -c 'sh .../common/x14opt.sh snapshot'` |
| 守护状态 | `su -c 'pgrep -f audio_x14_opt/service.sh'` |

> 路径前缀：`/data/adb/modules/audio_x14_opt`

---

## 调音建议路线

```
第1步  只开「非对称平衡」+「播放链」，听原厂与模块的差别
第2步  调顶部/底部增益，找到不闷不破的平衡点
第3步  调数字音量到你听着够响的上限（不超 100）
第4步  加「杜比DAP」，先只调「对白」，看视频验证
第5步  再调「低音」「清晰度」，每次只动一项
第6步  最后才碰「DAX 深层调音」，这层最精细也最易失真
```

> 每次改动后等 2 秒再判断，不要连续快速调整。

---

## V3.3 修复了什么（全部为实机复现）

V3.2 有 7 处问题，其中第 1 条会真实损坏通话链路。它们的共同点是**静态读代码看不出来，只有实机 diff 才能暴露**。

| # | 问题 | 实测证据 | 修复 |
|---|---|---|---|
| 1 | 「3 麦注入」实为**替换** | 挂载后与原厂备份 diff：base 4 条 ctl → 2 条、overlay 18 条 → 2 条；听筒通话被改成单麦 DMIC2，日志却写「3麦已注入」 | 改为真正追加（原厂 DMIC1+DMIC3 保留，追加 DEC3/DMIC2），生成后回读校验 ctl 条数 ≥ 3，不达标即判失败不挂载 |
| 2 | tinymix 原厂快照恒为 **0 字节** | `tinymix_all.txt` = 0 字节，而同一条 `tinymix` 手工执行有 525 个控件 / 49KB | 快照改到开机后、`apply` 之前由 `service.sh` 调 `snapshot` 补齐 |
| 3 | 录音增益连坐通话路径 | `ADC1 Volume` 在本机出现在 9~10 处 path 中，含 `handset-tmic-endfire`／`speaker-dmic-endfire`／`va-mic-*` | 新增 `rec_paths`（默认 `recorder\|camcorder`），只手录音路径 |
| 4 | `apply_rec` 会覆盖 `apply_mic` | 两者 bind 同一目标文件，后跑者胜 | 合并为一次生成：`build_mixer_file` → `apply_mixer` |
| 5 | fluence 用普通 `setprop` 会污染原厂快照 | `persist.*` 会落盘，下次开机快照就把改过的值当原厂存下 | 统一改 `resetprop -n`（不落盘，重启即回原厂） |
| 6 | 原厂基线不全 | `factory.sh` 只覆盖 9 个 DAP 键，另 6 个只靠可能被污染的快照还原 | 按首次干净快照补齐硬编码基线 |
| 7 | `post-fs-data` 无上限等待 | `until [ -f .../dax-default.xml ]; do sleep 1; done`，缺文件会把启动挂住 | 最多等 30s，超时跳过 |

另有两处取参/追加缺陷：WebUI 用贪婪 `sed` 取值而 `vol` 是 `t_vol`/`b_vol` 的子串（实测 `vol=92&t_vol=0` 旧版把 `vol` 读成 `0`），已加 `&` 边界锚定；配置文件无结尾换行时追加会把两行粘连，已加加固。

---

## 硬件能力自检（V3.3 起）

```bash
su -c 'sh /data/adb/modules/audio_x14_opt/common/x14opt.sh probe'
```

报告写入 `/data/adb/modules/audio_x14_opt/capabilities.txt`，全部是**本机实测**而非假设：tinymix 是否可用与控件总数、每一层所需控件是否存在＋当前值与取值范围、13 个挂载目标文件是否齐全、原厂备份与快照的可逆性、麦克风拓扑，以及「哪些项在硬件上被验证过」。改参数前先跑一次，能避免把效果建立在并不存在的硬件能力上。

---

## 已知陷阱（开发过程中实测踩坑记录）

以下问题**只有实机才能暴露**，静态分析无法发现。记录于此供二次开发者参考。

### 1. mixer_paths_overlay_static 会覆盖 base

`libar-pal.so`（Qualcomm PAL）按 `mixer_paths` → `mixer_paths_overlay_static` → `mixer_paths_overlay_dynamic` 顺序加载。**overlay 中同名 path 会覆盖 base 的定义**。

本机 `handset-dmic-endfire` 在 base 与 overlay 中内容完全不同（overlay 走 ADC 模拟麦，base 走 DMIC数字麦）。因此 3 麦注入必须**双文件同时改**，只改一个不生效。

### 2. audio HAL 重载会清掉 tinymix

`setprop ctl.restart audioserver` 后 HAL 重新解析 mixer_paths，会重置全部控件。

应用顺序必须是：
```
挂载 / 设置属性  →  重启音频栈  →  重写 tinymix
```
并在最后追加 `reassert_tinymix` 做校验重写（3 轮）。

### 3. 守护与 apply 会形成无限反馈环

**症状**：音频栈每 43 秒自动重启一次，声音断续耗电。

**原因**：`service.sh` 检测到 audioserver PID 变化后调用 `apply`，而 `apply` 内部的 `restart_audio()` 会 `setprop ctl.restart audioserver` 重启 audioserver —— 于是 PID 再变，守护再 apply，形成无限循环。

43 秒 = 守护 `sleep 20` + 触发后 `sleep 8` + apply 自身约 15 秒。

**解法**：新增 `tonly` 模式 —— 只重写 tinymix 控件，不 bind、不重启音频栈。守护改调 `tonly`，环被切断。

### 4. 守护进程 PPID 依赖

手动或通过 WebUI 拉起守护时，若父进程是调用方，**调用方结束后守护会被连带杀死**，表现为参数莫名掉回原厂。

必须用 `nohup` 启动，确认 `PPID=1` 挂到 init 下。

### 5. KernelSU WebUI 无法用 XHR / fetch 通信

**KernelSU 不提供 HTTP 服务端**（实测无监听端口，`ksud` 无 `webui` 子命令）。WebView 内 `fetch` 与 `XMLHttpRequest` 都无法执行后端脚本。

必须使用 KernelSU 注入的接口：

```javascript
// 回调收到 {errno, stdout, stderr}
window.ksu.exec(command, callbackName)
```

参数建议走环境变量，避免多层引号转义：

```bash
QUERY_STRING='...' sh /path/to/webroot/run.sh
```

### 6. 守护状态不在配置文件里

守护是运行时状态，不在 `x14.conf` 中，WebUI 无法获知真实值，导致开关重开页面后总显示关闭。

解法：后端 `get` 命令额外返回 `wdog` 字段，实时 `pgrep` 查询进程。

### 7. 属性快照可能被污染

若在调音后才备份，备份会把「已调好的值」当作原厂基线。

解法：`common/factory.sh` 硬编码原厂基线真值，`restore` 不依赖任何快照。

### 8. 写入操作可能静默截断

曾出现脚本文件被静默截断为 0 字节、而空脚本 `exit 0` 造成「假成功」的情况。

**每次写入后必须校验字节数。**

---

### 9. awk 写「注入」很容易变成「替换」

V3.2 的写法：匹配到起始标签 → 打印注入行 → **立刻补 `</path>` 并置标志位跳过原内容**，于是原厂内容被整段丢弃：

```
base    handset-dmic-endfire:  4 条 ctl -> 2 条
overlay handset-dmic-endfire: 18 条 ctl -> 2 条
```

又因为 overlay 覆盖 base，最终生效的是那份 2 条的版本 —— 听筒通话从「双麦降噪」变成「单麦 DMIC2」。

**教训**：往 XML 插行的脚本必须**生成后回读校验原内容仍在**（本模块校验路径内 ctl 条数 ≥ 3），不能只看注入有没有"成功"。

### 10. post-fs-data 阶段抓不到 tinymix

`post-fs-data` 时音频混音器尚未注册，`tinymix` 输出为空但退出码为 0，重定向后就是一个 **0 字节文件** —— 看起来"备份成功"，实际是空的。

**教训**：依赖混音器的快照必须放到 `sys.boot_completed` 之后，且在任何写入之前。

### 11. 配置文件没有结尾换行时，追加会粘连

`echo "KEY=VAL" >> conf` 在文件结尾没有换行时会把新键接到最后一行上（本机实测把 `THERM_HYST=2` 与 `TXQ_ENABLE=1` 粘成一行）。

**教训**：追加前先补换行，判据 `[ "$(tail -c1 f | wc -l)" = "0" ]`。

### 12. 普通 setprop 会污染「原厂快照」

`persist.*` 用普通 `setprop` 会落盘。下次开机若再抓快照，抓到的就是"被改过的值"，`restore` 便不再干净。

**教训**：运行期调音属性一律走 `resetprop -n`（不落盘），重启即回原厂。

### 13. WebUI 取参：贪婪匹配撞子串

`sed 's/.*$k=\([^&]*\)/\1/'` 有两个坑：`.*` 贪婪，且 `vol` 是 `t_vol`／`b_vol` 的子串。参数顺序一变就读错值（实测 `vol=92&t_vol=0` 把 `vol` 读成 `0`）。

**教训**：取值加分隔符边界（`[&]`）或直接做成键值表解析。

---

## 实测参数速查

```
tinymix 位置      /system/bin/tinymix
                  输出 529 行(含 4 行表头) => 实际 525 个控件
RX_RX0/1/2 Digital Volume     0 -> 124   原厂 84
RX_RX0/1/2 Mix Digital Volume 0 -> 124   原厂 84
RX_COMP1/2 Switch             动态压缩    原厂关
RX_Softclip Enable
RX_HPH_PWR_MODE               枚举 ULP / LOHIFI   (hph_hifi=1 才写 LOHIFI)
T AMP PCM Gain                0 -> 20     原厂 18
B AMP PCM Gain                0 -> 20     原厂 18
T/B Digital PCM Volume        0 -> 913    原厂 817  (模块未动用, 默认 0=不碰)
ADC1 Volume                   0 -> 20     原厂 6    (模拟麦增益, 通话/录音共用)
TX_AIF1_CAP Mixer DEC0~DEC7   存在
TX DMIC MUX0~MUX7             可选 ZERO / DMIC0..DMIC7
RX_HPH_PWR_MODE / ADC1 等均实测存在

麦克风拓扑(从 mixer_paths 反推, 物理 4 麦):
  dmic1→DMIC0   dmic2→DMIC1   dmic3→DMIC2   dmic4→DMIC3
  handset-dmic-endfire 原厂 = DEC1/MUX1=DMIC1(顶部) + DEC2/MUX2=DMIC3(底部)
  => 「第三路麦」= 追加 DEC3 + DMIC MUX3 = DMIC2

杜比服务        vendor.dolby.hardware.dms@2.0-service
加载的 policy   /vendor/etc/audio/sku_pineapple/audio_policy_configuration.xml
```

**原厂基线真值（用于精确还原）**

```
geq    = 2,2,-1,-1,1,2,3,4,6,7,8,9,11,12,9,7,5,4,1,0
bass   = 2    dialog = 5    virt = 12    spectral = 8
vol    = 84   COMP   = 0    TGAIN  = 18   BGAIN = 18
DAX 原厂 md5   = 03e00031226a03d3  (odm 版)
```

---

## 文件结构

```
common/x14opt.sh     主引擎：七层应用逻辑
common/daxgen.sh     DAX 调音文件生成器 (awk)
common/factory.sh    原厂基线真值（还原用）
service.sh           开机自启 + 守护（audioserver 重启后自动补写）
webroot/index.html   WebUI 界面
webroot/run.sh       WebUI 后端
post-fs-data.sh      早期启动阶段
action.sh            KernelSU 操作按钮
uninstall.sh         卸载清理
customize.sh         安装时校验机型
module.prop          模块元信息
META-INF/            KernelSU 安装入口
docs/功能说明.txt     完整功能说明
capabilities.txt     硬件能力自检报告(探测后生成, 不入库)
```

---

## 版权与许可

本项目采用 **MIT License + 附加署名要求**：

- ✅ 允许二次修改、重新分发、商用
- ✅ **必须保留原作者署名** `bingjiling92` 及原项目链接

详见 [LICENSE](LICENSE) 与 [NOTICE](NOTICE)。

**本仓库不包含**任何杜比实验室的 DAX 调音数据、小米/高通的原始配置文件或厂商 ROM 提取文件。DAX 调音文件由脚本在用户设备本地动态生成。

---

## 免责声明

本模块仅为个人技术研究与学习目的提供。作者不对使用本模块导致的任何设备损坏、数据丢失或音频异常承担责任。使用前请自行评估风险。

本模块仅适配小米14 (houji / pineapple)，不保证其他机型可用。