# =========================
# SOLUCION DEFINITIVA
# Cambia temporalmente AUOptions 3->4, instala, restaura
# =========================

$server = "192.168.11.106"
$cred   = Get-Credential

$taskName   = "ForceInstall_Final"
$scriptPath = "C:\Windows\Temp\wu_final_solution.ps1"
$logPath    = "C:\Windows\Temp\WU_Final.log"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SOLUCION DEFINITIVA - CAMBIO DE POLITICA TEMPORAL" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock {
    param($scriptPath, $logPath)

    if (Test-Path $logPath) { Remove-Item $logPath -Force }

    $scriptContent = @'
"========================================" | Out-File -FilePath "{LOGPATH}" -Append
"=== INSTALACION CON CAMBIO DE POLITICA TEMPORAL ===" | Out-File -FilePath "{LOGPATH}" -Append
"=== Inicio: $(Get-Date) ===" | Out-File -FilePath "{LOGPATH}" -Append
"========================================" | Out-File -FilePath "{LOGPATH}" -Append
"" | Out-File -FilePath "{LOGPATH}" -Append

$regPath = "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"
$valueName = "AUOptions"
$originalValue = $null
$policyChanged = $false

try {
    # PASO 1: Guardar valor original de AUOptions
    "PASO 1: Verificando politica actual..." | Out-File -FilePath "{LOGPATH}" -Append
    
    if (Test-Path $regPath) {
        $originalValue = (Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction SilentlyContinue).$valueName
        "Valor actual de AUOptions: $originalValue" | Out-File -FilePath "{LOGPATH}" -Append
        
        if ($originalValue -eq 3) {
            "La politica esta en modo 3 (Descargar y notificar)" | Out-File -FilePath "{LOGPATH}" -Append
            "Cambiando temporalmente a 4 (Instalacion automatica)..." | Out-File -FilePath "{LOGPATH}" -Append
            
            # Cambiar a 4 (instalacion automatica)
            Set-ItemProperty -Path $regPath -Name $valueName -Value 4 -Type DWord
            $policyChanged = $true
            
            "Politica cambiada exitosamente a 4" | Out-File -FilePath "{LOGPATH}" -Append
            "" | Out-File -FilePath "{LOGPATH}" -Append
            
            # Reiniciar servicio para aplicar cambio
            "Reiniciando servicio Windows Update para aplicar cambios..." | Out-File -FilePath "{LOGPATH}" -Append
            Restart-Service -Name wuauserv -Force
            Start-Sleep -Seconds 5
            "Servicio reiniciado" | Out-File -FilePath "{LOGPATH}" -Append
            
        } else {
            "AUOptions no es 3, no es necesario cambiar" | Out-File -FilePath "{LOGPATH}" -Append
        }
    } else {
        "No existe la ruta de politicas" | Out-File -FilePath "{LOGPATH}" -Append
    }
    
    "" | Out-File -FilePath "{LOGPATH}" -Append
    
    # PASO 2: Forzar instalacion con UsoClient
    "PASO 2: Forzando instalacion con UsoClient..." | Out-File -FilePath "{LOGPATH}" -Append
    
    "  Ejecutando StartScan..." | Out-File -FilePath "{LOGPATH}" -Append
    Start-Process -FilePath "C:\Windows\System32\UsoClient.exe" -ArgumentList "StartScan" -NoNewWindow -Wait
    Start-Sleep -Seconds 5
    
    "  Ejecutando StartDownload..." | Out-File -FilePath "{LOGPATH}" -Append
    Start-Process -FilePath "C:\Windows\System32\UsoClient.exe" -ArgumentList "StartDownload" -NoNewWindow -Wait
    Start-Sleep -Seconds 10
    
    "  Ejecutando StartInstall..." | Out-File -FilePath "{LOGPATH}" -Append
    Start-Process -FilePath "C:\Windows\System32\UsoClient.exe" -ArgumentList "StartInstall" -NoNewWindow -Wait
    
    "UsoClient ejecutado con politica en modo 4" | Out-File -FilePath "{LOGPATH}" -Append
    "" | Out-File -FilePath "{LOGPATH}" -Append
    
    # PASO 3: Usar COM API ahora que la politica permite instalacion
    "PASO 3: Intentando instalacion via COM API..." | Out-File -FilePath "{LOGPATH}" -Append
    
    try {
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()
        $updateSearcher.ServerSelection = 3
        
        "Buscando actualizaciones..." | Out-File -FilePath "{LOGPATH}" -Append
        $searchResult = $updateSearcher.Search("IsInstalled=0 and IsHidden=0")
        
        "Encontradas: $($searchResult.Updates.Count)" | Out-File -FilePath "{LOGPATH}" -Append
        
        if ($searchResult.Updates.Count -gt 0) {
            "" | Out-File -FilePath "{LOGPATH}" -Append
            "Actualizaciones detectadas:" | Out-File -FilePath "{LOGPATH}" -Append
            
            $toInstall = New-Object -ComObject Microsoft.Update.UpdateColl
            
            foreach ($update in $searchResult.Updates) {
                "  - $($update.Title)" | Out-File -FilePath "{LOGPATH}" -Append
                "    IsDownloaded: $($update.IsDownloaded)" | Out-File -FilePath "{LOGPATH}" -Append
                
                if ($update.EulaAccepted -eq $false) {
                    $update.AcceptEula()
                }
                $toInstall.Add($update) | Out-Null
            }
            
            "" | Out-File -FilePath "{LOGPATH}" -Append
            "Instalando $($toInstall.Count) actualizaciones..." | Out-File -FilePath "{LOGPATH}" -Append
            
            $installer = $updateSession.CreateUpdateInstaller()
            $installer.Updates = $toInstall
            $installResult = $installer.Install()
            
            "" | Out-File -FilePath "{LOGPATH}" -Append
            "========================================" | Out-File -FilePath "{LOGPATH}" -Append
            "RESULTADO DE INSTALACION" | Out-File -FilePath "{LOGPATH}" -Append
            "========================================" | Out-File -FilePath "{LOGPATH}" -Append
            "ResultCode: $($installResult.ResultCode)" | Out-File -FilePath "{LOGPATH}" -Append
            "  (2=Succeeded, 3=SucceededWithErrors, 4=Failed)" | Out-File -FilePath "{LOGPATH}" -Append
            "RebootRequired: $($installResult.RebootRequired)" | Out-File -FilePath "{LOGPATH}" -Append
            "" | Out-File -FilePath "{LOGPATH}" -Append
            
            for ($i = 0; $i -lt $toInstall.Count; $i++) {
                $update = $toInstall.Item($i)
                $result = $installResult.GetUpdateResult($i)
                "  $($update.Title)" | Out-File -FilePath "{LOGPATH}" -Append
                "    Result: $($result.ResultCode)" | Out-File -FilePath "{LOGPATH}" -Append
                "    HResult: $($result.HResult)" | Out-File -FilePath "{LOGPATH}" -Append
            }
            
            "" | Out-File -FilePath "{LOGPATH}" -Append
            
            if ($installResult.RebootRequired) {
                "REINICIO REQUERIDO - Programando en 3 minutos..." | Out-File -FilePath "{LOGPATH}" -Append
                shutdown /r /t 180 /c "Reiniciando para completar Windows Updates"
            }
            
        } else {
            "No se encontraron actualizaciones pendientes en COM API" | Out-File -FilePath "{LOGPATH}" -Append
            "Puede que UsoClient ya este instalandolas en segundo plano" | Out-File -FilePath "{LOGPATH}" -Append
        }
        
    } catch {
        "ERROR en COM API: $($_.Exception.Message)" | Out-File -FilePath "{LOGPATH}" -Append
    }
    
    "" | Out-File -FilePath "{LOGPATH}" -Append
    
    # PASO 4: Esperar y verificar
    "PASO 4: Esperando 30 segundos para que las instalaciones completen..." | Out-File -FilePath "{LOGPATH}" -Append
    Start-Sleep -Seconds 30
    
    # PASO 5: RESTAURAR politica original
    if ($policyChanged -and $originalValue -ne $null) {
        "" | Out-File -FilePath "{LOGPATH}" -Append
        "========================================" | Out-File -FilePath "{LOGPATH}" -Append
        "PASO 5: RESTAURANDO POLITICA ORIGINAL" | Out-File -FilePath "{LOGPATH}" -Append
        "========================================" | Out-File -FilePath "{LOGPATH}" -Append
        
        "Restaurando AUOptions a valor original: $originalValue" | Out-File -FilePath "{LOGPATH}" -Append
        Set-ItemProperty -Path $regPath -Name $valueName -Value $originalValue -Type DWord
        
        "Politica restaurada exitosamente" | Out-File -FilePath "{LOGPATH}" -Append
        
        # Reiniciar servicio para aplicar
        Restart-Service -Name wuauserv -Force
        "Servicio Windows Update reiniciado" | Out-File -FilePath "{LOGPATH}" -Append
    }
    
    "" | Out-File -FilePath "{LOGPATH}" -Append
    
} catch {
    "========================================" | Out-File -FilePath "{LOGPATH}" -Append
    "ERROR CRITICO" | Out-File -FilePath "{LOGPATH}" -Append
    "========================================" | Out-File -FilePath "{LOGPATH}" -Append
    "Mensaje: $($_.Exception.Message)" | Out-File -FilePath "{LOGPATH}" -Append
    
    # Intentar restaurar politica en caso de error
    if ($policyChanged -and $originalValue -ne $null) {
        "" | Out-File -FilePath "{LOGPATH}" -Append
        "Intentando restaurar politica tras error..." | Out-File -FilePath "{LOGPATH}" -Append
        try {
            Set-ItemProperty -Path $regPath -Name $valueName -Value $originalValue -Type DWord
            "Politica restaurada" | Out-File -FilePath "{LOGPATH}" -Append
        } catch {
            "ERROR al restaurar politica: $($_.Exception.Message)" | Out-File -FilePath "{LOGPATH}" -Append
        }
    }
}

