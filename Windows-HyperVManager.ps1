# ==========================================================
#  Windows-HyperVManager
#  Autor: Yousof
#  Website: Neisitech.de
# ==========================================================

# Pre-Check: Prüfen auf Administratorrechte
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[FEHLER] Dieses Skript erfordert administrative Rechte. Bitte starte die PowerShell als Administrator!" -ForegroundColor Red
    Pause
    exit
}

# ----------------------------------------------------------
# HILFSFUNKTIONEN UND VISUALISIERUNG
# ----------------------------------------------------------

function Show-Header {
    Clear-Host
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "                WINDOWS-HYPERV MANAGER                   " -ForegroundColor Yellow
    Write-Host "               Autor: Yousof | Neisitech.de               " -ForegroundColor DarkGray
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "Zentrales Verwaltungswerkzeug fuer Hyper-V Hosts & VMs    " -ForegroundColor Green
    Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
}

function Pause-Console {
    Write-Host ""
    Write-Host "Druecke eine beliebige Taste, um zum Menue zurueckzukehren..." -ForegroundColor DarkGray
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ----------------------------------------------------------
# HYPER-V FUNKTIONEN
# ----------------------------------------------------------

function Install-HyperVHost {
    Show-Header
    Write-Host "--- Hyper-V Rolle & Basiskonfiguration installieren ---" -ForegroundColor Yellow
    
    $computerName = Read-Host "Zielserver angeben (Standard: Localhost)"
    if ([string]::IsNullOrWhitespace($computerName)) { $computerName = "localhost" }

    try {
        Write-Host "`nInstalliere Hyper-V Rolle..." -ForegroundColor Cyan
        
        $isServer = (Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -ne 1

        if ($computerName -eq "localhost") {
            if ($isServer) {
                Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -ErrorAction Stop
            } else {
                Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart -ErrorAction Stop
            }
        } else {
            Invoke-Command -ComputerName $computerName -ScriptBlock {$isRemoteServer = (Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -ne 1
                if ($isRemoteServer) {
                    Install-WindowsFeature -Name Hyper-V -IncludeManagementTools
                } else {
                    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
                }
            } -ErrorAction Stop
        }
        
        Write-Host "[ERFOLG] Hyper-V Rolle wurde erfolgreich installiert!" -ForegroundColor Green
        
        $reboot = Read-Host "Moechtest du das System jetzt neustarten? (J/N)"
        if ($reboot -eq "J" -or $reboot -eq "j") {
            if ($computerName -eq "localhost") {
                Restart-Computer -Force
            } else {
                Restart-Computer -ComputerName $computerName -Force
            }
        }
    } catch {
        Write-Host "[FEHLER] Installation fehlgeschlagen: $_" -ForegroundColor Red
    }
    Pause-Console
}

function Configure-HostDefaults {
    Show-Header
    Write-Host "--- Hyper-V Host Standardpfade & Optionen konfigurieren ---" -ForegroundColor Yellow

    $vhdPath = Read-Host "Standardpfad fuer VHDs (z.B. C:\VMs\Vhds)"
    $vmPath  = Read-Host "Standardpfad fuer VMs (z.B. C:\VMs\Configurations)"

    if ([string]::IsNullOrWhitespace($vhdPath) -or [string]::IsNullOrWhitespace($vmPath)) {
        Write-Host "[FEHLER] Pfade duerfen nicht leer sein!" -ForegroundColor Red
        Pause-Console
        return
    }

    if (-not (Test-Path $vhdPath)) { New-Item -Path$vhdPath -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path $vmPath))  { New-Item -Path$vmPath  -ItemType Directory -Force | Out-Null }

    try {
        Set-VMHost -VirtualHardDiskPath $vhdPath -VirtualMachinePath$vmPath
        Set-VMHost -NumaSpanningEnabled $true
        Set-VMHost -EnableEnhancedSessionMode $true
        Set-VMHost -ResourceMeteringSaveInterval (New-TimeSpan -Hours 0 -Minutes 15)
        
        Write-Host "`n[ERFOLG] Host-Pfade und erweiterte Optionen erfolgreich gesetzt!" -ForegroundColor Green
        Get-VMHost | Format-List Name, VirtualHardDiskPath, VirtualMachinePath, NumaSpanningEnabled, EnableEnhancedSessionMode
    } catch {
        Write-Host "[FEHLER] Konfiguration fehlgeschlagen: $_" -ForegroundColor Red
    }
    Pause-Console
}

function New-HyperVVM {
    Show-Header
    Write-Host "--- Neue Virtuelle Maschine erstellen ---" -ForegroundColor Yellow

    $vmName = Read-Host "VM-Name eingeben"
    if ([string]::IsNullOrWhitespace($vmName)) { Write-Host "[FEHLER] Name ungueltig!" -ForegroundColor Red; Pause-Console; return }

    $ramMB   = Read-Host "Arbeitsspeicher in MB (Standard: 2048)"
    if ([string]::IsNullOrWhitespace($ramMB)) { $ramMB = 2048 }

    $vhdSizeGB = Read-Host "Festplattengroesse in GB (Standard: 40)"
    if ([string]::IsNullOrWhitespace($vhdSizeGB)) { $vhdSizeGB = 40 }

    $isoPath = Read-Host "Pfad zur ISO-Datei (Optional, Enter zum Ueberspringen)"

    try {
        $hostSettings = Get-VMHost
        $vmDir = Join-Path -Path $hostSettings.VirtualMachinePath -ChildPath $vmName
        $vhdDir = Join-Path -Path $hostSettings.VirtualHardDiskPath -ChildPath "$vmName.vhdx"

        Write-Host "`nErstelle VM '$vmName'..." -ForegroundColor Cyan
        New-VM -Name $vmName -Path $vmDir -MemoryStartupBytes ([long]$ramMB * 1MB) | Out-Null
        New-VHD -Path $vhdDir -SizeBytes ([long]$vhdSizeGB * 1GB) -Dynamic | Out-Null
        Add-VMHardDiskDrive -VMName $vmName -Path$vhdDir | Out-Null

        if (-not [string]::IsNullOrWhitespace($isoPath) -and (Test-Path$isoPath)) {
            Set-VMDvdDrive -VMName $vmName -ControllerNumber 1 -Path$isoPath | Out-Null
            Write-Host "ISO-Image '$isoPath' wurde zugewiesen." -ForegroundColor DarkGray
        }

        Write-Host "[ERFOLG] VM '$vmName' wurde erfolgreich erstellt!" -ForegroundColor Green
    } catch {
        Write-Host "[FEHLER] Erstellung fehlgeschlagen: $_" -ForegroundColor Red
    }
    Pause-Console
}

function Show-VMStatus {
    Show-Header
    Write-Host "--- VM Statusuebersicht ---" -ForegroundColor Yellow

    try {
        $vms = Get-VM
        if ($vms) {$vms | Format-Table Name, State, CPUUsage, MemoryAssigned, Uptime -AutoSize
        } else {
            Write-Host "Keine virtuellen Maschinen vorhanden." -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "[FEHLER] Fehler beim Abrufen der VMs: $_" -ForegroundColor Red
    }
    Pause-Console
}

function Manage-VMState {
    Show-Header
    Write-Host "--- VM Zustand verwalten ---" -ForegroundColor Yellow

    $vmName = Read-Host "Name der Ziel-VM"
    if (-not (Get-VM -Name $vmName -ErrorAction SilentlyContinue)) {
        Write-Host "[FEHLER] VM '$vmName' wurde nicht gefunden!" -ForegroundColor Red
        Pause-Console
        return
    }

    Write-Host "`nWaehle eine Aktion fuer '$vmName':" -ForegroundColor Cyan
    Write-Host "1) Starten"
    Write-Host "2) Stoppen (Geregelt)"
    Write-Host "3) Stoppen (Hard TurnOff)"
    Write-Host "4) Einfrieren (Suspend)"
    Write-Host "5) Fortsetzen (Resume)"
    Write-Host "6) Speichern (Save)"
    Write-Host "7) Neustarten"
    
    $action = Read-Host "`nAktion waehlen (1-7)"

    try {
        switch ($action) {
            "1" { Start-VM -Name $vmName; Write-Host "[OK] VM gestartet." -ForegroundColor Green }
            "2" { Stop-VM -Name $vmName; Write-Host "[OK] VM gestoppt." -ForegroundColor Green }
            "3" { Stop-VM -Name $vmName -TurnOff; Write-Host "[OK] VM hart ausgeschaltet." -ForegroundColor Green }
            "4" { Suspend-VM -Name $vmName; Write-Host "[OK] VM eingefroren." -ForegroundColor Green }
            "5" { Resume-VM -Name $vmName; Write-Host "[OK] VM fortgesetzt." -ForegroundColor Green }
            "6" { Save-VM -Name $vmName; Write-Host "[OK] VM-Zustand gespeichert." -ForegroundColor Green }
            "7" { Restart-VM -Name $vmName -Force; Write-Host "[OK] VM neugestartet." -ForegroundColor Green }
            default { Write-Host "Ungueltige Auswahl." -ForegroundColor Red }
        }
    } catch {
        Write-Host "[FEHLER] Aktion konnte nicht ausgefuehrt werden: $_" -ForegroundColor Red
    }
    Pause-Console
}

function Manage-VMSwitch {
    Show-Header
    Write-Host "--- Virtuelle Switches verwalten ---" -ForegroundColor Yellow

    Write-Host "Vorhandene Switches:" -ForegroundColor DarkGray
    Get-VMSwitch | Format-Table Name, SwitchType, NetAdapterInterfaceDescription -AutoSize

    Write-Host "`n1) Neuen Switch erstellen"
    Write-Host "2) Zurueck"
    $choice = Read-Host "Auswahl"

    if ($choice -eq "1") {
        $switchName = Read-Host "Name des neuen Switches"
        Write-Host "Typen: 1 = External, 2 = Internal, 3 = Private"
        $typeInput = Read-Host "Auswahl Typ (1-3)"

        try {
            switch ($typeInput) {
                "1" {
                    Get-NetAdapter | Format-Table Name, InterfaceDescription -AutoSize
                    $nicName = Read-Host "Name der physischen Netzwerkkarte"
                    New-VMSwitch -Name $switchName -NetAdapterName $nicName -AllowManagementOS $true
                }
                "2" { New-VMSwitch -Name $switchName -SwitchType Internal }
                "3" { New-VMSwitch -Name $switchName -SwitchType Private }
            }
            Write-Host "[ERFOLG] Switch '$switchName' erstellt!" -ForegroundColor Green
        } catch {
            Write-Host "[FEHLER] Switch konnte nicht erstellt werden: $_" -ForegroundColor Red
        }
    }
    Pause-Console
}

function Invoke-PSDirect {
    Show-Header
    Write-Host "--- PowerShell Direct ausfuehren ---" -ForegroundColor Yellow

    $vmName = Read-Host "Ziel-VM Name"
    $cred = Get-Credential -Message "Zugangsdaten fuer die Ziel-VM eingeben"
    $command = Read-Host "Auszufuehrender Befehl (z.B. hostname oder Get-Service)"

    try {
        Write-Host "`nFuehre Befehl auf VM '$vmName' aus..." -ForegroundColor Cyan
        Invoke-Command -VMName $vmName -Credential $cred -ScriptBlock ([ScriptBlock]::Create($command))
    } catch {
        Write-Host "[FEHLER] PowerShell Direct Ausfuehrung fehlgeschlagen: $_" -ForegroundColor Red
    }
    Pause-Console
}

function Enable-NestedVirt {
    Show-Header
    Write-Host "--- Verschachtelte Virtualisierung (Nested Hyper-V) ---" -ForegroundColor Yellow

    $vmName = Read-Host "Name der Ziel-VM"
    $vm = Get-VM -Name$vmName -ErrorAction SilentlyContinue

    if (-not $vm) {
        Write-Host "[FEHLER] VM '$vmName' existiert nicht." -ForegroundColor Red
        Pause-Console
        return
    }

    if ($vm.State -ne "Off") {
        Write-Host "[HINWEIS] Die VM muss ausgeschaltet sein, um Virtualisierungserweiterungen zu aktivieren." -ForegroundColor Yellow
        $stop = Read-Host "Moechtest du die VM jetzt ausschalten? (J/N)"
        if ($stop -eq "J" -or $stop -eq "j") {
            Stop-VM -Name $vmName -Force
        } else {
            Pause-Console
            return
        }
    }

    try {
        Set-VMProcessor -VMName $vmName -ExposeVirtualizationExtensions$true
        Write-Host "[ERFOLG] Virtualisierungserweiterungen wurden fuer VM '$vmName' aktiviert!" -ForegroundColor Green
    } catch {
        Write-Host "[FEHLER] Aktivierung fehlgeschlagen: $_" -ForegroundColor Red
    }
    Pause-Console
}

# ----------------------------------------------------------
# HAUPTMENÜ SCHLEIFE
# ----------------------------------------------------------

do {
    Show-Header
    Write-Host "1) Hyper-V Rolle auf Host installieren" -ForegroundColor White
    Write-Host "2) Host Standardpfade & Optionen konfigurieren" -ForegroundColor White
    Write-Host "3) Neue Virtuelle Maschine (VM) erstellen" -ForegroundColor White
    Write-Host "4) VM-Status anzeigen" -ForegroundColor White
    Write-Host "5) VM-Zustand steuern (Start/Stopp/Pause/...)" -ForegroundColor White
    Write-Host "6) Virtuelle Switches verwalten" -ForegroundColor White
    Write-Host "7) PowerShell Direct Ausfuehrung" -ForegroundColor White
    Write-Host "8) Nested Hyper-V aktivieren" -ForegroundColor White
    Write-Host "9) Beenden" -ForegroundColor Red
    Write-Host ""
    
    $selection = Read-Host "Bitte waehle eine Option (1-9)"

    switch ($selection) {
        "1" { Install-HyperVHost }
        "2" { Configure-HostDefaults }
        "3" { New-HyperVVM }
        "4" { Show-VMStatus }
        "5" { Manage-VMState }
        "6" { Manage-VMSwitch }
        "7" { Invoke-PSDirect }
        "8" { Enable-NestedVirt }
        "9" { Clear-Host; Write-Host "Hyper-V Manager beendet." -ForegroundColor Yellow; exit }
        default { Write-Host "Ungueltige Eingabe!" -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
} while ($true)
