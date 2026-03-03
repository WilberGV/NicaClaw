#!/bin/bash
# =============================================================================
# NicaClaw-Lite Ubuntu Server Deployment Script
# Target: Ubuntu 24.04 at 192.168.0.111
# =============================================================================
set -euo pipefail

INSTALL_DIR="/home/wilserver/nicaclaw-lite"
BARE_REPO="/home/wilserver/nicaclaw-shared.git"
CONFIG_DIR="/home/wilserver/.nicaclaw-lite"
LOG_FILE="/var/log/nicaclaw-autoimprove.log"
BINARY_NAME="nicaclaw-lite"

echo "=========================================="
echo " NicaClaw-Lite Ubuntu Setup"
echo "=========================================="

# Phase 1: Directory structure
echo "[1/7] Creating directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR/workspace"
mkdir -p "$CONFIG_DIR/workspace/memory"
mkdir -p "$CONFIG_DIR/workspace/skills"
sudo touch "$LOG_FILE"
sudo chmod 666 "$LOG_FILE"
echo "[OK] Directories created"

# Phase 2: Install binary
echo "[2/7] Installing binary..."
if [ -f "/tmp/nicaclaw-lite-linux-amd64" ]; then
    cp /tmp/nicaclaw-lite-linux-amd64 "$INSTALL_DIR/$BINARY_NAME"
    chmod +x "$INSTALL_DIR/$BINARY_NAME"
    echo "[OK] Binary installed: $INSTALL_DIR/$BINARY_NAME"
else
    echo "[ERROR] Binary not found at /tmp/nicaclaw-lite-linux-amd64"
    echo "        Upload it first: scp nicaclaw-lite-linux-amd64 wilserver@192.168.0.111:/tmp/"
    exit 1
fi

# Phase 3: Install config
echo "[3/7] Installing config..."
if [ -f "/tmp/config.json" ]; then
    cp /tmp/config.json "$CONFIG_DIR/config.json"
    echo "[OK] Config installed: $CONFIG_DIR/config.json"
else
    echo "[WARN] Config not found at /tmp/config.json — using example"
fi

# Phase 4: Install Go (for future source builds)
echo "[4/7] Checking Go installation..."
if command -v go &> /dev/null; then
    echo "[OK] Go already installed: $(go version)"
else
    echo "[INFO] Installing Go..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq golang-go git make
    echo "[OK] Go installed: $(go version)"
fi

# Phase 5: Create bare Git repo
echo "[5/7] Setting up shared Git repo..."
if [ -d "$BARE_REPO" ]; then
    echo "[OK] Bare repo already exists at $BARE_REPO"
else
    git init --bare "$BARE_REPO"
    echo "[OK] Bare repo created: $BARE_REPO"
fi

# Phase 6: Git hooks
echo "[6/7] Installing Git hooks..."

# pre-receive hook: validate pushes
cat > "$BARE_REPO/hooks/pre-receive" << 'HOOK_END'
#!/bin/bash
# Pre-receive hook: validates code before accepting push
LOG="/var/log/nicaclaw-autoimprove.log"
echo "$(date '+%Y-%m-%d %H:%M:%S') PRE-RECEIVE: Validating push..." >> "$LOG"

while read oldrev newrev refname; do
    TMPDIR=$(mktemp -d)
    git archive "$newrev" | tar -x -C "$TMPDIR"
    
    # Check if Go source exists
    if [ -f "$TMPDIR/go.mod" ]; then
        cd "$TMPDIR"
        
        # Build test
        CGO_ENABLED=0 go build -ldflags="-s -w" -o /tmp/test-nicaclaw-lite ./cmd/nicaclaw-lite 2>> "$LOG"
        BUILD_EXIT=$?
        
        if [ $BUILD_EXIT -ne 0 ]; then
            echo "BUILD FAIL — push rejected"
            echo "$(date '+%Y-%m-%d %H:%M:%S') PRE-RECEIVE: BUILD FAIL" >> "$LOG"
            rm -rf "$TMPDIR"
            exit 1
        fi
        
        # Binary size check (<20MB)
        SIZE=$(stat -c%s /tmp/test-nicaclaw-lite 2>/dev/null || echo 0)
        SIZE_MB=$((SIZE / 1024 / 1024))
        if [ "$SIZE_MB" -gt 20 ]; then
            echo "BINARY SIZE FAIL: ${SIZE_MB}MB > 20MB limit"
            echo "$(date '+%Y-%m-%d %H:%M:%S') PRE-RECEIVE: SIZE FAIL ${SIZE_MB}MB" >> "$LOG"
            rm -rf "$TMPDIR"
            exit 1
        fi
        
        # Run tests
        go test ./... 2>> "$LOG"
        TEST_EXIT=$?
        if [ $TEST_EXIT -ne 0 ]; then
            echo "TEST FAIL — push rejected"
            echo "$(date '+%Y-%m-%d %H:%M:%S') PRE-RECEIVE: TEST FAIL" >> "$LOG"
            rm -rf "$TMPDIR"
            exit 1
        fi
        
        echo "$(date '+%Y-%m-%d %H:%M:%S') PRE-RECEIVE: VALIDATED OK (${SIZE_MB}MB)" >> "$LOG"
        rm -rf "$TMPDIR"
    fi
