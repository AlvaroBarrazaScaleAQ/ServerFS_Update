# =========================
# SOLUCION DEFINITIVA V2 - PROTECCION TOTAL
# Incluye watchdog para restaurar politica en CUALQUIER escenario
# =========================

$server = "192.168.11.106"
$cred   = Get-Credential

$taskName   = "ForceInstall_Final_V2"
$watchdogTask = "WU_PolicyWatchdog"
$scriptPath = "C:\Windows\Temp\wu_final_solution_v2.ps1"
$watchdogPath = "C:\Windows\Temp\wu_watchdog.ps1"
$logPath    = "C:\Windows\Temp\WU_Final_V2.log"
$lockFile   = "C:\Windows\Temp\WU_Policy_Lock.txt"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SOLUCION V2 - CON PROTECCION TOTAL" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 1) Crear script watchdog que restaurara la politica automaticamente
Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock {
    param($watchdogPath, $lockFile)

    $watchdogContent = @'
# Watchdog - Restaurar politica si el lock file existe por mas de 5 minutos
$lockFile = "{LOCKFILE}"
$regPath = "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"

if (Test-Path $lockFile) {
    $lockAge = (Get-Date) - (Get-Item $lockFile).LastWriteTime
    
    # Si el lock tiene mas de 5 minutos, algo salio mal
    if ($lockAge.TotalMinutes -gt 5) {
        # Leer el valor original del lock file
        $originalValue = Get-Content $lockFile
        
        if ($originalValue -match '^\d+$') {
            # Restaurar politica
            Set-ItemProperty -Path $regPath -Name AUOptions -Value ([int]$originalValue) -Type DWord
            
            # Log del watchdog
            "$(Get-Date) - WATCHDOG: Politica restaurada a $originalValue tras timeout" | Out-File -FilePath "C:\Windows\Temp\WU_Watchdog.log" -Append
            
            # Eliminar lock
            Remove-Item $lockFile -Force
            
            # Reiniciar servicio
            Restart-Service -Name wuauserv -Force
        }
    }
} else {
    # No hay lock, todo bien
    "$(Get-Date) - WATCHDOG: No hay lock file, sistema OK" | Out-File -FilePath "C:\Windows\Temp\WU_Watchdog.log" -Append
}
'@
    
    $watchdogContent = $watchdogContent -replace '{LOCKFILE}', $lockFile
    $watchdogContent | Set-Content -Path $watchdogPath -Encoding UTF8
    
    "Watchdog creado en $watchdogPath"
} -ArgumentList $watchdogPath, $lockFile