"" | Out-File -FilePath "{LOGPATH}" -Append
"========================================" | Out-File -FilePath "{LOGPATH}" -Append
"=== Finalizado: $(Get-Date) ===" | Out-File -FilePath "{LOGPATH}" -Append
"========================================" | Out-File -FilePath "{LOGPATH}" -Append
'@

    $scriptContent = $scriptContent -replace '{LOGPATH}', $logPath
    $scriptContent | Set-Content -Path $scriptPath -Encoding UTF8

    "Script preparado"
} -ArgumentList $scriptPath, $logPath


Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock {
    param($taskName, $scriptPath)

    $runTime = (Get-Date).AddMinutes(1).ToString("HH:mm")

    schtasks /Create /TN $taskName `
      /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" `
      /SC ONCE /ST $runTime /RU "SYSTEM" /RL HIGHEST /F | Out-Null

    schtasks /Run /TN $taskName | Out-Null

    "Tarea lanzada"
} -ArgumentList $taskName, $scriptPath


$timeoutSeconds = 120
$start = Get-Date

Write-Host "Ejecutando instalacion con cambio temporal de politica..." -ForegroundColor Cyan

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


Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "LOG DE INSTALACION" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Yellow

Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock {
    param($logPath)
    if (Test-Path $logPath) { Get-Content $logPath }
} -ArgumentList $logPath

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "VERIFICACION DE POLITICA" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock {
    $regPath = "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"
    $current = (Get-ItemProperty -Path $regPath -Name AUOptions -ErrorAction SilentlyContinue).AUOptions
    Write-Host "AUOptions actual: $current (debe ser 3 si se restauro correctamente)" -ForegroundColor $(if($current -eq 3){"Green"}else{"Yellow"})
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "ACCIONES RECOMENDADAS:" -ForegroundColor Cyan
Write-Host "1. Espera 2-3 minutos" -ForegroundColor White
Write-Host "2. Verifica Windows Update manualmente" -ForegroundColor White
Write-Host "3. Si hay reinicio programado, se ejecutara en 3 minutos" -ForegroundColor White
Write-Host "4. Cancela reinicio con: shutdown /a" -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Cyan
