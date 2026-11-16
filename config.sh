# tapwake 配置（改完执行 sh /data/adb/modules/tapwake/service.sh 或重启生效）
# 通道A: KEY_GOTO(354) -> KEY_WAKEUP(143)。唯一需要的通道，AOD/深睡通用。
GOTO_WAKE=1
# 通道B: 面板 FB_BLANK_UNBLANK -> KEY_WAKEUP。实测 KEY_GOTO 比面板 unblank 还早约 45ms，
#        通道A 已完全覆盖它，且会在通知/抬腕唤醒时多注入，默认关闭。
PANEL_WAKE=0
# 关键开关: 开机强制关闭 MIUI「双击亮屏与熄屏」(system/gesture_wakeup=0)。
#   原因: 该开关控制触控 IC 深睡时的手势位——开启时 IC 是 Double Tap(0x01)，收到第一下必须先等
#         单击/双击消歧窗口(300~500ms)才敢上报单击，导致单击亮屏慢约 1 秒；
#         关闭后 IC 变为 Single Tap(0x10)，单击立即上报，延迟降到 iPhone 级。
#   副作用: 原厂双击亮屏手势被关（双击仍可用，因为第一下就会触发本模块亮屏）。
#   回滚: 把这里改成 0，或执行 sh /data/adb/modules/tapwake/uninstall.sh
FORCE_SINGLE_TAP_ARM=1