# 2) Programar watchdog para ejecutarse cada 2 minutos
Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock {
    param($watchdogTask, $watchdogPath)
    
    # Eliminar tarea si existe
    schtasks /Delete /TN $watchdogTask /F 2>$null | Out-Null
    
    # Crear tarea que se ejecuta cada 2 minutos
    schtasks /Create /TN $watchdogTask `
      /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$watchdogPath`"" `
      /SC MINUTE /MO 2 /RU "SYSTEM" /RL HIGHEST /F | Out-Null
    
    "Watchdog programado: $watchdogTask (cada 2 minutos)"
} -ArgumentList $watchdogTask, $watchdogPath


# 3) Crear script principal mejorado
Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock {
    param($scriptPath, $logPath, $lockFile)

    if (Test-Path $logPath) { Remove-Item $logPath -Force }

    $scriptContent = @'
"========================================" | Out-File -FilePath "{LOGPATH}" -Append
"=== INSTALACION V2 - CON PROTECCION TOTAL ===" | Out-File -FilePath "{LOGPATH}" -Append
"=== Inicio: $(Get-Date) ===" | Out-File -FilePath "{LOGPATH}" -Append
"========================================" | Out-File -FilePath "{LOGPATH}" -Append
"" | Out-File -FilePath "{LOGPATH}" -Append

$regPath = "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"
$valueName = "AUOptions"
$originalValue = $null
$policyChanged = $false
$lockFile = "{LOCKFILE}"

try {
    # PASO 1: Guardar valor original y crear LOCK FILE
    "PASO 1: Verificando politica actual..." | Out-File -FilePath "{LOGPATH}" -Append
    
    if (Test-Path $regPath) {
        $originalValue = (Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction SilentlyContinue).$valueName
        "Valor actual de AUOptions: $originalValue" | Out-File -FilePath "{LOGPATH}" -Append
        
        if ($originalValue -eq 3) {
            # CREAR LOCK FILE con el valor original
            $originalValue | Out-File -FilePath $lockFile -Force
            "Lock file creado: $lockFile (valor: $originalValue)" | Out-File -FilePath "{LOGPATH}" -Append
            
            "Cambiando politica a 4..." | Out-File -FilePath "{LOGPATH}" -Append
            Set-ItemProperty -Path $regPath -Name $valueName -Value 4 -Type DWord
            $policyChanged = $true
            
            "Politica cambiada exitosamente a 4" | Out-File -FilePath "{LOGPATH}" -Append
            "" | Out-File -FilePath "{LOGPATH}" -Append
            
            Restart-Service -Name wuauserv -Force
            Start-Sleep -Seconds 5
            "Servicio reiniciado" | Out-File -FilePath "{LOGPATH}" -Append
            
        } else {
            "AUOptions no es 3, no es necesario cambiar" | Out-File -FilePath "{LOGPATH}" -Append
        }
    }
    
    "" | Out-File -FilePath "{LOGPATH}" -Append
    
    # PASO 2: Forzar instalacion con UsoClient
    "PASO 2: Forzando instalacion con UsoClient..." | Out-File -FilePath "{LOGPATH}" -Append
    
    Start-Process -FilePath "C:\Windows\System32\UsoClient.exe" -ArgumentList "StartScan" -NoNewWindow -Wait
    Start-Sleep -Seconds 5
    
    Start-Process -FilePath "C:\Windows\System32\UsoClient.exe" -ArgumentList "StartDownload" -NoNewWindow -Wait
    Start-Sleep -Seconds 10
    
    Start-Process -FilePath "C:\Windows\System32\UsoClient.exe" -ArgumentList "StartInstall" -NoNewWindow -Wait
    
    "UsoClient ejecutado" | Out-File -FilePath "{LOGPATH}" -Append
    "" | Out-File -FilePath "{LOGPATH}" -Append
    
    # PASO 3: Intentar COM API
    "PASO 3: Intentando instalacion via COM API..." | Out-File -FilePath "{LOGPATH}" -Append
    
    try {
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()
        $updateSearcher.ServerSelection = 3
        
        $searchResult = $updateSearcher.Search("IsInstalled=0 and IsHidden=0")
        
        "Encontradas: $($searchResult.Updates.Count)" | Out-File -FilePath "{LOGPATH}" -Append
        
        if ($searchResult.Updates.Count -gt 0) {
            $toInstall = New-Object -ComObject Microsoft.Update.UpdateColl
            
            foreach ($update in $searchResult.Updates) {
                "  - $($update.Title)" | Out-File -FilePath "{LOGPATH}" -Append
                if ($update.EulaAccepted -eq $false) { $update.AcceptEula() }
                $toInstall.Add($update) | Out-Null
            }
            
            $installer = $updateSession.CreateUpdateInstaller()
            $installer.Updates = $toInstall
            $installResult = $installer.Install()
            
            "" | Out-File -FilePath "{LOGPATH}" -Append
            "RESULTADO: $($installResult.ResultCode)" | Out-File -FilePath "{LOGPATH}" -Append
            
            if ($installResult.RebootRequired) {
                "REINICIO REQUERIDO - Programando en 3 minutos..." | Out-File -FilePath "{LOGPATH}" -Append
                shutdown /r /t 180 /c "Reiniciando para completar Windows Updates"
            }
        }
        
    } catch {
        "ERROR en COM API: $($_.Exception.Message)" | Out-File -FilePath "{LOGPATH}" -Append
    }
    
    "" | Out-File -FilePath "{LOGPATH}" -Append
    "PASO 4: Esperando 30 segundos..." | Out-File -FilePath "{LOGPATH}" -Append
    Start-Sleep -Seconds 30
    
    # PASO 5: RESTAURAR y ELIMINAR LOCK
    if ($policyChanged -and $originalValue -ne $null) {
        "" | Out-File -FilePath "{LOGPATH}" -Append
        "========================================" | Out-File -FilePath "{LOGPATH}" -Append
        "PASO 5: RESTAURANDO POLITICA ORIGINAL" | Out-File -FilePath "{LOGPATH}" -Append
        "========================================" | Out-File -FilePath "{LOGPATH}" -Append
        
        Set-ItemProperty -Path $regPath -Name $valueName -Value $originalValue -Type DWord
        "Politica restaurada a $originalValue" | Out-File -FilePath "{LOGPATH}" -Append
        
        # ELIMINAR LOCK FILE (muy importante!)
        if (Test-Path $lockFile) {
            Remove-Item $lockFile -Force
            "Lock file eliminado - Watchdog desactivado" | Out-File -FilePath "{LOGPATH}" -Append
        }
        
        Restart-Service -Name wuauserv -Force
        "Servicio reiniciado" | Out-File -FilePath "{LOGPATH}" -Append
    }
    
} catch {
    "========================================" | Out-File -FilePath "{LOGPATH}" -Append
    "ERROR CRITICO" | Out-File -FilePath "{LOGPATH}" -Append
    "========================================" | Out-File -FilePath "{LOGPATH}" -Append
    "Mensaje: $($_.Exception.Message)" | Out-File -FilePath "{LOGPATH}" -Append
    
    # RESTAURAR EN CASO DE ERROR
    if ($policyChanged -and $originalValue -ne $null) {
        "" | Out-File -FilePath "{LOGPATH}" -Append
        "Restaurando politica tras error..." | Out-File -FilePath "{LOGPATH}" -Append
        try {
            Set-ItemProperty -Path $regPath -Name $valueName -Value $originalValue -Type DWord
            
            # ELIMINAR LOCK
            if (Test-Path $lockFile) {
                Remove-Item $lockFile -Force
            }
            
            "Politica restaurada y lock eliminado" | Out-File -FilePath "{LOGPATH}" -Append
        } catch {
            "ERROR al restaurar: $($_.Exception.Message)" | Out-File -FilePath "{LOGPATH}" -Append
            "WATCHDOG se encargara de restaurar automaticamente" | Out-File -FilePath "{LOGPATH}" -Append
        }
    }
}

"" | Out-File -FilePath "{LOGPATH}" -Append
"========================================" | Out-File -FilePath "{LOGPATH}" -Append
"=== Finalizado: $(Get-Date) ===" | Out-File -FilePath "{LOGPATH}" -Append
"========================================" | Out-File -FilePath "{LOGPATH}" -Append
'@

    $scriptContent = $scriptContent -replace '{LOGPATH}', $logPath
    $scriptContent = $scriptContent -replace '{LOCKFILE}', $lockFile
    $scriptContent | Set-Content -Path $scriptPath -Encoding UTF8

    "Script V2 preparado"
} -ArgumentList $scriptPath, $logPath, $lockFile


# 4) Ejecutar script principal
Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock {
    param($taskName, $scriptPath)

    $runTime = (Get-Date).AddMinutes(1).ToString("HH:mm")

    schtasks /Create /TN $taskName `
      /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" `
      /SC ONCE /ST $runTime /RU "SYSTEM" /RL HIGHEST /F | Out-Null

    schtasks /Run /TN $taskName | Out-Null

    "Tarea lanzada"
} -ArgumentList $taskName, $scriptPath


