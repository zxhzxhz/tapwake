#!/system/bin/sh
# [备选 v1] 仅 GOTO->WAKEUP：只在触控 IC 上报 KEY_GOTO(354) 之后才注入（AOD 态最快 ~25ms，深睡态要等 HAL 上报 ~460ms）
DATA=/data/adb/tapwake
mkdir -p "$DATA"
LOG="$DATA/daemon.log"
MAXLOG=262144
SEQ='\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\001\000\217\000\001\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\001\000\217\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000'
log() { echo "[$(date '+%m-%d %H:%M:%S')] [v1] $*"; }
log "daemon start (pid $$)"
while true; do
  [ -f "$LOG" ] && [ "$(wc -c < "$LOG" 2>/dev/null)" -gt "$MAXLOG" ] && mv -f "$LOG" "$LOG.1"
  getevent -lt 2>/dev/null | while read -r line; do
    case "$line" in
      *KEY_GOTO*DOWN*)
        x=${line#*] }
        ev=${x%%:*}
        printf "$SEQ" > "$ev" 2>/dev/null
        log "GOTO -> WAKEUP on $ev"
        ;;
    esac
  done
  log "getevent exited, restart in 1s"
  sleep 1
done
