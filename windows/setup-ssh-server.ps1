<#
.SYNOPSIS
  Configura (o deshace) un laboratorio local de OpenSSH Server en Windows.

.DESCRIPTION
  Requiere ejecutarse como Administrador en el equipo de destino Y con
  consentimiento del propietario. No oculta servicios, no crea tareas
  programadas, no modifica el Registro para arranque silencioso y no evita
  antivirus. Todo lo que crea se elimina con -Uninstall.

.EXAMPLE
  .\setup-ssh-server.ps1 -PublicKeyPath .\lab_ed25519.pub
  .\setup-ssh-server.ps1 -PublicKeyPath .\lab_ed25519.pub -Autostart
  .\setup-ssh-server.ps1 -Uninstall
#>
#Requires -RunAsAdministrator
[CmdletBinding(DefaultParameterSetName = 'Install')]
param(
  [Parameter(ParameterSetName='Install', Mandatory=$true)]
  [string]$PublicKeyPath,

  [string]$UserName = 'labremote',

  [Parameter(ParameterSetName='Install')]
  [switch]$Autostart,

  [Parameter(ParameterSetName='Install')]
  [switch]$Force,

  [Parameter(ParameterSetName='Uninstall', Mandatory=$true)]
  [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$FirewallRuleName = 'SSHD-Lab'
$SshDir = Join-Path $env:ProgramData 'ssh'
$CfgPath = Join-Path $SshDir 'sshd_config'
$BakPath = "$CfgPath.lab-bak"
$KeysDir = Join-Path $SshDir 'authorized_keys_lab'

function Get-PrivateSubnetCidr {
  $nics = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled = True' |
          Where-Object { $_.DefaultGateway } | Sort-Object InterfaceIndex
  if (-not $nics) { throw 'No encuentro una interfaz de red con gateway. ¿Estás en la LAN?' }

  foreach ($nic in $nics) {
    for ($i = 0; $i -lt $nic.IPAddress.Count; $i++) {
      $addr = $nic.IPAddress[$i]
      $mask = $nic.IPSubnet[$i]
      if ($addr -notmatch '^\d+\.\d+\.\d+\.\d+$') { continue }
      if ($mask -notmatch '^\d+\.\d+\.\d+\.\d+$') { continue }

      $ipBytes   = [System.Net.IPAddress]::Parse($addr).GetAddressBytes()
      $maskBytes = [System.Net.IPAddress]::Parse($mask).GetAddressBytes()
      [array]::Reverse($ipBytes)
      [array]::Reverse($maskBytes)

      $bits = 0
      foreach ($b in $maskBytes) { $bits += ([Convert]::ToString($b, 2)).ToCharArray() | Where-Object { $_ -eq '1' } | Measure-Object | Select-Object -ExpandProperty Count }
      $netBytes = [byte[]]@(for ($j = 0; $j -lt 4; $j++) { $ipBytes[$j] -band $maskBytes[$j] })
      [array]::Reverse($netBytes)
      $cidr = "$(([System.Net.IPAddress]::new($netBytes)).ToString())/$bits"

      $addrBytes = [System.Net.IPAddress]::Parse($addr).GetAddressBytes()
      $first = [int]$addrBytes[0]
      $second = [int]$addrBytes[1]
      $isPrivate = ($first -eq 10) -or
                   ($first -eq 192 -and $second -eq 168) -or
                   ($first -eq 172 -and $second -ge 16 -and $second -le 31)
      if ($isPrivate) { return [pscustomobject]@{ Address = $addr; Cidr = $cidr } }
    }
  }
  throw 'Solo se detectaron IP públicas. Este laboratorio exige una red privada (RFC1918).'
}

function Assert-PublicKeyFile {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "No encuentro la clave pública: $Path" }
  $content = Get-Content -LiteralPath $Path -Raw
  if ($content -notmatch '^(ssh-ed25519|ecdsa-sha2-nistp256|ssh-rsa)\s+[A-Za-z0-9+/=]+') {
    throw "El archivo '$Path' no parece una clave pública OpenSSH válida."
  }
}

if ($Uninstall) {
  Write-Host '== Desinstalando laboratorio SSH ==' -ForegroundColor Yellow

  if (Get-Service -Name sshd -ErrorAction SilentlyContinue) {
    Stop-Service -Name sshd -Force -ErrorAction SilentlyContinue
    Set-Service -Name sshd -StartupType Manual -ErrorAction SilentlyContinue
  }
  Remove-NetFirewallRule -Name $FirewallRuleName -ErrorAction SilentlyContinue
  if (Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue) {
    Remove-LocalUser -Name $UserName
  }
  if (Test-Path -LiteralPath $KeysDir) { Remove-Item -LiteralPath $KeysDir -Recurse -Force }
  if (Test-Path -LiteralPath $BakPath) {
    Copy-Item -LiteralPath $BakPath -Destination $CfgPath -Force
    Remove-Item -LiteralPath $BakPath -Force
    Write-Host "sshd_config restaurado desde copia de seguridad." -ForegroundColor Green
  } else {
    Write-Warning 'No había copia de seguridad de sshd_config; revisa el archivo manualmente.'
  }
  Write-Host "Hecho. Usuario '$UserName', regla '$FirewallRuleName' y claves eliminados." -ForegroundColor Green
  return
}

# -------------------- Instalación --------------------
Assert-PublicKeyFile -Path $PublicKeyPath
$net = Get-PrivateSubnetCidr
Write-Host "Red detectada: $($net.Address) -> $($net.Cidr)" -ForegroundColor Cyan

$cap = Get-WindowsCapability -Online -ErrorAction Stop |
       Where-Object { $_.Name -like 'OpenSSH.Server*' } | Select-Object -First 1
if (-not $cap) { throw 'No encuentro la característica OpenSSH.Server en este Windows.' }
if ($cap.State -ne 'Installed') {
  Write-Host 'Instalando OpenSSH.Server...' -ForegroundColor Cyan
  Add-WindowsCapability -Online -Name $cap.Name | Out-Null
}

if (-not (Test-Path -LiteralPath $SshDir)) { New-Item -ItemType Directory -Path $SshDir | Out-Null }

# Usuario dedicado (la contraseña es aleatoria y no se usa: solo clave pública).
if (Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue) {
  if (-not $Force) {
    Write-Warning "El usuario '$UserName' ya existe. Se reutilizará. Usa -Force si quieres recrear sus claves."
  }
} else {
  $chars = @()
  $chars += 48..57 | ForEach-Object { [char]$_ }
  $chars += 65..90 | ForEach-Object { [char]$_ }
  $chars += 97..122 | ForEach-Object { [char]$_ }
  $plainPassword = -join ($chars | Get-Random -Count 28)
  $securePassword = ConvertTo-SecureString -String $plainPassword -AsPlainText -Force
  New-LocalUser -Name $UserName -Password $securePassword -PasswordNeverExpires `
                -AccountNeverExpires -Description 'Laboratorio SSH local (autenticacion por clave)' | Out-Null
  Write-Host "Creado usuario local '$UserName' (contraseña aleatoria, no se usa)." -ForegroundColor Green
}

# Claves autorizadas en una ruta predecible dentro de ProgramData.
if (-not (Test-Path -LiteralPath $KeysDir)) { New-Item -ItemType Directory -Path $KeysDir | Out-Null }
$authorizedFile = Join-Path $KeysDir "$UserName"
Copy-Item -LiteralPath $PublicKeyPath -Destination $authorizedFile -Force
(Get-Content -LiteralPath $authorizedFile -Raw).Trim() | Set-Content -LiteralPath $authorizedFile -Encoding ASCII

$principal = "$($env:COMPUTERNAME)\$UserName"
& icacls $KeysDir /inheritance:r | Out-Null
& icacls $KeysDir /grant:r "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F" "$principal:(OI)(CI)RX" | Out-Null
& icacls $authorizedFile /inheritance:r | Out-Null
& icacls $authorizedFile /grant:r "SYSTEM:F" "Administrators:F" "$principal:R" | Out-Null

# Configuración de sshd: conservar el original para poder deshacer.
if (-not (Test-Path -LiteralPath $CfgPath)) {
  $template = Join-Path $SshDir 'sshd_config_default'
  if (Test-Path -LiteralPath $template) { Copy-Item -LiteralPath $template -Destination $CfgPath -Force }
  else { New-Item -ItemType File -Path $CfgPath -Force | Out-Null }
}
if (-not (Test-Path -LiteralPath $BakPath)) { Copy-Item -LiteralPath $CfgPath -Destination $BakPath -Force }

$managed = @('PubkeyAuthentication','PasswordAuthentication','KbdInteractiveAuthentication',
             'PermitEmptyPasswords','AllowUsers','AuthorizedKeysFile','PermitRootLogin')
$lines = Get-Content -LiteralPath $CfgPath | Where-Object {
  $t = $_.Trim()
  if (-not $t -or $t.StartsWith('#')) { return $true }
  foreach ($m in $managed) { if ($t -match "^$m\s+") { return $false } }
  return $true
}

$block = @(
  '',
  '# --- Laboratorio local: gestionado por setup-ssh-server.ps1 ---',
  'PubkeyAuthentication yes',
  'PasswordAuthentication no',
  'KbdInteractiveAuthentication no',
  'PermitEmptyPasswords no',
  "AllowUsers $UserName",
  'AuthorizedKeysFile __PROGRAMDATA__/ssh/authorized_keys_lab/%u',
  '# --- Fin laboratorio ---'
)

$matchLine = $lines | Select-String -Pattern '^\s*Match\s' | Select-Object -First 1
if ($null -ne $matchLine) {
  $idx = [int]$matchLine.LineNumber - 1
  $before = @()
  if ($idx -gt 0) { $before = $lines[0..($idx - 1)] }
  $after = @()
  if ($idx -lt $lines.Count) { $after = $lines[$idx..($lines.Count - 1)] }
  $lines = @($before) + @($block) + @($after)
} else {
  $lines = @($lines) + @($block)
}
Set-Content -LiteralPath $CfgPath -Value $lines -Encoding ASCII

# Firewall: solo la subred privada detectada.
Remove-NetFirewallRule -Name $FirewallRuleName -ErrorAction SilentlyContinue
New-NetFirewallRule -Name $FirewallRuleName `
  -DisplayName 'OpenSSH Server (laboratorio local, solo LAN)' `
  -Direction Inbound -Action Allow -Protocol TCP -LocalPort 22 `
  -RemoteAddress $net.Cidr -Profile Private | Out-Null

$startup = if ($Autostart) { 'Automatic' } else { 'Manual' }
Set-Service -Name sshd -StartupType $startup
if ((Get-Service -Name sshd).Status -ne 'Running') { Start-Service -Name sshd }

Write-Host @"

Laboratorio configurado correctamente.
  Servidor:        $($net.Address)
  Subred permitida:$($net.Cidr)
  Usuario:         $UserName
  Autenticación:   solo clave pública (contraseñas desactivadas)
  Servicio sshd:   $((Get-Service -Name sshd).Status) / inicio $startup
  Claves:          $authorizedFile

Desde Linux:
  ./client/connect.sh -H $($net.Address) -u $UserName -k ./keys/lab_ed25519

Desde Windows:
  .\client\connect.ps1 -Host $($net.Address) -User $UserName -Key .\keys\lab_ed25519

Para deshacer: .\setup-ssh-server.ps1 -Uninstall
"@ -ForegroundColor Green
