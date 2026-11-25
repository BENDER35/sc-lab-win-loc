<#
 Cliente SSH para Windows (usa el ssh.exe incluido en Windows 10/11).
 Solo redes privadas (RFC1918) salvo que se pase -AllowPublic.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Host,
  [string]$User = 'labremote',
  [Parameter(Mandatory=$true)][string]$Key,
  [ValidateRange(1,65535)][int]$Port = 22,
  [string]$Command,
  [switch]$AllowPublic
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Key)) {
  throw "No encuentro la clave privada: $Key"
}
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
  throw "No encuentro ssh.exe. Instala 'OpenSSH Client' en Características opcionales de Windows."
}

$privateHost = $Host -match '^10\.' -or
               $Host -match '^192\.168\.' -or
               $Host -match '^172\.(1[6-9]|2[0-9]|3[01])\.'
if (-not $privateHost) {
  if (-not $AllowPublic) {
    Write-Error "AVISO: '$Host' no parece una IP privada (RFC1918). Este laboratorio es solo para la LAN. Usa -AllowPublic bajo tu responsabilidad."
    exit 3
  }
  Write-Warning "Conectando a una IP pública con -AllowPublic. ¡Necesitas autorización!"
}

$knownHosts = Join-Path $env:USERPROFILE '.ssh\known_hosts_lab'
$knownDir = Split-Path $knownHosts
if (-not (Test-Path -LiteralPath $knownDir)) { New-Item -ItemType Directory -Path $knownDir | Out-Null }

$sshArgs = @(
  '-i', $Key,
  '-o', 'IdentitiesOnly=yes',
  '-o', 'StrictHostKeyChecking=accept-new',
  '-o', "UserKnownHostsFile=$knownHosts",
  '-o', 'ForwardAgent=no',
  '-p', "$Port",
  "$User@$Host"
)
if ($PSBoundParameters.ContainsKey('Command') -and $Command) { $sshArgs += $Command }

Write-Host "Conectando a $User@$Host`:$Port ..." -ForegroundColor Cyan
& ssh @sshArgs
exit $LASTEXITCODE
