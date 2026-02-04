# ========================================
# GUIA COMPLETA: CONFIGURACION DE COMUNICACION REMOTA
# PC Madre (Windows) -> Servidor Hijo (Windows Server)
# ========================================

## TABLA DE CONTENIDOS
1. Requisitos Previos
2. Configuracion en el SERVIDOR (Windows Server)
3. Configuracion en el PC MADRE (Windows)
4. Pruebas de Conectividad
5. Solucion de Problemas Comunes
6. Configuracion Avanzada (Opcional)

# ========================================
# 1. REQUISITOS PREVIOS
# ========================================

## Hardware/Red:
- Ambos equipos en la misma red o con conectividad IP directa
- Puertos de red abiertos (ver seccion de puertos)
- Privilegios de administrador en ambos equipos

## Software:
- Windows 10/11 en PC Madre
- Windows Server 2016/2019/2022 en Servidor
- PowerShell 5.1 o superior (ya incluido en Windows)

## Credenciales:
- Usuario con permisos de administrador en el Servidor
- Puede ser:
  * Usuario local del servidor (ej: .\Administrador)
  * Usuario de dominio (ej: DOMAIN\usuario)

# ========================================
# 2. CONFIGURACION EN EL SERVIDOR (Windows Server)
# ========================================

## PASO 2.1: Habilitar PowerShell Remoting
## ---------------------------------------
## Ejecutar en PowerShell como ADMINISTRADOR en el SERVIDOR:

Enable-PSRemoting -Force

# Esto hace automaticamente:
# - Inicia el servicio WinRM
# - Configura WinRM para inicio automatico
# - Crea reglas de firewall
# - Configura listener en HTTP

## Verificar que se habilito correctamente:
Get-Service WinRM

# Debe mostrar: Status = Running


## PASO 2.2: Configurar Firewall (si es necesario)
## ------------------------------------------------
## Si Enable-PSRemoting no creo las reglas automaticamente:

# Regla para WinRM HTTP (puerto 5985)
New-NetFirewallRule -Name "WinRM-HTTP-In" `
    -DisplayName "Windows Remote Management (HTTP-In)" `
    -Protocol TCP `
    -LocalPort 5985 `
    -Action Allow `
    -Direction Inbound `
    -Enabled True

# Regla para WinRM HTTPS (puerto 5986) - Opcional pero recomendado
New-NetFirewallRule -Name "WinRM-HTTPS-In" `
    -DisplayName "Windows Remote Management (HTTPS-In)" `
    -Protocol TCP `
    -LocalPort 5986 `
    -Action Allow `
    -Direction Inbound `
    -Enabled True


## PASO 2.3: Configurar TrustedHosts (si NO estas en dominio)
## -----------------------------------------------------------
## Esto permite que el servidor acepte conexiones del PC Madre

# Ver configuracion actual:
Get-Item WSMan:\localhost\Client\TrustedHosts

# Agregar IP del PC Madre (reemplaza con tu IP real):
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.1.100" -Force

# O permitir toda la subnet (menos seguro pero mas flexible):
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.1.*" -Force

# O permitir cualquier equipo (SOLO para testing):
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force


## PASO 2.4: Verificar configuracion de WinRM
## -------------------------------------------
winrm quickconfig

# Debe responder: "WinRM is already set up to receive requests"


## PASO 2.5: Verificar Listeners activos
## --------------------------------------
winrm enumerate winrm/config/listener

# Debe mostrar al menos un listener HTTP en puerto 5985


## PASO 2.6: Crear usuario para administracion remota (Opcional)
## --------------------------------------------------------------
## Si quieres un usuario dedicado para las tareas automatizadas:

# Crear usuario local
$password = ConvertTo-SecureString "Password123!" -AsPlainText -Force
New-LocalUser -Name "WUAdmin" -Password $password -Description "Usuario para Windows Update remoto"

# Agregar al grupo de administradores
Add-LocalGroupMember -Group "Administradores" -Member "WUAdmin"

# Nota: Guarda estas credenciales de forma segura


# ========================================
# 3. CONFIGURACION EN EL PC MADRE (Windows)
# ========================================

## PASO 3.1: Habilitar cliente WinRM
## ----------------------------------
## Ejecutar en PowerShell como ADMINISTRADOR en el PC MADRE:

Enable-PSRemoting -Force

# Esto prepara el PC para enviar comandos remotos


## PASO 3.2: Configurar TrustedHosts en el PC
## -------------------------------------------
## Agregar el servidor a la lista de hosts confiables:

# Ver configuracion actual:
Get-Item WSMan:\localhost\Client\TrustedHosts

# Agregar IP del servidor (ejemplo: 192.168.11.106):
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.11.106" -Force

# O agregar por nombre:
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "VM-FEEDSTATION" -Force

# O agregar multiples servidores:
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.11.106,192.168.11.107" -Force


## PASO 3.3: Verificar servicio WinRM
## -----------------------------------
Get-Service WinRM

# Debe estar Running


# ========================================
# 4. PRUEBAS DE CONECTIVIDAD
# ========================================

