# Runs Findmeajob on Windows without Docker: a portable PostgreSQL and a portable
# Node.js, both kept in this folder. Used by the .cmd files next to it.
#   findmeajob.ps1 start     start the database and the app, then open the browser
#   findmeajob.ps1 stop      stop both
#   findmeajob.ps1 password  set or change the sign-in password
#   findmeajob.ps1 status    show whether it's running
param([ValidateSet("start", "stop", "password", "status")][string]$Command = "start")

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$App = Join-Path $Root "app"
$Server = Join-Path $App ".next\standalone"
$PgBin = Join-Path $Root "runtime\pgsql\bin"
$PgData = Join-Path $Root "data\pg"
$Logs = Join-Path $Root "logs"
$PidFile = Join-Path $Root "data\app.pid"
$EnvFile = Join-Path $App ".env"
$Port = 3210 # keep in step with PORT in app\.env
$Url = "http://localhost:$Port"
# Checks go to IPv4 directly, so another program on localhost's IPv6 address can't answer for Findmeajob.
$HealthUrl = "http://127.0.0.1:$Port/api/health"

$env:PATH = "$Root\runtime\node;$PgBin;$env:PATH"
$env:PLAYWRIGHT_BROWSERS_PATH = Join-Path $Root "runtime\ms-playwright"
$env:COREPACK_ENABLE_DOWNLOAD_PROMPT = "0"
$env:NEXT_TELEMETRY_DISABLED = "1"
New-Item -ItemType Directory -Force $Logs | Out-Null

function Say($text) { Write-Host $text -ForegroundColor Cyan }

function Read-EnvFile {
  $values = @{}
  foreach ($line in [IO.File]::ReadAllLines($EnvFile)) {
    if ($line -match '^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*)$') {
      $values[$Matches[1]] = $Matches[2].Trim().Trim('"')
    }
  }
  return $values
}

# pg_ctl is started without inheriting this window's output handles: the
# database it launches would otherwise keep them open and the script would hang.
function Invoke-Hidden([string]$file, [string]$arguments, [string]$workDir = $Root, [string]$log = "") {
  $options = @{ FilePath = $file; ArgumentList = $arguments; WorkingDirectory = $workDir; PassThru = $true }
  if ($log) {
    $options.NoNewWindow = $true
    $options.RedirectStandardOutput = "$log"
    $options.RedirectStandardError = "$log.err"
  } else {
    $options.WindowStyle = "Hidden"
  }
  $proc = Start-Process @options
  $null = $proc.Handle # without this, Windows PowerShell may lose the exit code
  $proc.WaitForExit()
  return $proc.ExitCode
}

function Invoke-PgCtl([string]$arguments) { return Invoke-Hidden "$PgBin\pg_ctl.exe" $arguments }

function Test-Database { return (Invoke-PgCtl "-D `"$PgData`" status") -eq 0 }

function Start-Database {
  if (Test-Database) { return }
  Say "Starting the database..."
  $log = Join-Path $Logs "postgres.log"
  if ((Invoke-PgCtl "-D `"$PgData`" -l `"$log`" -w start") -ne 0) { throw "The database didn't start. See logs\postgres.log." }
}

function Get-AppProcess {
  if (-not (Test-Path $PidFile)) { return $null }
  $id = [int](Get-Content $PidFile)
  $proc = Get-Process -Id $id -ErrorAction SilentlyContinue
  if ($proc -and $proc.ProcessName -eq "node") { return $proc }
  return $null
}

function Test-Health {
  try { return (Invoke-WebRequest $HealthUrl -UseBasicParsing -TimeoutSec 3).StatusCode -eq 200 } catch { return $false }
}

function Set-Password {
  Say "Choose the password you'll sign in to Findmeajob with (typing is hidden)."
  $first = Read-Host "Password" -AsSecureString
  $second = Read-Host "Same again" -AsSecureString
  $plain = { param($s) [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)) }
  $password = & $plain $first
  if (-not $password) { throw "No password entered." }
  if ($password -cne (& $plain $second)) { throw "The passwords don't match." }
  $env:DOSSIER_NEW_PASSWORD = $password
  Push-Location $App
  try { $hash = (& node node_modules/tsx/dist/cli.mjs (Join-Path $Root "tools\hash-password.mts")) }
  finally { Pop-Location; Remove-Item env:DOSSIER_NEW_PASSWORD }
  if ($LASTEXITCODE -ne 0 -or -not $hash) { throw "The password wasn't set." }
  $lines = [IO.File]::ReadAllLines($EnvFile) | ForEach-Object {
    if ($_ -match '^\s*DOSSIER_PASSWORD\s*=') { "DOSSIER_PASSWORD=$($hash.Trim())" } else { $_ }
  }
  [IO.File]::WriteAllLines($EnvFile, $lines)
  Say "Password saved. Only a hash of it is stored."
}

