Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ===== Тёмный заголовок окна =====
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class DwmDark {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int val, int size);
    public static void Set(IntPtr h) {
        int v = 1;
        if (DwmSetWindowAttribute(h, 20, ref v, sizeof(int)) != 0)
            DwmSetWindowAttribute(h, 19, ref v, sizeof(int));
    }
}
"@

$base = Split-Path $PSScriptRoot -Parent          # папка, где лежит .vbs
$appDir = $PSScriptRoot                            # папка _app
$configFile = Join-Path $appDir "config.ini"
$logFile    = Join-Path $appDir "launcher.log"
$vbsPath    = Join-Path $base "BG3 Launcher.vbs"
$runKey     = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$runName    = "BG3Launcher"

# ===== Пути по умолчанию (используются, если config.ini нет) =====
$defaults = [ordered]@{
    Teams   = "C:\Program Files\WindowsApps\MSTeams_26288.2004.5269.3420_x64__8wekyb3d8bbwe\ms-teams.exe"
    Radmin  = "C:\Program Files (x86)\Radmin VPN\RvRvpnGui.exe"
    Trainer = "D:\Programs\BG3\Baldurs Gate 3 v4.1.1 Plus 21 Trainer Updated 2025.04.16.exe"
    Game    = ""   # пусто = автоопределение через Steam
}

# ===== Чтение config.ini =====
$cfg = @{}
if (Test-Path $configFile) {
    $section = ""
    foreach ($line in Get-Content $configFile -Encoding UTF8) {
        $t = $line.Trim()
        if ($t -match '^\[(.+)\]$') { $section = $Matches[1].ToLower() }
        elseif ($t -match '^([^=]+)=(.*)$') { $cfg["$section.$($Matches[1].Trim().ToLower())"] = $Matches[2].Trim() }
    }
}

function Get-Cfg([string]$key) {
    $v = $cfg["paths.$($key.ToLower())"]
    if ([string]::IsNullOrWhiteSpace($v)) { return $defaults[$key] }
    return $v
}

$teamsPath   = Get-Cfg "Teams"
$radminPath  = Get-Cfg "Radmin"
$trainerPath = Get-Cfg "Trainer"
$gamePath    = Get-Cfg "Game"

# ===== Автоопределение игры через Steam =====
if ([string]::IsNullOrWhiteSpace($gamePath) -or -not (Test-Path $gamePath)) {
    $steamPath = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name SteamPath -ErrorAction SilentlyContinue).SteamPath
    if ($steamPath) {
        $candidates = @($steamPath)
        $vdf = Join-Path $steamPath "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            foreach ($l in Get-Content $vdf) {
                if ($l -match '"path"\s+"([^"]+)"') { $candidates += ($Matches[1] -replace '\\\\', '\') }
            }
        }
        foreach ($lib in $candidates) {
            $p = Join-Path $lib "steamapps\common\Baldurs Gate 3\bin\bg3_dx11.exe"
            if (Test-Path $p) { $gamePath = $p; break }
        }
    }
}

# ===== Палитра =====
$cBg       = [System.Drawing.Color]::FromArgb(24, 24, 26)
$cSurface  = [System.Drawing.Color]::FromArgb(40, 40, 44)
$cSurface2 = [System.Drawing.Color]::FromArgb(56, 56, 60)
$cText     = [System.Drawing.Color]::FromArgb(230, 230, 230)
$cTextDim  = [System.Drawing.Color]::FromArgb(150, 150, 155)
$cAccent   = [System.Drawing.Color]::FromArgb(212, 168, 87)
$cAccentHi = [System.Drawing.Color]::FromArgb(232, 190, 110)
$cAccentDk = [System.Drawing.Color]::FromArgb(180, 140, 65)
$cDark     = [System.Drawing.Color]::FromArgb(24, 24, 26)

# ===== Скруглённый регион =====
function Set-Rounded($ctrl, $radius) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = $radius; $w = $ctrl.Width; $h = $ctrl.Height
    $path.AddArc(0, 0, $r*2, $r*2, 180, 90)
    $path.AddArc($w - $r*2, 0, $r*2, $r*2, 270, 90)
    $path.AddArc($w - $r*2, $h - $r*2, $r*2, $r*2, 0, 90)
    $path.AddArc(0, $h - $r*2, $r*2, $r*2, 90, 90)
    $path.CloseFigure()
    $ctrl.Region = New-Object System.Drawing.Region($path)
}

