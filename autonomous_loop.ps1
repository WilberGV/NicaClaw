# NicaClaw Master-Slaves Orchestration Loop
# Master: C:\Users\Admin\Desktop\nica-main\nicaclaw-main\nicaclaw.exe
# Slaves: .\nicaclaw-lite.exe

$Master = "C:\Users\Admin\Desktop\nica-main\nicaclaw-main\nicaclaw.exe"
$SlaveApp = ".\nicaclaw-lite.exe"
$Agents = @("coder", "tester", "fixer", "quality", "troubleshooter")
$RetryInterval = 60

Write-Host "`n--- [MASTER-SLAVE MODE] Starting NicaClaw Hierarchical Swarm ---" -ForegroundColor Yellow

while ($true) {
    Write-Host "`n[MASTER] Analyzing overall project state..." -ForegroundColor Cyan
    & $Master agent -m "Review MEMORY.md and project goals. Delegate high-level tasks to specialized slaves. Focus on overall strategy." --agent "master" --model "openrouter-auto"

    foreach ($AgentId in $Agents) {
        Write-Host "`n[SLAVE] Running Agent: $AgentId..." -ForegroundColor White
        
        $Prompt = "ROLE: $AgentId. Execute specialized tasks delegated by Master in MEMORY.md. " +
        "Update your specific section in MEMORY.md and report back to Master."

        # Execute specialized slave agent
        & $SlaveApp agent -m "$Prompt" -s "master_slave_orchestration" --agent "$AgentId" --model "openrouter-auto"

        if ($LASTEXITCODE -eq 0) {
            Write-Host "[SUCCESS] $AgentId reported completion." -ForegroundColor Green
        }
        else {
            Write-Host "[WARNING] $AgentId encountered issues. Master will analyze next cycle." -ForegroundColor Yellow
        }
        
        Start-Sleep -Seconds 5
    }

    Write-Host "`n[CYCLE DONE] Master-Slave coordination finished. Sleeping for $RetryInterval seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds $RetryInterval
}
