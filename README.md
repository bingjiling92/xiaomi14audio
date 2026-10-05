# 小米14 全域音频优化 (Xiaomi 14 Audio Optimization)

针对 **小米 14 (houji / pineapple)** 的 KernelSU 音频调优模块。

七层可独立开关的调音能力，核心是针对小米14 **非对称分频硬件**的深度适配 —— 顶部小高音单元与底部大低音单元分别由独立功放驱动，必须分别控制增益才能得到平衡的听感。

> 作者：[bingjiling92](https://github.com/bingjiling92)
> 许可：MIT + 附加署名要求（允许二改，但必须保留原作者署名）
> 适配：小米14 / Android 16 / 澎湃OS 3 / KernelSU

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
| 4 | DAX 深层调音 | 开 | 9 项参数，动态生成 DAX 调音文件 |
| 5 | 3 麦通话阵列 | 开 | 原厂 2 麦 → 3 麦，拾音范围更广 |
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

原厂通话仅启用 2 路数字麦，开启后补入第 3 路。

> ⚠️ 必须**同时注入** `mixer_paths_pineapple_mtp.xml` 与
> `mixer_paths_overlay_static.xml`。原因见下方「已知陷阱」第 1 条。

### 6-7. 外接解码 / Hi-Res

默认关闭，按需开启。解除限音与 Hi-Res 会增加耗电。

---

## 安装

1. 下载 `Xiaomi14全域音频优化_V3.2.zip`
2. KernelSU → 模块 → 安装模块 → 选择该ZIP
3. 重启手机
4. 开机约 15 秒后生效（属正常延迟）

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

## 实测参数速查

```
tinymix 位置      /system/bin/tinymix  (529 控件)
RX_RX0/1/2 Digital Volume     0 -> 124   原厂 84
RX_RX0/1/2 Mix Digital Volume 0 -> 124   原厂 84
RX_COMP1/2 Switch             动态压缩    原厂关
RX_Softclip Enable
RX_HPH_PWR_MODE               枚举 ULP / LOHIFI
T AMP PCM Gain                0 -> 20     原厂 18
B AMP PCM Gain                0 -> 20     原厂 18
T/B Digital PCM Volume        0 -> 913    原厂 817

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