done
HOOK_END
chmod +x "$BARE_REPO/hooks/pre-receive"

# post-receive hook: auto-deploy
cat > "$BARE_REPO/hooks/post-receive" << 'HOOK_END'
#!/bin/bash
# Post-receive: auto-rebuild and restart NicaClaw-Lite
LOG="/var/log/nicaclaw-autoimprove.log"
INSTALL_DIR="/home/wilserver/nicaclaw-lite"

echo "$(date '+%Y-%m-%d %H:%M:%S') POST-RECEIVE: Deploying..." >> "$LOG"

# Clone/update working tree
if [ -d "$INSTALL_DIR/.git" ]; then
    cd "$INSTALL_DIR"
    git pull origin main 2>> "$LOG"
else
    git clone /home/wilserver/nicaclaw-shared.git "$INSTALL_DIR" 2>> "$LOG"
fi

cd "$INSTALL_DIR"

# Rebuild
CGO_ENABLED=0 go build -ldflags="-s -w" -o nicaclaw-lite ./cmd/nicaclaw-lite 2>> "$LOG"
BUILD_EXIT=$?

if [ $BUILD_EXIT -eq 0 ]; then
    # Restart service
    pkill -f "nicaclaw-lite agent" 2>/dev/null || true
    sleep 1
    nohup ./nicaclaw-lite agent --model gemini-flash --agent coder "Analyze workspace and optimize code" >> "$LOG" 2>&1 &
    echo "$(date '+%Y-%m-%d %H:%M:%S') POST-RECEIVE: DEPLOYED OK (PID: $!)" >> "$LOG"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') POST-RECEIVE: BUILD FAIL — not deployed" >> "$LOG"
fi
HOOK_END
chmod +x "$BARE_REPO/hooks/post-receive"
echo "[OK] Git hooks installed"

# Phase 7: Create auto-improve loop
echo "[7/7] Installing auto-improve loop..."
cat > "$INSTALL_DIR/auto_improve_loop.sh" << 'LOOP_END'
#!/bin/bash
# =============================================================================
# NicaClaw-Lite Auto-Improvement Loop
# Runs every 120s, measures metrics, communicates with NicaClaw Full
# =============================================================================
set -u

FULL_HOST="192.168.0.11"
FULL_PORT="8080"
LITE_PORT="8081"
LOG="/var/log/nicaclaw-autoimprove.log"
INSTALL_DIR="/home/wilserver/nicaclaw-lite"
ITERATION=0
MAX_ITERATIONS_WITHOUT_IMPROVEMENT=50
NO_IMPROVE_COUNT=0
LAST_RAM_KB=0

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

get_ram_kb() {
    local pid=$(pgrep -f "nicaclaw-lite" | head -1)
    if [ -n "$pid" ]; then
        awk '/VmRSS/{print $2}' /proc/$pid/status 2>/dev/null || echo 0
    else
        echo 0
    fi
}

get_binary_size_kb() {
    local size=$(stat -c%s "$INSTALL_DIR/nicaclaw-lite" 2>/dev/null || echo 0)
    echo $((size / 1024))
}

send_feedback() {
    local type="$1"
    local data="$2"
    curl -s -X POST "http://${FULL_HOST}:${FULL_PORT}/feedback/receive" \
        -H "Content-Type: application/json" \
        -d "$data" \
        --connect-timeout 5 \
        --max-time 10 2>/dev/null || true
}

log "=========================================="
log "AUTO-IMPROVE LOOP STARTED"
log "=========================================="