## PRUEBA 4.1: Test de conectividad basico
## ----------------------------------------
## Desde el PC MADRE, ejecutar:

Test-NetConnection -ComputerName 192.168.11.106 -Port 5985

# Debe mostrar: TcpTestSucceeded : True


## PRUEBA 4.2: Test de WinRM
## --------------------------
Test-WSMan -ComputerName 192.168.11.106

# Si funciona, mostrara informacion del servidor remoto
# Si falla, mostrara un error especifico


## PRUEBA 4.3: Conexion con credenciales
## --------------------------------------
$cred = Get-Credential
# Ingresar: usuario y contraseña del servidor

Test-WSMan -ComputerName 192.168.11.106 -Credential $cred


## PRUEBA 4.4: Ejecutar comando remoto simple
## -------------------------------------------
$cred = Get-Credential

Invoke-Command -ComputerName 192.168.11.106 -Credential $cred -ScriptBlock {
    Get-ComputerInfo | Select-Object CsName, WindowsVersion, OsArchitecture
}

# Si funciona, debe mostrar informacion del servidor


## PRUEBA 4.5: Sesion interactiva (Opcional)
## ------------------------------------------
Enter-PSSession -ComputerName 192.168.11.106 -Credential $cred

# Ahora estas "dentro" del servidor
# Tu prompt cambiara a: [192.168.11.106]: PS C:\>
# Ejecuta comandos como si estuvieras fisicamente ahi

# Para salir:
Exit-PSSession


# ========================================
# 5. SOLUCION DE PROBLEMAS COMUNES
# ========================================

## PROBLEMA 5.1: "Access is denied"
## ---------------------------------
# CAUSA: Credenciales incorrectas o usuario sin permisos
# SOLUCION:
# 1. Verificar usuario y contraseña
# 2. Verificar que el usuario sea administrador:
Get-LocalGroupMember -Group "Administradores"


## PROBLEMA 5.2: "The WinRM client cannot process the request"
## ------------------------------------------------------------
# CAUSA: Servidor no esta en TrustedHosts
# SOLUCION:
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "IP_DEL_SERVIDOR" -Force


## PROBLEMA 5.3: "WinRM cannot complete the operation"
## ----------------------------------------------------
# CAUSA: Firewall bloqueando
# SOLUCION en el SERVIDOR:
# Verificar reglas de firewall:
Get-NetFirewallRule -Name "WinRM*" | Select-Object Name, Enabled, Direction

# Si estan deshabilitadas, habilitarlas:
Enable-NetFirewallRule -Name "WinRM-HTTP-In-TCP"


## PROBLEMA 5.4: Timeout al conectar
## ----------------------------------
# CAUSA: Servidor apagado o red inaccesible
# SOLUCION:
# 1. Verificar que el servidor este encendido
# 2. Hacer ping:
Test-Connection -ComputerName 192.168.11.106 -Count 2

# 3. Verificar que no haya firewalls externos bloqueando


## PROBLEMA 5.5: "Cannot find the computer"
## -----------------------------------------
# CAUSA: Problema de resolucion DNS
# SOLUCION:
# 1. Usar IP en lugar de nombre
# 2. Agregar entrada en archivo hosts:
# C:\Windows\System32\drivers\etc\hosts
# Agregar linea: 192.168.11.106    VM-FEEDSTATION


## PROBLEMA 5.6: "The SSL connection cannot be established"
## ---------------------------------------------------------
# CAUSA: Intentando usar HTTPS sin certificado
# SOLUCION TEMPORAL: Usar HTTP (puerto 5985)
# SOLUCION PERMANENTE: Ver seccion 6.2 para configurar HTTPS


# ========================================
# 6. CONFIGURACION AVANZADA (Opcional)
# ========================================

## 6.1: Configurar WinRM para HTTPS (Mas Seguro)
## ----------------------------------------------
## En el SERVIDOR:

# Crear certificado autofirmado
$cert = New-SelfSignedCertificate -DnsName "VM-FEEDSTATION" -CertStoreLocation Cert:\LocalMachine\My

# Obtener thumbprint
$thumbprint = $cert.Thumbprint

# Crear listener HTTPS
New-Item -Path WSMan:\LocalHost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $thumbprint -Force

# Verificar
Get-ChildItem WSMan:\localhost\Listener\


## 6.2: Aumentar limites de memoria y timeouts
## --------------------------------------------
## En el SERVIDOR (para scripts largos):

# Aumentar MaxMemoryPerShellMB (default: 1024 MB)
Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB -Value 2048

# Aumentar MaxShellsPerUser (default: 25)
Set-Item WSMan:\localhost\Shell\MaxShellsPerUser -Value 50

# Aumentar timeout (en milisegundos, default: 60000 = 60 seg)
Set-Item WSMan:\localhost\MaxTimeoutms -Value 180000


## 6.3: Configurar autenticacion Kerberos (en dominio)
## ----------------------------------------------------
## Si ambos equipos estan en Active Directory:

# Verificar que Kerberos este habilitado:
Get-Item WSMan:\localhost\Service\Auth\Kerberos

