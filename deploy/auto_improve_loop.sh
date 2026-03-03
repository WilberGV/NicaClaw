#!/bin/bash
# =============================================================================
# NicaClaw Auto-Improvement Loop
# Runs every 120s, measures metrics, sends feedback to NicaClaw Full
# =============================================================================
set -u

FULL_HOST="192.168.0.11"
FULL_PORT="8080"
LOG="/home/wilserver/nicaclaw-autoimprove.log"
INSTALL_DIR="/home/wilserver/nicaclaw-lite"
ITERATION=0
MAX_NO_IMPROVE=50
NO_IMPROVE=0
LAST_RAM=0

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG"; }

get_ram_kb() {
    local pid=$(pgrep -f "nicaclaw-lite" | head -1)
    [ -n "$pid" ] && awk '/VmRSS/{print $2}' /proc/$pid/status 2>/dev/null || echo 0
}

log "=========================================="
log "AUTO-IMPROVE LOOP STARTED"
log "Full endpoint: http://${FULL_HOST}:${FULL_PORT}"
log "=========================================="

while true; do
    ITERATION=$((ITERATION + 1))
    log "--- ITERATION #${ITERATION} ---"

    # 1. Measure RAM of nicaclaw-lite process
    RAM_KB=$(get_ram_kb)
    RAM_MB=$(awk "BEGIN{printf \"%.2f\", $RAM_KB/1024}")
    BIN_SIZE=$(stat -c%s "$INSTALL_DIR/nicaclaw-lite" 2>/dev/null || echo 0)
    BIN_MB=$(awk "BEGIN{printf \"%.2f\", $BIN_SIZE/1048576}")

    log "METRICS: RAM=${RAM_MB}MB BIN=${BIN_MB}MB"

    # 2. Track improvement
    if [ "$LAST_RAM" -gt 0 ] && [ "$RAM_KB" -ge "$LAST_RAM" ]; then
        NO_IMPROVE=$((NO_IMPROVE + 1))
    else
        NO_IMPROVE=0
    fi
    LAST_RAM=$RAM_KB

    # 3. Emergency pause after 50 stale iterations
    if [ "$NO_IMPROVE" -ge "$MAX_NO_IMPROVE" ]; then
        log "PAUSE: ${MAX_NO_IMPROVE} stale iterations — sleeping 24h"
        sleep 86400
        NO_IMPROVE=0
        continue
    fi

    # 4. Send metrics to NicaClaw Full
    curl -s -X POST "http://${FULL_HOST}:${FULL_PORT}/feedback/receive" \
        -H "Content-Type: application/json" \
        -d "{\"from\":\"nica_lite\",\"to\":\"nica_full\",\"timestamp\":$(date +%s),\"type\":\"perf_feedback\",\"data\":{\"metrics\":{\"ram_peak_mb\":${RAM_MB},\"binary_size_mb\":${BIN_MB},\"iteration\":${ITERATION}}}}" \
        --connect-timeout 5 --max-time 10 2>/dev/null && log "FEEDBACK: Sent to Full" || log "FEEDBACK: Full unreachable"

    # 5. Run self-improvement agent if not already running
    if ! pgrep -f "nicaclaw-lite agent" > /dev/null 2>&1; then
        log "AGENT: Starting self-improvement..."
        cd "$INSTALL_DIR"
        timeout 90 ./nicaclaw-lite agent --model gemini-flash --agent coder \
            "Analyze Go code in this workspace for: oversized buffers (>1024 bytes), unnecessary dynamic allocs (make/new), goroutine leaks. Suggest concrete patches to reduce RAM. Current RAM: ${RAM_MB}MB. Target: <5MB." \
            >> "$LOG" 2>&1 || true
        log "AGENT: Analysis cycle done"
    fi

    # 6. Check & apply pending patches
    if [ -f "$INSTALL_DIR/pending_diff.patch" ]; then
        log "PATCH: Found pending, testing..."
        cd "$INSTALL_DIR"
        cp nicaclaw-lite nicaclaw-lite.bak 2>/dev/null || true
        if git apply pending_diff.patch 2>>"$LOG"; then
            if CGO_ENABLED=0 go build -ldflags="-s -w" -o nicaclaw-lite-test ./cmd/nicaclaw-lite 2>>"$LOG"; then
                NEW=$(stat -c%s nicaclaw-lite-test)
                OLD=$(stat -c%s nicaclaw-lite 2>/dev/null || echo $NEW)
                if [ "$NEW" -le "$OLD" ]; then
                    mv nicaclaw-lite-test nicaclaw-lite
                    git add -A && git commit -m "Auto-opti iter #${ITERATION}" 2>>"$LOG"
                    git push origin master 2>>"$LOG" || true
                    log "PATCH: APPLIED (${OLD}→${NEW} bytes)"
                else
                    log "PATCH: REJECTED — size regression"
                    git checkout -- .
                    rm -f nicaclaw-lite-test
                fi
            else
                log "PATCH: BUILD FAIL — reverting"
                git checkout -- .
            fi
        else
            log "PATCH: APPLY FAIL — skipping"
        fi
        rm -f pending_diff.patch
    fi

    log "ITER #${ITERATION} DONE — sleep 120s"
    sleep 120
done