# ===== Форма =====
$form = New-Object System.Windows.Forms.Form
$form.Text = "BG3 Launcher"
$form.ClientSize = New-Object System.Drawing.Size(420, 600)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = $cBg
$form.ForeColor = $cText
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Add_Shown({ [DwmDark]::Set($form.Handle); $form.Activate() })

# ===== Заголовки =====
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "BG3 LAUNCHER"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 16, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = $cAccent
$lblTitle.Location = New-Object System.Drawing.Point(20, 18)
$lblTitle.Size = New-Object System.Drawing.Size(380, 30)
$form.Controls.Add($lblTitle)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = "Отметьте, что запустить:"
$lblSub.ForeColor = $cTextDim
$lblSub.Location = New-Object System.Drawing.Point(20, 52)
$lblSub.Size = New-Object System.Drawing.Size(380, 20)
$form.Controls.Add($lblSub)

# ===== Тоггл-чекбоксы =====
function New-Toggle($text, $y) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $text
    $cb.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $cb.Padding = New-Object System.Windows.Forms.Padding(16, 0, 0, 0)
    $cb.Location = New-Object System.Drawing.Point(20, $y)
    $cb.Size = New-Object System.Drawing.Size(380, 46)
    $cb.Appearance = [System.Windows.Forms.Appearance]::Button
    $cb.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $cb.FlatAppearance.BorderSize = 0
    $cb.FlatAppearance.CheckedBackColor = $cAccent
    $cb.FlatAppearance.MouseOverBackColor = $cSurface2
    $cb.FlatAppearance.MouseDownBackColor = $cAccentDk
    $cb.BackColor = $cSurface
    $cb.ForeColor = $cText
    $cb.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $cb.Cursor = [System.Windows.Forms.Cursors]::Hand
    $cb.Add_CheckedChanged({
        if ($this.Checked) { $this.ForeColor = [System.Drawing.Color]::FromArgb(24, 24, 26) }
        else               { $this.ForeColor = [System.Drawing.Color]::FromArgb(230, 230, 230) }
    })
    Set-Rounded $cb 6
    $form.Controls.Add($cb)
    return $cb
}

$cbTeams   = New-Toggle "Microsoft Teams" 84
$cbRadmin  = New-Toggle "Radmin VPN" 138
$cbTrainer = New-Toggle "BG3 Trainer" 192
$cbGame    = New-Toggle "Baldur's Gate 3" 246

# ===== Кнопки =====
function New-FlatBtn($text, $x, $y, $w, $h, $isAccent=$false) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Location = New-Object System.Drawing.Point($x, $y)
    $b.Size = New-Object System.Drawing.Size($w, $h)
    $b.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $b.FlatAppearance.BorderSize = 0
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $b.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    if ($isAccent) {
        $b.BackColor = $cAccent; $b.ForeColor = $cDark
        $b.FlatAppearance.MouseOverBackColor = $cAccentHi
        $b.FlatAppearance.MouseDownBackColor = $cAccentDk
    } else {
        $b.BackColor = $cSurface; $b.ForeColor = $cText
        $b.FlatAppearance.MouseOverBackColor = $cSurface2
        $b.FlatAppearance.MouseDownBackColor = $cSurface2
    }
    Set-Rounded $b 6
    return $b
}

# --- Пресеты ---
$btnSolo = New-FlatBtn "Соло"       20  302 120 30
$btnCoop = New-FlatBtn "Кооп"      150  302 120 30
$btnMass = New-FlatBtn "Всё сразу" 280  302 120 30
$form.Controls.Add($btnSolo); $form.Controls.Add($btnCoop); $form.Controls.Add($btnMass)

$btnAll  = New-FlatBtn "Выбрать все" 20  342 185 32
$btnNone = New-FlatBtn "Снять все"  215  342 185 32
$form.Controls.Add($btnAll); $form.Controls.Add($btnNone)

$btnLaunch = New-FlatBtn "ЗАПУСТИТЬ" 20 384 380 50 $true
$btnLaunch.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnLaunch)

