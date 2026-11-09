$ErrorActionPreference = "SilentlyContinue"
$appDir = $PSScriptRoot
$configFile = Join-Path $appDir "config.ini"
Write-Host ""

# ---------- 1. TEAMS ----------
Write-Host "[1/4] Ищу Microsoft Teams..." -ForegroundColor Cyan
$teams = ""
# Новый Teams (из Microsoft Store)
$pkg = Get-AppxPackage -Name "MSTeams" | Select-Object -First 1
if ($pkg) {
    $p = Join-Path $pkg.InstallLocation "ms-teams.exe"
    if (Test-Path $p) { $teams = $p }
}
# Классический Teams
if (-not $teams) {
    $p = "$env:ProgramFiles(x86)\Microsoft\Teams\current\Teams.exe" -replace '\(x86\)', ' (x86)'
    if (Test-Path $p) { $teams = $p }
}
if ($teams) { Write-Host "      Найден: $teams" -ForegroundColor Green }
else        { Write-Host "      НЕ найден автоматически." -ForegroundColor Yellow }

# ---------- 2. RADMIN ----------
Write-Host "[2/4] Ищу Radmin VPN..." -ForegroundColor Cyan
$radmin = ""
$candidates = @(
    "${env:ProgramFiles(x86)}\Radmin VPN\RvRvpnGui.exe",
    "$env:ProgramFiles\Radmin VPN\RvRvpnGui.exe"
)
foreach ($c in $candidates) { if (Test-Path $c) { $radmin = $c; break } }
if ($radmin) { Write-Host "      Найден: $radmin" -ForegroundColor Green }
else         { Write-Host "      НЕ найден автоматически." -ForegroundColor Yellow }

# ---------- 3. ИГРА (Steam) ----------
Write-Host "[3/4] Ищу Baldur's Gate 3..." -ForegroundColor Cyan
$game = ""
$steamPath = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name SteamPath -ErrorAction SilentlyContinue).SteamPath
if ($steamPath) {
    $libs = @($steamPath)
    $vdf = Join-Path $steamPath "steamapps\libraryfolders.vdf"
    if (Test-Path $vdf) {
        foreach ($l in Get-Content $vdf) {
            if ($l -match '"path"\s+"([^"]+)"') { $libs += ($Matches[1] -replace '\\\\', '\') }
        }
    }
    foreach ($lib in $libs) {
        $p = Join-Path $lib "steamapps\common\Baldurs Gate 3\bin\bg3_dx11.exe"
        if (Test-Path $p) { $game = $p; break }
    }
}
if ($game) { Write-Host "      Найдена: $game" -ForegroundColor Green }
else       { Write-Host "      НЕ найдена через Steam." -ForegroundColor Yellow }

# ---------- 4. ТРЕНЕР ----------
Write-Host "[4/4] Ищу трейнер..." -ForegroundColor Cyan
$trainer = ""
# ищем в типичных местах файл с "Trainer" и "BG3"/"Baldurs" в имени
$searchDirs = @(
    "D:\Programs\BG3",
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\Downloads",
    "C:\Games"
)
foreach ($dir in $searchDirs) {
    if (Test-Path $dir) {
        $found = Get-ChildItem -Path $dir -Filter "*.exe" -Recurse -Depth 2 |
                 Where-Object { $_.Name -match 'trainer' -and $_.Name -match 'bg3|baldur' } |
                 Select-Object -First 1
        if ($found) { $trainer = $found.FullName; break }
    }
}
if ($trainer) { Write-Host "      Найден: $trainer" -ForegroundColor Green }
else          { Write-Host "      НЕ найден автоматически." -ForegroundColor Yellow }

# ---------- Ручной выбор того, что не нашлось ----------
Add-Type -AssemblyName System.Windows.Forms
function Pick-File($title) {
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = $title
    $dlg.Filter = "Программа (*.exe)|*.exe"
    if ($dlg.ShowDialog() -eq "OK") { return $dlg.FileName }
    return ""
}

if (-not $teams)   { $teams   = Pick-File "Найди и выбери ms-teams.exe (или нажми Отмена, чтобы пропустить)" }
if (-not $radmin)  { $radmin  = Pick-File "Найди и выбери RvRvpnGui.exe (или нажми Отмена, чтобы пропустить)" }
if (-not $game)    { $game    = Pick-File "Найди и выбери bg3_dx11.exe (или нажми Отмена, чтобы пропустить)" }
if (-not $trainer) { $trainer = Pick-File "Найди и выбери файл трейнера (или нажми Отмена, чтобы пропустить)" }

# ---------- Записываем config.ini ----------
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("[Paths]")
[void]$sb.AppendLine("Teams=$teams")
[void]$sb.AppendLine("Radmin=$radmin")
[void]$sb.AppendLine("Trainer=$trainer")
[void]$sb.AppendLine("Game=$game")
[System.IO.File]::WriteAllText($configFile, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))

# ---------- ИТОГОВАЯ ПРОВЕРКА ----------
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$results = @(
    @{ Name = "Microsoft Teams";   Path = $teams },
    @{ Name = "Radmin VPN";        Path = $radmin },
    @{ Name = "Трейнер BG3";       Path = $trainer },
    @{ Name = "Baldur's Gate 3";   Path = $game }
)

$reportLines = @()
$msgLines    = @()
$okCount = 0

foreach ($r in $results) {
    if     ($r.Path -and (Test-Path $r.Path)) { $mark = "[OK]  нашлась"; $color = "Green";  $okCount++ }
    elseif ($r.Path)                          { $mark = "[?]   путь записан, но файла нет"; $color = "Yellow" }
    else                                      { $mark = "[X]   НЕ НАЙДЕНА"; $color = "Red" }

    Write-Host ("{0,-30} {1}" -f $r.Name, $mark) -ForegroundColor $color
    if ($r.Path) { Write-Host ("{0}-30 {1}" -f "", $r.Path) -ForegroundColor Gray }

    $msgLines    += ("{0,-18} {1}" -f $r.Name, $mark.Trim())
    if ($r.Path) { $msgLines += ("     $($r.Path)") }
    $reportLines += "$($r.Name) : $mark : $($r.Path)"
}

$reportLines | Set-Content -Path (Join-Path $appDir "setup_report.txt") -Encoding UTF8

# ---------- Всплывающее окно с итогом ----------
$icon = if ($okCount -eq 4) { [System.Windows.Forms.MessageBoxIcon]::Information }
        else                { [System.Windows.Forms.MessageBoxIcon]::Warning }

$title = if ($okCount -eq 4) { "Всё готово!" } else { "Готово, но есть замечания" }

[void][System.Windows.Forms.MessageBox]::Show(
    "Найдено программ: $okCount из 4`n`n" + ($msgLines -join "`n") + `
    "`n`nОтчёт сохранён в _app\setup_report.txt",
    $title, "OK", $icon
)

Write-Host ""
Write-Host "Настройка завершена. Можно закрывать это окно." -ForegroundColor Cyan
