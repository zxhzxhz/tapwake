# tapwake · AOD 单击亮屏

> 息屏 / AOD（Always-On Display）状态下，**点一下屏幕就亮屏**，不用再双击。
> 纯用户态、零内核改动、零 fork 注入，可一键卸载回滚。

[![Release](https://img.shields.io/github/v/release/zxhzxhz/tapwake?display_name=tag)](https://github.com/zxhzxhz/tapwake/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Magisk%20%7C%20KernelSU%20%7C%20APatch-blue)](#安装)

---

## 这是什么

小米 / Redmi（HyperOS · MIUI）在息屏与 AOD 状态下的「双击亮屏」，第一下点击必须等一个
**单击/双击消歧窗口（300~500ms）** 过去，才敢向上层上报单击，所以手感上总觉得「慢半拍」，
和 iPhone 的抬手即亮差一个身位。

`tapwake` 换了一条路走：**不去猜手势，直接翻译手势通道的按键码。**

```
触控 IC 上报 KEY_GOTO(354)  ──►  tapwake 回注 KEY_WAKEUP(143)  ──►  PowerManager 亮屏
```

同时把 MIUI 的「双击亮屏与熄屏」开关（`system/gesture_wakeup`）置 0，让触控 IC 在深睡时
由 **Double Tap 手势位切换到 Single Tap 手势位**，单击立即上报，消歧窗口彻底消失。

| 方案 | 单击 → 亮屏 | 说明 |
| :--- | :--- | :--- |
| 原厂双击亮屏 | 约 1000ms+ | 必须等双击消歧窗口超时，才上报单击 |
| **tapwake（本模块）** | **iPhone 级响应** | 手势到达内核后 **约 11ms** 完成注入 |
| 参考：面板 unblank 通道 | 比 KEY_GOTO 晚约 45ms | 被主通道完全覆盖，因此默认关闭 |

---

## 环境要求

| 项目 | 要求 |
| :--- | :--- |
| 机型 | 小米 / Redmi / POCO（`Xiaomi_Touch_Input_0` 触控驱动） |
| 系统 | HyperOS / MIUI（依赖 `settings` 服务的 `system/gesture_wakeup` 键） |
| Root | **Magisk** / **KernelSU** / **APatch** 任一 |
| Shell | `getevent`（toybox，系统自带） |

> 其他机型请先确认：`getevent -lt` 在息屏点屏时能看到 `KEY_GOTO`；且
> `settings get system gesture_wakeup` 返回 0 或 1。

---

## 安装

### 方式一：直接刷 zip（推荐）

1. 打开 [Releases](https://github.com/zxhzxhz/tapwake/releases/latest) 下载 `tapwake-v3.0.zip`；
2. Magisk / KernelSU / APatch → 模块 → 从本地安装 → 选 zip；
3. **重启手机**（或 `su -c 'sh /data/adb/modules/tapwake/service.sh'` 手动拉起）。

### 方式二：手动部署

```bash
adb push module.prop config.sh service.sh post-fs-data.sh uninstall.sh daemon.sh /sdcard/
adb shell su -c '
  mkdir -p /data/adb/modules/tapwake
  cp /sdcard/module.prop /sdcard/config.sh /sdcard/service.sh /sdcard/post-fs-data.sh /sdcard/uninstall.sh /sdcard/daemon.sh /data/adb/modules/tapwake/
  chmod 755 /data/adb/modules/tapwake/*.sh
  sh /data/adb/modules/tapwake/service.sh
'
```

---

## 配置

配置文件：`/data/adb/tapwake/config.sh`（首次开机由 `service.sh` 自动落盘）
改完执行 `su -c 'sh /data/adb/modules/tapwake/service.sh'` 或重启生效。

| 键 | 默认 | 作用 |
| :--- | :---: | :--- |
| `GOTO_WAKE` | `1` | **主通道**。`KEY_GOTO(354)` → `KEY_WAKEUP(143)`，AOD 与深睡通用 |
| `PANEL_WAKE` | `0` | 备用通道。面板 `FB_BLANK_UNBLANK` → `KEY_WAKEUP`。实测被主通道覆盖（主通道早约 45ms），且会在通知/抬腕唤醒时多注入，默认关闭 |
| `FORCE_SINGLE_TAP_ARM` | `1` | 开机把 `system/gesture_wakeup` 置 0，让触控 IC 深睡时用 Single Tap 手势位，**这是延迟下降到 iPhone 级的关键** |

> `FORCE_SINGLE_TAP_ARM=1` 的副作用：原厂「双击亮屏」手势开关会被关闭。
> 实际上双击依然能用——因为第一下就已经点亮了。

---

## 验证与日志

```bash
# 实时日志：应看到 [A] GOTO -> WAKEUP 记录，且时间戳紧跟点屏时刻
su -c 'tail -f /data/adb/tapwake/daemon.log'

# 确认手势开关已被置 0
su -c 'settings get system gesture_wakeup'

# 确认守护进程在跑
su -c 'pgrep -af modules/tapwake/daemon'
```

日志自带 256KB 轮转（`daemon.log` → `daemon.log.1`），不需要手工清理。

---

## 卸载 / 回滚

**推荐**：模块管理器里移除 → 重启。`uninstall.sh` 会自动：

- 把 `system/gesture_wakeup` 恢复成安装前记录的原厂值（存在 `/data/adb/tapwake/orig_gesture_wakeup`）；
- `kill -9` 掉 daemon 进程。

手动回滚（不卸载模块，只关掉行为）：

```bash
su -c 'sed -i "s/^FORCE_SINGLE_TAP_ARM=.*/FORCE_SINGLE_TAP_ARM=0/" /data/adb/tapwake/config.sh'
su -c 'settings put system gesture_wakeup 1'
su -c 'sh /data/adb/modules/tapwake/uninstall.sh'
```

---

## 技术细节

### 1. 零 fork 注入

不是每次点屏都 fork 一个 `sendevent`，而是：

- `service.sh` 启动时解析触控节点（遍历 `/sys/class/input/input*/name` 匹配 `Xiaomi_Touch_Input_0`，失败回退 `/dev/input/event8`）并缓存到 `/data/adb/tapwake/ev_main`；
- `daemon.sh` 用 `exec 3>"$EV"` 打开**持久 fd**；
- 命中 `KEY_GOTO DOWN` 时用 shell 内建 `printf` 往 fd 里 write 一段预编码的 `input_event` 序列（`KEY_WAKEUP` 按下 + 抬起）——等价于 `input_inject_event()`，全程不创建进程。

### 2. 手势通道翻译

`KEY_GOTO(354)` 是触控驱动在识别到 LPWG（Low Power Wakeup Gesture）后上报的私有手势键，
Framework 侧对它只做手势路由，不直接亮屏。把它转写成 `KEY_WAKEUP(143)` 后，
`PhoneWindowManager` 会走标准的 `PowerManagerService.wakeUp()` 路径。

### 3. 消歧窗口消除

`gesture_wakeup=1` 时，触控 IC 深睡手势位是 **Double Tap**，硬件必须先等一段窗口
判断「第二下会不会来」，才敢报单击 —— 这就是那 1 秒的来源。
置 0 后 IC 切到 **Single Tap** 手势位，第一下直接上报，链路端到端缩短到与面板 unblank 同一量级。

### 4. 备用通道为什么不默认开

`FB_BLANK_UNBLANK` 来自 `/dev/kmsg` 的面板点亮日志，实测比 `KEY_GOTO` **晚约 45ms**，
且通知亮屏、抬腕亮屏、来电等场景也会触发 unblank，会造成无意义的多余按键注入。
`PANEL_WAKE=1` 仅在个别固件上 `KEY_GOTO` 不下发时作为兜底。

---

## 目录结构

```
tapwake/
├── module.prop              # 模块元信息（id=tapwake, v3.0）
├── config.sh                # 三个行为开关
├── service.sh               # late_start：落盘配置 + 改手势开关 + 拉起 daemon
├── post-fs-data.sh          # 占位（本模块无需早期阶段操作）
├── uninstall.sh             # 恢复原厂 gesture_wakeup + 清理进程
├── daemon.sh                # 主守护：getevent 监听 → 持久 fd 注入
├── legacy/
│   └── daemon_v1_goto_only.sh   # v1 备选实现（AOD ~25ms / 深睡 ~460ms，保留参考）
├── build.sh                 # 一键打包 zip
└── README.md
```

## 自行打包

```bash
bash build.sh          # 产出 dist/tapwake-<version>.zip
```

---

## 已知限制

- 依赖 `Xiaomi_Touch_Input_0` 与 `system/gesture_wakeup` 键，**非小米系机型基本不适用**；
- 触控 IC 固件若被厂商锁死在 Double Tap 手势位，`gesture_wakeup=0` 无效，此时只能拿到「双击提速」效果；
- 本模块不改变亮屏后的解锁行为，仍走原厂锁屏 / 指纹流程。

## 免责声明

本项目为个人设备上的客户端行为验证与本地化实验产物，按 MIT 协议开源。
刷机有风险，请自行确认机型与固件匹配，一切后果自负。