# --- Автозапуск с Windows ---
$cbAuto = New-Object System.Windows.Forms.CheckBox
$cbAuto.Text = "Запускать лаунчер вместе с Windows"
$cbAuto.Location = New-Object System.Drawing.Point(20, 442)
$cbAuto.Size = New-Object System.Drawing.Size(380, 22)
$cbAuto.ForeColor = $cTextDim
$cbAuto.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($cbAuto)

# ===== Лог =====
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(20, 470)
$logBox.Size = New-Object System.Drawing.Size(380, 110)
$logBox.Multiline = $true
$logBox.ReadOnly = $true
$logBox.ScrollBars = "Vertical"
$logBox.BackColor = $cSurface
$logBox.ForeColor = $cTextDim
$logBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($logBox)

# ===== Логика =====
function Write-Log($msg) {
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logBox.AppendText("$msg`r`n")
    $logBox.SelectionStart = $logBox.Text.Length
    $logBox.ScrollToCaret()
    try { Add-Content -Path $logFile -Value "[$stamp] $msg" -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-All([bool]$teams, [bool]$radmin, [bool]$trainer, [bool]$game) {
    $cbTeams.Checked = $teams; $cbRadmin.Checked = $radmin
    $cbTrainer.Checked = $trainer; $cbGame.Checked = $game
}

$btnSolo.Add_Click({ Set-All $false $false $true $true })
$btnCoop.Add_Click({ Set-All $false $true $false $true })
$btnMass.Add_Click({ Set-All $true $true $true $true })
$btnAll.Add_Click({ Set-All $true $true $true $true })
$btnNone.Add_Click({ Set-All $false $false $false $false })

# --- Автозапуск: состояние при старте ---
$cbAuto.Checked = (Get-ItemProperty -Path $runKey -Name $runName -ErrorAction SilentlyContinue) -ne $null
$cbAuto.Add_CheckedChanged({
    if ($cbAuto.Checked) {
        Set-ItemProperty -Path $runKey -Name $runName -Value ("wscript.exe `"$vbsPath`"")
        Write-Log "[OK] Автозапуск включён"
    } else {
        Remove-ItemProperty -Path $runKey -Name $runName -ErrorAction SilentlyContinue
        Write-Log "[OK] Автозапуск выключен"
    }
})

$btnLaunch.Add_Click({
    $btnLaunch.Enabled = $false
    $logBox.Clear()
    Write-Log "=== Запуск $(Get-Date -Format 'HH:mm:ss') ==="

    if ($cbTeams.Checked) {
        try { Start-Process -FilePath $teamsPath; Write-Log "[OK] Teams запущен" }
        catch { Write-Log "[ERR] Teams: $($_.Exception.Message)" }
    }
    if ($cbRadmin.Checked) {
        try { Start-Process -FilePath $radminPath; Write-Log "[OK] Radmin VPN запущен" }
        catch { Write-Log "[ERR] Radmin: $($_.Exception.Message)" }
    }
    if ($cbTrainer.Checked) {
        try { Start-Process -FilePath $trainerPath; Write-Log "[OK] Трейнер запущен" }
        catch { Write-Log "[ERR] Трейнер: $($_.Exception.Message)" }
    }
    if ($cbTrainer.Checked -and $cbGame.Checked) {
        for ($i = 12; $i -gt 0; $i--) {
            Write-Log "Ожидание $i сек. перед запуском игры..."
            Start-Sleep -Seconds 1
        }
    }
    if ($cbGame.Checked) {
        if ($gamePath -and (Test-Path $gamePath)) {
            try { Start-Process -FilePath $gamePath -WorkingDirectory (Split-Path $gamePath); Write-Log "[OK] Baldur's Gate 3 запущена" }
            catch { Write-Log "[ERR] Игра: $($_.Exception.Message)" }
        } else {
            Write-Log "[ERR] Игра не найдена. Укажи путь в config.ini"
        }
    }
    if (-not ($cbTeams.Checked -or $cbRadmin.Checked -or $cbTrainer.Checked -or $cbGame.Checked)) {
        Write-Log "Ничего не выбрано."
    }
    $btnLaunch.Enabled = $true
})

[void]$form.ShowDialog()