# Si es False, habilitar:
Set-Item WSMan:\localhost\Service\Auth\Kerberos -Value $true


## 6.4: Logging y auditoria
## -------------------------
## Habilitar logging de WinRM en el SERVIDOR:

# Habilitar log operacional
wevtutil sl Microsoft-Windows-WinRM/Operational /e:true

# Ver logs:
Get-WinEvent -LogName "Microsoft-Windows-WinRM/Operational" -MaxEvents 20


## 6.5: Crear perfil de sesion personalizado
## ------------------------------------------
## Para optimizar sesiones remotas repetidas:

$sessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck
$session = New-PSSession -ComputerName 192.168.11.106 -Credential $cred -SessionOption $sessionOption

# Usar la sesion:
Invoke-Command -Session $session -ScriptBlock { Get-Service }

# Cerrar cuando termines:
Remove-PSSession $session


# ========================================
# 7. CHECKLIST FINAL DE CONFIGURACION
# ========================================

## EN EL SERVIDOR:
# [ ] Enable-PSRemoting ejecutado
# [ ] Servicio WinRM corriendo
# [ ] Firewall permite puerto 5985
# [ ] TrustedHosts configurado (si no hay dominio)
# [ ] Test-WSMan funciona localmente

## EN EL PC MADRE:
# [ ] Enable-PSRemoting ejecutado
# [ ] TrustedHosts incluye IP del servidor
# [ ] Test-NetConnection exitoso al puerto 5985
# [ ] Test-WSMan exitoso con credenciales
# [ ] Invoke-Command funciona correctamente

## SEGURIDAD:
# [ ] Credenciales guardadas de forma segura
# [ ] TrustedHosts limitado a IPs especificas (no "*")
# [ ] Considerar usar HTTPS en produccion
# [ ] Auditar accesos regularmente


# ========================================
# 8. COMANDOS DE DIAGNOSTICO RAPIDO
# ========================================

## Script de diagnostico completo (ejecutar en PC MADRE):

$servidor = "192.168.11.106"

Write-Host "=== DIAGNOSTICO DE CONECTIVIDAD ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Ping
Write-Host "1. Test de PING..." -ForegroundColor Yellow
$ping = Test-Connection -ComputerName $servidor -Count 2 -Quiet
Write-Host "   Resultado: $($ping ? 'OK' : 'FALLO')" -ForegroundColor $($ping ? 'Green' : 'Red')

# Test 2: Puerto WinRM
Write-Host "2. Test de Puerto 5985..." -ForegroundColor Yellow
$port = Test-NetConnection -ComputerName $servidor -Port 5985 -WarningAction SilentlyContinue
Write-Host "   Resultado: $($port.TcpTestSucceeded ? 'OK' : 'FALLO')" -ForegroundColor $($port.TcpTestSucceeded ? 'Green' : 'Red')

# Test 3: WinRM sin credenciales
Write-Host "3. Test de WinRM basico..." -ForegroundColor Yellow
try {
    Test-WSMan -ComputerName $servidor -ErrorAction Stop | Out-Null
    Write-Host "   Resultado: OK" -ForegroundColor Green
} catch {
    Write-Host "   Resultado: FALLO - Requiere credenciales" -ForegroundColor Yellow
}

# Test 4: WinRM con credenciales
Write-Host "4. Test de WinRM con credenciales..." -ForegroundColor Yellow
$cred = Get-Credential -Message "Ingrese credenciales del servidor"
try {
    Test-WSMan -ComputerName $servidor -Credential $cred -ErrorAction Stop | Out-Null
    Write-Host "   Resultado: OK" -ForegroundColor Green
} catch {
    Write-Host "   Resultado: FALLO - $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Comando remoto
Write-Host "5. Test de comando remoto..." -ForegroundColor Yellow
try {
    $result = Invoke-Command -ComputerName $servidor -Credential $cred -ScriptBlock { $env:COMPUTERNAME } -ErrorAction Stop
    Write-Host "   Resultado: OK - Conectado a $result" -ForegroundColor Green
} catch {
    Write-Host "   Resultado: FALLO - $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== DIAGNOSTICO COMPLETO ===" -ForegroundColor Cyan


# ========================================
# 9. REFERENCIAS Y RECURSOS ADICIONALES
# ========================================

## Documentacion oficial de Microsoft:
# https://docs.microsoft.com/en-us/powershell/scripting/learn/remoting/running-remote-commands

## Puertos usados por WinRM:
# HTTP:  5985
# HTTPS: 5986

## Permisos minimos requeridos:
# - Miembro del grupo "Administradores" en el servidor remoto
# - O miembro del grupo "Remote Management Users" (solo para comandos especificos)

## Mejores practicas de seguridad:
# 1. Usar HTTPS en produccion
# 2. Limitar TrustedHosts a IPs especificas
# 3. Usar cuentas de servicio dedicadas
# 4. Rotar credenciales regularmente
# 5. Auditar logs de acceso remoto
# 6. Usar autenticacion Kerberos cuando sea posible


# ========================================
# FIN DE LA GUIA
# ========================================
