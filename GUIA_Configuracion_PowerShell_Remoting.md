# Guía Completa: Configuración de Comunicación Remota
## PC Madre (Windows) ↔️ Servidor Hijo (Windows Server)

---

## 📋 Tabla de Contenidos

1. [Requisitos Previos](#requisitos-previos)
2. [Configuración en el Servidor](#configuración-en-el-servidor)
3. [Configuración en el PC Madre](#configuración-en-el-pc-madre)
4. [Pruebas de Conectividad](#pruebas-de-conectividad)
5. [Solución de Problemas](#solución-de-problemas)
6. [Configuración Avanzada](#configuración-avanzada)
7. [Checklist Final](#checklist-final)

---

## 🎯 Requisitos Previos

### Hardware y Red
- ✅ Ambos equipos en la misma red o con conectividad IP directa
- ✅ Puertos de red abiertos (5985 para HTTP, 5986 para HTTPS)
- ✅ Privilegios de administrador en ambos equipos

### Software
- ✅ Windows 10/11 en PC Madre
- ✅ Windows Server 2016/2019/2022 en Servidor
- ✅ PowerShell 5.1 o superior (incluido en Windows)

### Credenciales
- Usuario con permisos de administrador en el Servidor
- Puede ser usuario local (`.\Administrador`) o de dominio (`DOMAIN\usuario`)

---

## 🖥️ Configuración en el Servidor

### Paso 1: Habilitar PowerShell Remoting

**Abrir PowerShell como ADMINISTRADOR en el SERVIDOR** y ejecutar:

```powershell
Enable-PSRemoting -Force
```

Esto automáticamente:
- ✅ Inicia el servicio WinRM
- ✅ Configura WinRM para inicio automático
- ✅ Crea reglas de firewall
- ✅ Configura listener en HTTP

**Verificar que funcionó:**
```powershell
Get-Service WinRM
```
✅ Debe mostrar: `Status = Running`

---

### Paso 2: Configurar Firewall

Si `Enable-PSRemoting` no creó las reglas automáticamente:

```powershell
# Regla para HTTP (puerto 5985)
New-NetFirewallRule -Name "WinRM-HTTP-In" `
    -DisplayName "Windows Remote Management (HTTP-In)" `
    -Protocol TCP `
    -LocalPort 5985 `
    -Action Allow `
    -Direction Inbound `
    -Enabled True

# Regla para HTTPS (puerto 5986) - Opcional
New-NetFirewallRule -Name "WinRM-HTTPS-In" `
    -DisplayName "Windows Remote Management (HTTPS-In)" `
    -Protocol TCP `
    -LocalPort 5986 `
    -Action Allow `
    -Direction Inbound `
    -Enabled True
```

---

### Paso 3: Configurar TrustedHosts

⚠️ **Solo necesario si NO estás en un dominio Active Directory**

```powershell
# Ver configuración actual
Get-Item WSMan:\localhost\Client\TrustedHosts

# Opción 1: Agregar IP específica del PC Madre (MÁS SEGURO)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.1.100" -Force

# Opción 2: Agregar toda la subnet
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.1.*" -Force

# Opción 3: Permitir cualquier equipo (SOLO PARA TESTING)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
```

---

### Paso 4: Verificar Configuración

```powershell
# Verificar que WinRM esté configurado
winrm quickconfig

# Debe responder: "WinRM is already set up to receive requests"

# Ver listeners activos
winrm enumerate winrm/config/listener
```

✅ Debe mostrar al menos un listener HTTP en puerto 5985

---

## 💻 Configuración en el PC Madre

### Paso 1: Habilitar Cliente WinRM

**Abrir PowerShell como ADMINISTRADOR en el PC MADRE** y ejecutar:

```powershell
Enable-PSRemoting -Force
```

---

### Paso 2: Configurar TrustedHosts

Agregar el servidor a la lista de hosts confiables:

```powershell
# Ver configuración actual
Get-Item WSMan:\localhost\Client\TrustedHosts

# Agregar IP del servidor (ejemplo: 192.168.11.106)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.11.106" -Force

# O agregar por nombre
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "VM-FEEDSTATION" -Force

# O agregar múltiples servidores
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.11.106,192.168.11.107" -Force
```

---

### Paso 3: Verificar Servicio

```powershell
Get-Service WinRM
```
✅ Debe estar `Running`

---

## 🧪 Pruebas de Conectividad

### Test 1: Conectividad de Red

```powershell
Test-NetConnection -ComputerName 192.168.11.106 -Port 5985
```
✅ Debe mostrar: `TcpTestSucceeded : True`

---

### Test 2: Conectividad WinRM

```powershell
Test-WSMan -ComputerName 192.168.11.106
```
✅ Si funciona, mostrará información del servidor remoto

---

### Test 3: Con Credenciales

```powershell
$cred = Get-Credential
Test-WSMan -ComputerName 192.168.11.106 -Credential $cred
```

---

### Test 4: Ejecutar Comando Remoto

```powershell
$cred = Get-Credential

Invoke-Command -ComputerName 192.168.11.106 -Credential $cred -ScriptBlock {
    Get-ComputerInfo | Select-Object CsName, WindowsVersion, OsArchitecture
}
```
✅ Si funciona, debe mostrar información del servidor

---

### Test 5: Sesión Interactiva (Opcional)

```powershell
Enter-PSSession -ComputerName 192.168.11.106 -Credential $cred

# Tu prompt cambiará a: [192.168.11.106]: PS C:\>
# Ahora estás "dentro" del servidor

# Para salir:
Exit-PSSession
```

---

## 🔧 Solución de Problemas

### Problema 1: "Access is denied"

**Causa:** Credenciales incorrectas o usuario sin permisos

**Solución:**
```powershell
# En el servidor, verificar que el usuario sea administrador
Get-LocalGroupMember -Group "Administradores"
```

---

### Problema 2: "The WinRM client cannot process the request"

**Causa:** Servidor no está en TrustedHosts

**Solución:**
```powershell
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "IP_DEL_SERVIDOR" -Force
```

---

### Problema 3: "WinRM cannot complete the operation"

**Causa:** Firewall bloqueando

**Solución en el SERVIDOR:**
```powershell
# Verificar reglas de firewall
Get-NetFirewallRule -Name "WinRM*" | Select-Object Name, Enabled, Direction

# Si están deshabilitadas, habilitarlas
Enable-NetFirewallRule -Name "WinRM-HTTP-In-TCP"
```

---

### Problema 4: Timeout al Conectar

**Causa:** Servidor apagado o red inaccesible

**Solución:**
```powershell
# 1. Verificar conectividad básica
Test-Connection -ComputerName 192.168.11.106 -Count 2

# 2. Verificar que el servidor esté encendido
```

---

### Problema 5: "Cannot find the computer"

**Causa:** Problema de resolución DNS

**Solución:**
1. Usar IP en lugar de nombre
2. Agregar entrada en archivo hosts:
   - Editar: `C:\Windows\System32\drivers\etc\hosts`
   - Agregar línea: `192.168.11.106    VM-FEEDSTATION`

---

## ⚙️ Configuración Avanzada (Opcional)

### Aumentar Límites de Memoria y Timeouts

Para scripts largos, **ejecutar en el SERVIDOR:**

```powershell
# Aumentar MaxMemoryPerShellMB (default: 1024 MB)
Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB -Value 2048

# Aumentar MaxShellsPerUser (default: 25)
Set-Item WSMan:\localhost\Shell\MaxShellsPerUser -Value 50

# Aumentar timeout (en milisegundos, default: 60000 = 60 seg)
Set-Item WSMan:\localhost\MaxTimeoutms -Value 180000
```

---

### Configurar HTTPS (Más Seguro)

**En el SERVIDOR:**

```powershell
# Crear certificado autofirmado
$cert = New-SelfSignedCertificate -DnsName "VM-FEEDSTATION" -CertStoreLocation Cert:\LocalMachine\My

# Obtener thumbprint
$thumbprint = $cert.Thumbprint

# Crear listener HTTPS
New-Item -Path WSMan:\LocalHost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $thumbprint -Force

# Verificar
Get-ChildItem WSMan:\localhost\Listener\
```

---

### Habilitar Logging y Auditoría

**En el SERVIDOR:**

```powershell
# Habilitar log operacional
wevtutil sl Microsoft-Windows-WinRM/Operational /e:true

# Ver logs
Get-WinEvent -LogName "Microsoft-Windows-WinRM/Operational" -MaxEvents 20
```

---

## ✅ Checklist Final

### En el SERVIDOR:
- [ ] `Enable-PSRemoting` ejecutado
- [ ] Servicio WinRM corriendo
- [ ] Firewall permite puerto 5985
- [ ] TrustedHosts configurado (si no hay dominio)
- [ ] `Test-WSMan` funciona localmente

### En el PC MADRE:
- [ ] `Enable-PSRemoting` ejecutado
- [ ] TrustedHosts incluye IP del servidor
- [ ] `Test-NetConnection` exitoso al puerto 5985
- [ ] `Test-WSMan` exitoso con credenciales
- [ ] `Invoke-Command` funciona correctamente

### Seguridad:
- [ ] Credenciales guardadas de forma segura
- [ ] TrustedHosts limitado a IPs específicas (no "*")
- [ ] Considerar usar HTTPS en producción
- [ ] Auditar accesos regularmente

---

## 🔍 Script de Diagnóstico Completo

Ejecutar en el **PC MADRE** para diagnosticar problemas:

```powershell
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

# Test 3: WinRM básico
Write-Host "3. Test de WinRM basico..." -ForegroundColor Yellow
try {
    Test-WSMan -ComputerName $servidor -ErrorAction Stop | Out-Null
    Write-Host "   Resultado: OK" -ForegroundColor Green
} catch {
    Write-Host "   Resultado: Requiere credenciales" -ForegroundColor Yellow
}

# Test 4: WinRM con credenciales
Write-Host "4. Test con credenciales..." -ForegroundColor Yellow
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
    Write-Host "   Resultado: FALLO" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== DIAGNOSTICO COMPLETO ===" -ForegroundColor Cyan
```

---

## 📚 Información Adicional

### Puertos Utilizados
- **HTTP:** 5985
- **HTTPS:** 5986

### Permisos Mínimos Requeridos
- Miembro del grupo "Administradores" en el servidor remoto
- O miembro del grupo "Remote Management Users" (para comandos específicos)

### Mejores Prácticas de Seguridad
1. ✅ Usar HTTPS en producción
2. ✅ Limitar TrustedHosts a IPs específicas
3. ✅ Usar cuentas de servicio dedicadas
4. ✅ Rotar credenciales regularmente
5. ✅ Auditar logs de acceso remoto
6. ✅ Usar autenticación Kerberos cuando sea posible

---

## 📞 Documentación Oficial

- [Microsoft Docs - PowerShell Remoting](https://docs.microsoft.com/en-us/powershell/scripting/learn/remoting/running-remote-commands)
- [About Remote Troubleshooting](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_remote_troubleshooting)

---

**Versión del documento:** 1.0  
**Fecha:** Febrero 2026  
**Autor:** Equipo de IT
