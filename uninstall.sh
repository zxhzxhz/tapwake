#!/system/bin/sh
# 模块卸载时恢复原厂「双击亮屏与熄屏」开关（默认恢复为 1=开启）
DATA=/data/adb/tapwake
v=1
if [ -s "$DATA/orig_gesture_wakeup" ]; then
  t=$(cat "$DATA/orig_gesture_wakeup" 2>/dev/null)
  case "$t" in 0|1) v="$t" ;; esac
fi
settings put system gesture_wakeup "$v" 2>/dev/null
for p in $(pgrep -f "modules/tapwake/daemon"); do kill -9 "$p" 2>/dev/null; done
pkill -9 -f "modules/tapwake/daemon" 2>/dev/null
