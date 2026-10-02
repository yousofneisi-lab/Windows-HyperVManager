# Windows-HyperVManager

Ein interaktives PowerShell-Skript zur vereinfachten Verwaltung und Automatisierung von Microsoft Hyper-V-Umgebungen und virtuellen Maschinen.

## Funktionen
- **Host-Einrichtung:** Schnelle Konfiguration von Standardpfaden, NUMA-Spanning und System-Einstellungen.
- **VM-Verwaltung:** Erstellung neuer virtueller Maschinen inklusive automatischer VHDX-Dateierzeugung und ISO-Zuordnung.
- **Hardware-Anpassung:** Dynamische Steuerung von RAM-, CPU- und SCSI-Ressourcen.
- **Netzwerk & Direktzugriff:** Verwaltung virtueller Switches und Nutzung von PowerShell Direct.
- **Verschachtelte Virtualisierung:** Aktivierung von Nested Hyper-V für Test- und Schulungsumgebungen.
- **Interaktive Menüführung:** Benutzerfreundliche Farbkonsole mit automatischer Bildschirmbereinigung.

## Voraussetzungen
- Windows Server 2016/2019/2022 oder Windows 10/11 (Pro/Enterprise/Education)
- PowerShell 5.1 oder höher
- Administrative Rechte (Als Administrator ausführen)

## Nutzung

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
.\Windows-HyperVManager.ps1