# The build links some libraries by full path (Windows junctions). If this
# folder was moved or renamed, point them at the copies in this folder again.
function Repair-Links {
  $linkDir = Join-Path $Server ".next\node_modules"
  if (-not (Test-Path $linkDir)) { return }
  foreach ($link in Get-ChildItem $linkDir -Recurse -Depth 1 -Force | Where-Object { $_.LinkType -eq "Junction" }) {
    $target = [string]($link.Target | Select-Object -First 1)
    if ($target -and (Test-Path $target)) { continue }
    $index = $target.IndexOf("\.next\standalone\node_modules\")
    if ($index -lt 0) { continue }
    $fixed = Join-Path $Server $target.Substring($index + "\.next\standalone\".Length)
    if (-not (Test-Path $fixed)) { continue }
    [IO.Directory]::Delete($link.FullName) # removes only the link, never what it points to
    New-Item -ItemType Junction -Path $link.FullName -Target $fixed | Out-Null
    Say "Repaired a library link ($($link.Name))."
  }
}

function Start-Findmeajob {
  Repair-Links
  if (-not (Read-EnvFile)["DOSSIER_PASSWORD"]) { Set-Password }
  Start-Database
  if (Get-AppProcess) {
    Say "Findmeajob is already running."
  } else {
    foreach ($pair in (Read-EnvFile).GetEnumerator()) { Set-Item "env:$($pair.Key)" $pair.Value }
    Say "Updating the database tables..."
    $node = Join-Path $Root "runtime\node\node.exe"
    if ((Invoke-Hidden $node "node_modules/prisma/build/index.js migrate deploy" $App (Join-Path $Logs "migrate.log")) -ne 0) {
      throw "Updating the database failed. See logs\migrate.log.err."
    }
    if ((Invoke-Hidden $node "node_modules/tsx/dist/cli.mjs prisma/seed.ts" $App (Join-Path $Logs "seed.log")) -ne 0) {
      throw "Loading the built-in themes failed. See logs\seed.log.err."
    }

    $taken = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($taken) {
      $other = (Get-Process -Id $taken.OwningProcess -ErrorAction SilentlyContinue).ProcessName
      throw "Port $Port is already used by another program ($other). Close it, or change PORT in app\.env and `$Port in dossier.ps1."
    }
    Say "Starting Findmeajob..."
    $env:NODE_ENV = "production"
    $proc = Start-Process -FilePath (Join-Path $Root "runtime\node\node.exe") -ArgumentList "server.js" `
      -WorkingDirectory $Server -WindowStyle Hidden -PassThru `
      -RedirectStandardOutput (Join-Path $Logs "dossier.log") -RedirectStandardError (Join-Path $Logs "dossier-error.log")
    Set-Content $PidFile $proc.Id
  }
  for ($i = 0; $i -lt 60 -and -not (Test-Health); $i++) {
    if (-not (Get-AppProcess)) { throw "Findmeajob stopped while starting. See logs\dossier-error.log." }
    Start-Sleep -Seconds 1
  }
  if (-not (Test-Health)) { throw "Findmeajob didn't answer within a minute. See logs\dossier-error.log." }
  Say "Findmeajob is running at $Url"
  Start-Process $Url
}

function Stop-Findmeajob {
  $proc = Get-AppProcess
  if ($proc) { Say "Stopping Findmeajob..."; Stop-Process -Id $proc.Id -Force }
  if (Test-Path $PidFile) { [IO.File]::Delete($PidFile) }
  if (Test-Database) { Say "Stopping the database..."; Invoke-PgCtl "-D `"$PgData`" -m fast -w stop" | Out-Null }
  Say "Findmeajob is stopped."
}

try {
  switch ($Command) {
    "start" { Start-Findmeajob }
    "stop" { Stop-Findmeajob }
    "password" {
      Set-Password
      if (Get-AppProcess) { Say "Restarting Findmeajob so the new password takes effect..."; Stop-Findmeajob; Start-Findmeajob }
    }
    "status" {
      Say ("Database: " + $(if (Test-Database) { "running" } else { "stopped" }))
      Say ("Findmeajob: " + $(if (Test-Health) { "running at $Url" } else { "stopped" }))
    }
  }
} catch {
  Write-Host $_.Exception.Message -ForegroundColor Red
  exit 1
}