while true; do
    ITERATION=$((ITERATION + 1))
    log "--- ITERATION #${ITERATION} ---"
    
    # 1. Measure RAM
    RAM_KB=$(get_ram_kb)
    RAM_MB=$(echo "scale=2; $RAM_KB / 1024" | bc 2>/dev/null || echo "0")
    BIN_SIZE_KB=$(get_binary_size_kb)
    BIN_SIZE_MB=$(echo "scale=2; $BIN_SIZE_KB / 1024" | bc 2>/dev/null || echo "0")
    
    log "METRICS: RAM=${RAM_MB}MB BIN=${BIN_SIZE_MB}MB"
    
    # 2. Check if RAM improved vs last iteration
    if [ "$LAST_RAM_KB" -gt 0 ] && [ "$RAM_KB" -ge "$LAST_RAM_KB" ]; then
        NO_IMPROVE_COUNT=$((NO_IMPROVE_COUNT + 1))
    else
        NO_IMPROVE_COUNT=0
    fi
    LAST_RAM_KB=$RAM_KB
    
    # 3. Emergency stop: 50 iterations without improvement
    if [ "$NO_IMPROVE_COUNT" -ge "$MAX_ITERATIONS_WITHOUT_IMPROVEMENT" ]; then
        log "EMERGENCY: ${MAX_ITERATIONS_WITHOUT_IMPROVEMENT} iterations without improvement — pausing 24h"
        sleep 86400
        NO_IMPROVE_COUNT=0
        continue
    fi
    
    # 4. Send performance metrics to NicaClaw Full
    send_feedback "perf_feedback" "{
        \"from\": \"nica_lite\",
        \"to\": \"nica_full\",
        \"timestamp\": $(date +%s),
        \"type\": \"perf_feedback\",
        \"data\": {
            \"metrics\": {
                \"ram_peak_mb\": $RAM_MB,
                \"binary_size_mb\": $BIN_SIZE_MB,
                \"iteration\": $ITERATION,
                \"no_improve_count\": $NO_IMPROVE_COUNT
            }
        },
        \"objectives\": {
            \"lite\": {\"ram_max\": 5.0, \"priority\": \"minimalism\"}
        }
    }"
    
    # 5. Run NicaClaw-Lite agent to self-analyze (if not already running)
    if ! pgrep -f "nicaclaw-lite agent" > /dev/null 2>&1; then
        log "AGENT: Starting self-improvement analysis..."
        cd "$INSTALL_DIR"
        timeout 90 ./nicaclaw-lite agent --model gemini-flash --agent coder \
            "Analyze all Go source files in this workspace. Find memory allocations (make, new, malloc-like patterns), unnecessary goroutines, oversized buffers. Generate a concrete git diff patch to reduce RAM usage. Current RAM: ${RAM_MB}MB. Target: <5MB." \
            >> "$LOG" 2>&1 || true
        log "AGENT: Analysis complete"
    else
        log "AGENT: Already running, skipping"
    fi
    
    # 6. Check for pending diffs and apply
    if [ -f "$INSTALL_DIR/pending_diff.patch" ]; then
        log "DIFF: Found pending patch, testing..."
        cd "$INSTALL_DIR"
        
        # Save current state
        cp nicaclaw-lite nicaclaw-lite.bak 2>/dev/null || true
        
        # Apply and test
        git apply pending_diff.patch 2>> "$LOG"
        if [ $? -eq 0 ]; then
            CGO_ENABLED=0 go build -ldflags="-s -w" -o nicaclaw-lite-test ./cmd/nicaclaw-lite 2>> "$LOG"
            if [ $? -eq 0 ]; then
                NEW_SIZE=$(stat -c%s nicaclaw-lite-test)
                OLD_SIZE=$(stat -c%s nicaclaw-lite 2>/dev/null || echo $NEW_SIZE)
                
                if [ "$NEW_SIZE" -le "$OLD_SIZE" ]; then
                    mv nicaclaw-lite-test nicaclaw-lite
                    git add -A
                    git commit -m "Auto-opti: RAM/size reduction iter #${ITERATION}" 2>> "$LOG"
                    git push origin main 2>> "$LOG" || true
                    log "DIFF: APPLIED & COMMITTED — size ${OLD_SIZE} → ${NEW_SIZE}"
                    
                    send_feedback "test_results" "{
                        \"from\": \"nica_lite\",
                        \"to\": \"nica_full\",
                        \"timestamp\": $(date +%s),
                        \"type\": \"test_results\",
                        \"data\": {\"passed\": true, \"size_before\": $OLD_SIZE, \"size_after\": $NEW_SIZE}
                    }"
                else
                    log "DIFF: REJECTED — size regression ${OLD_SIZE} → ${NEW_SIZE}"
                    git checkout -- .
                    rm -f nicaclaw-lite-test
                fi
            else
                log "DIFF: BUILD FAILED — reverting"
                git checkout -- .
            fi
        else
            log "DIFF: APPLY FAILED — skipping"
        fi
        rm -f pending_diff.patch
    fi
    
    # 7. Uptime check: restart after 30 days
    UPTIME_DAYS=$(awk '{print int($1/86400)}' /proc/uptime 2>/dev/null || echo 0)
    if [ "$UPTIME_DAYS" -ge 30 ]; then
        log "UPTIME: ${UPTIME_DAYS} days — graceful restart"
        pkill -f "nicaclaw-lite agent" 2>/dev/null || true
    fi
    
    log "ITERATION #${ITERATION} COMPLETE — sleeping 120s"
    sleep 120
done
LOOP_END
chmod +x "$INSTALL_DIR/auto_improve_loop.sh"
echo "[OK] Auto-improve loop installed"

# Summary
echo ""
echo "=========================================="
echo " DEPLOYMENT COMPLETE"
echo "=========================================="
echo " Binary:   $INSTALL_DIR/$BINARY_NAME"
echo " Config:   $CONFIG_DIR/config.json"
echo " Git Repo: $BARE_REPO"
echo " Log:      $LOG"
echo " Loop:     $INSTALL_DIR/auto_improve_loop.sh"
echo ""
echo " To start the agent:"
echo "   cd $INSTALL_DIR && ./nicaclaw-lite agent --model gemini-flash"
echo ""
echo " To start the auto-improve loop:"
echo "   nohup $INSTALL_DIR/auto_improve_loop.sh &"
echo ""
echo " To clone shared repo from Windows:"
echo "   git clone wilserver@192.168.0.111:$BARE_REPO"
echo "=========================================="
