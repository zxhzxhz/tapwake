#!/system/bin/sh
MODDIR=${0%/*}
DATA=/data/adb/tapwake
mkdir -p "$DATA"
[ -f "$MODDIR/config.sh" ] && cp -f "$MODDIR/config.sh" "$DATA/config.sh"
[ -f "$DATA/config.sh" ] || { echo "GOTO_WAKE=1" > "$DATA/config.sh"; echo "PANEL_WAKE=0" >> "$DATA/config.sh"; echo "FORCE_SINGLE_TAP_ARM=1" >> "$DATA/config.sh"; }
. "$DATA/config.sh"
: ${GOTO_WAKE:=1}
: ${PANEL_WAKE:=0}
: ${FORCE_SINGLE_TAP_ARM:=1}

logline() { echo "[$(date '+%m-%d %H:%M:%S')] $*" >> "$DATA/daemon.log"; }

gs_get() { settings get system gesture_wakeup 2>/dev/null | tail -1; }

if [ "$FORCE_SINGLE_TAP_ARM" = "1" ]; then
  # 先记录原厂值(settings 服务可能尚未就绪, 重试并校验)
  i=0; gv=""
  while [ $i -lt 15 ]; do
    gv=$(gs_get)
    case "$gv" in 0|1) break ;; esac
    i=$((i+1)); sleep 2
  done
  case "$gv" in
    0|1) [ -s "$DATA/orig_gesture_wakeup" ] || echo "$gv" > "$DATA/orig_gesture_wakeup" ;;
    *)   logline "WARN gesture_wakeup 读取失败('$gv'), 使用默认回滚值 1"; [ -s "$DATA/orig_gesture_wakeup" ] || echo 1 > "$DATA/orig_gesture_wakeup" ;;
  esac
  [ "$gv" != "0" ] && { settings put system gesture_wakeup 0 2>/dev/null; sleep 0.5; }
  logline "gesture_wakeup: 原厂=$(cat "$DATA/orig_gesture_wakeup" 2>/dev/null) 当前=$(gs_get)"
fi

for p in $(pgrep -f "$MODDIR/daemon.sh"); do kill "$p" 2>/dev/null; done
sleep 0.2
setsid sh "$MODDIR/daemon.sh" >> "$DATA/daemon.log" 2>&1 &
logline "service.sh started daemon (pid $!) GOTO_WAKE=$GOTO_WAKE PANEL_WAKE=$PANEL_WAKE SINGLE_TAP_ARM=$FORCE_SINGLE_TAP_ARM"
