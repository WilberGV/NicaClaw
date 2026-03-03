# Complete Phase 2 Deploy — uses sshpass for all operations
$ErrorActionPreference = "Continue"
$env:PATH += ";$env:LOCALAPPDATA\Microsoft\WinGet\Links"
$pass = "Camaron2025."
$user = "wilserver@192.168.0.111"
$sshOpts = "-o StrictHostKeyChecking=no"

function Run-SSH($cmd) {
    $result = sshpass -p $pass ssh $sshOpts $user $cmd 2>&1
    Write-Host $result
    return $result
}

function Run-SCP($local, $remote) {
    $result = sshpass -p $pass scp $sshOpts $local "${user}:${remote}" 2>&1
    Write-Host "SCP $local -> $remote : $result"
}

Write-Host "=== PHASE 2: Git Hooks + Auto-Improve ===" -ForegroundColor Cyan

# 1. Fix SSH key auth properly
Write-Host "[1] Fixing SSH key auth..." -ForegroundColor Yellow
$pubkey = (Get-Content "$env:USERPROFILE\.ssh\id_rsa.pub" -Raw).Trim()
Run-SSH "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$pubkey' > ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo SSH_KEY_FIXED"

# 2. SCP the hook and loop scripts
Write-Host "[2] Transferring scripts..." -ForegroundColor Yellow
Run-SCP "deploy\post-receive" "/home/wilserver/nicaclaw-shared.git/hooks/post-receive"
Run-SCP "deploy\auto_improve_loop.sh" "/home/wilserver/nicaclaw-lite/auto_improve_loop.sh"

# 3. Set permissions
Write-Host "[3] Setting permissions..." -ForegroundColor Yellow
Run-SSH "chmod +x /home/wilserver/nicaclaw-shared.git/hooks/post-receive /home/wilserver/nicaclaw-lite/auto_improve_loop.sh && echo PERMS_OK"

# 4. Verify deployment
Write-Host "[4] Verifying..." -ForegroundColor Yellow
Run-SSH "ls -la /home/wilserver/nicaclaw-shared.git/hooks/post-receive /home/wilserver/nicaclaw-lite/auto_improve_loop.sh /home/wilserver/nicaclaw-lite/nicaclaw-lite /home/wilserver/.nicaclaw-lite/config.json"

# 5. Initialize shared repo with the current codebase
Write-Host "[5] Initializing shared Git repo from Windows..." -ForegroundColor Yellow
$sharedPath = "C:\Users\Admin\Desktop\nica-main\nicaclaw-shared"
if (-not (Test-Path $sharedPath)) {
    sshpass -p $pass git clone "${user}:/home/wilserver/nicaclaw-shared.git" $sharedPath 2>&1
    if (-not (Test-Path $sharedPath)) {
        New-Item -ItemType Directory -Path $sharedPath -Force
        Set-Location $sharedPath
        git init
        git remote add origin "${user}:/home/wilserver/nicaclaw-shared.git"
    }
    Write-Host "[OK] Shared repo cloned/created"
}
else {
    Write-Host "[OK] Shared repo already exists"
}

# 6. Start the nicaclaw-lite agent on Ubuntu
Write-Host "[6] Starting NicaClaw-Lite agent..." -ForegroundColor Yellow
Run-SSH "cd /home/wilserver/nicaclaw-lite && nohup ./nicaclaw-lite agent --model gemini-flash --agent coder 'Analyze Go source code in workspace for memory optimization opportunities. Report findings.' > /home/wilserver/nicaclaw-autoimprove.log 2>&1 & echo AGENT_PID=`echo `$!`"

# 7. Start the auto-improve loop
Write-Host "[7] Starting auto-improve loop..." -ForegroundColor Yellow
Run-SSH "cd /home/wilserver/nicaclaw-lite && nohup bash auto_improve_loop.sh >> /home/wilserver/nicaclaw-autoimprove.log 2>&1 & echo LOOP_PID=`echo `$!`"

# 8. Verify running processes
Write-Host "[8] Verifying running processes..." -ForegroundColor Yellow
Start-Sleep -Seconds 3
Run-SSH "ps aux | grep -E 'nicaclaw|auto_improve' | grep -v grep"

Write-Host "`n=== PHASE 2 COMPLETE ===" -ForegroundColor Green
Write-Host "Auto-improve loop running on Ubuntu"
Write-Host "Check logs: ssh $user 'tail -f /home/wilserver/nicaclaw-autoimprove.log'"
Write-Host "========================" -ForegroundColor Green