# 5) Monitorear
$timeoutSeconds = 120
$start = Get-Date

Write-Host "Ejecutando con proteccion watchdog activa..." -ForegroundColor Cyan

while ($true) {
    $status = Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock {
        param($taskName)
        $raw = schtasks /Query /TN $taskName /V /FO LIST 2>$null
        ($raw | Select-String "^Status").ToString()
    } -ArgumentList $taskName

    Write-Host "." -NoNewline

    if ($status -match "Ready") { 
        Write-Host "`nCompletado!" -ForegroundColor Green
        break 
    }

    if ((New-TimeSpan -Start $start -End (Get-Date)).TotalSeconds -gt $timeoutSeconds) {
        Write-Host "`nTimeout" -ForegroundColor Yellow
        break
    }

    Start-Sleep -Seconds 5
}


# 6) Resultado
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "LOG DE INSTALACION" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Yellow

Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock {
    param($logPath)
    if (Test-Path $logPath) { Get-Content $logPath }
} -ArgumentList $logPath


# 7) Verificar que el lock fue eliminado
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "VERIFICACION DE SEGURIDAD" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock {
    param($lockFile)
    
    $regPath = "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"
    $current = (Get-ItemProperty -Path $regPath -Name AUOptions -ErrorAction SilentlyContinue).AUOptions
    
    Write-Host "AUOptions actual: $current" -ForegroundColor $(if($current -eq 3){"Green"}else{"Red"})
    
    if (Test-Path $lockFile) {
        Write-Host "ADVERTENCIA: Lock file aun existe - Watchdog lo manejara" -ForegroundColor Yellow
    } else {
        Write-Host "Lock file eliminado - Sistema seguro" -ForegroundColor Green
    }
    
} -ArgumentList $lockFile

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "El Watchdog seguira activo por seguridad" -ForegroundColor White
Write-Host "Para desactivarlo: schtasks /Delete /TN WU_PolicyWatchdog /F" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Cyan
