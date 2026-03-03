# Deploy SSH key and complete Ubuntu setup
$ErrorActionPreference = "Continue"
$env:PATH += ";$env:LOCALAPPDATA\Microsoft\WinGet\Links"
$pass = "Camaron2025."
$host_addr = "wilserver@192.168.0.111"

# Get the SSH public key
$pubkey = Get-Content "$env:USERPROFILE\.ssh\id_rsa.pub" -Raw

# Step 1: Copy SSH key to Ubuntu
Write-Host "[1] Deploying SSH key..." -ForegroundColor Yellow
$cmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$pubkey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys && echo SSH_KEY_OK"
$result = sshpass -p $pass ssh -o StrictHostKeyChecking=no $host_addr $cmd 2>&1
Write-Host $result

# Step 2: Test passwordless SSH
Write-Host "[2] Testing passwordless SSH..." -ForegroundColor Yellow
$test = ssh -o BatchMode=yes -o ConnectTimeout=5 $host_addr "echo PASSWORDLESS_OK" 2>&1
Write-Host $test

# Step 3: Set up Git bare repo
Write-Host "[3] Setting up Git bare repo..." -ForegroundColor Yellow
$git_setup = ssh $host_addr "if [ ! -d /home/wilserver/nicaclaw-shared.git ]; then git init --bare /home/wilserver/nicaclaw-shared.git && echo GIT_BARE_CREATED; else echo GIT_BARE_EXISTS; fi" 2>&1
Write-Host $git_setup

# Step 4: Test binary
Write-Host "[4] Testing NicaClaw-Lite binary..." -ForegroundColor Yellow
$binary_test = ssh $host_addr "/home/wilserver/nicaclaw-lite/nicaclaw-lite --help 2>&1 | head -5" 2>&1
Write-Host $binary_test

# Step 5: Check Go availability
Write-Host "[5] Checking Go on Ubuntu..." -ForegroundColor Yellow
$go_check = ssh $host_addr "which go 2>/dev/null && go version 2>/dev/null || echo GO_NOT_INSTALLED" 2>&1
Write-Host $go_check

# Step 6: Create log file
Write-Host "[6] Creating log file..." -ForegroundColor Yellow
$log_setup = ssh $host_addr "touch /home/wilserver/nicaclaw-autoimprove.log && echo LOG_OK" 2>&1
Write-Host $log_setup

Write-Host "`n=== DEPLOYMENT STATUS ===" -ForegroundColor Green
Write-Host "Binary:  /home/wilserver/nicaclaw-lite/nicaclaw-lite"
Write-Host "Config:  /home/wilserver/.nicaclaw-lite/config.json"
Write-Host "Git:     /home/wilserver/nicaclaw-shared.git"
Write-Host "Log:     /home/wilserver/nicaclaw-autoimprove.log"
Write-Host "========================" -ForegroundColor Green
