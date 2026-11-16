#!/system/bin/sh
# tapwake daemon v2.2
#  通道A (GOTO): 触控 IC 上报 KEY_GOTO(354) -> 回注 KEY_WAKEUP(143)  [主通道, 实测手势到达内核后 11ms 完成]
#  通道B (PANEL): 面板 FB_BLANK_UNBLANK -> 回注 KEY_WAKEUP        [实测被通道A覆盖(A 比面板 unblank 还早 45ms), 默认关闭]
# 注入: 零 fork —— 持久 fd + shell 内建 printf 一次 write (evdev_write -> input_inject_event)
DATA=/data/adb/tapwake
mkdir -p "$DATA"
LOG="$DATA/daemon.log"
MAXLOG=262144
SEQ='\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\001\000\217\000\001\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\001\000\217\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000'
CONF=$DATA/config.sh
[ -f "$CONF" ] && . "$CONF"
: ${GOTO_WAKE:=1}
: ${PANEL_WAKE:=0}

log() { echo "[$(date '+%m-%d %H:%M:%S')] [$$] $*"; }

find_main_touch() {
  for d in /sys/class/input/input*; do
    case "$(cat "$d/name" 2>/dev/null)" in
      Xiaomi_Touch_Input_0*)
        for e in "$d"/event*; do [ -e "$e" ] && { echo "/dev/input/${e##*/}"; return 0; }; done ;;
    esac
  done
  echo /dev/input/event8
}

EV_MAIN=$DATA/ev_main
if [ -s "$EV_MAIN" ] && [ -e "$(cat "$EV_MAIN")" ]; then EV=$(cat "$EV_MAIN"); else EV=$(find_main_touch); echo "$EV" > "$EV_MAIN"; fi
rotate() { [ -f "$LOG" ] && [ "$(wc -c < "$LOG" 2>/dev/null)" -gt "$MAXLOG" ] && mv -f "$LOG" "$LOG.1"; }

watch_goto() {
  exec 3>"$EV" 2>/dev/null
  while true; do
    rotate
    getevent -lt 2>/dev/null | while read -r line; do
      case "$line" in
        *KEY_GOTO*DOWN*)
          [ "$GOTO_WAKE" = "1" ] || continue
          x=${line#*] }; dev=${x%%:*}
          printf "$SEQ" >&3 2>/dev/null || {
            EV=$(find_main_touch); echo "$EV" > "$EV_MAIN"
            exec 3>"$EV" 2>/dev/null; printf "$SEQ" >&3 2>/dev/null
          }
          log "[A] GOTO -> WAKEUP ($dev)"
          ;;
      esac
    done
    log "[A] getevent exited, restart in 1s"
    sleep 1
  done
}

watch_panel() {
  exec 4>"$EV" 2>/dev/null
  while true; do
    cat /dev/kmsg 2>/dev/null | while read -r line; do
      case "$line" in
        *"FB_BLANK_UNBLAN"*)
          [ "$PANEL_WAKE" = "1" ] || continue
          read -r now _ < /proc/uptime; now=${now%.*}
          [ "$now" = "$last" ] && continue
          last="$now"
          printf "$SEQ" >&4 2>/dev/null
          log "[B] PANEL UNBLANK -> WAKEUP"
          ;;
      esac
    done
    sleep 0.3
  done
}

log "daemon v2.2 start (pid $$) GOTO_WAKE=$GOTO_WAKE PANEL_WAKE=$PANEL_WAKE touch=$EV"
( watch_goto ) &
[ "$PANEL_WAKE" = "1" ] && ( watch_panel ) &
wait
