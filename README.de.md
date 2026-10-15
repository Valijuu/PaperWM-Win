# PaperWM für Windows

[English](README.md) | **Deutsch**

Scrollendes Tiling nach dem Vorbild von [PaperWM](https://github.com/paperwm/PaperWM) für GNOME, als AutoHotkey-v2-Skript. Fenster liegen als Spalten auf einem endlosen, waagerechten Streifen, der Bildschirm zeigt einen Ausschnitt davon. Jeder Monitor zeigt einen eigenen Workspace. Die Tastenkürzel entsprechen den PaperWM-Standards.

Im Folgenden steht **Windows** für die Windows-Taste. Die Tasten `^`, `Ö` und `Ä` beziehen sich auf das deutsche QWERTZ-Layout.

## Installation und Start

1. [AutoHotkey v2](https://www.autohotkey.com/) installieren, z. B. mit `winget install AutoHotkey.AutoHotkey`.
2. Dieses Repo klonen oder als ZIP herunterladen.
3. `PaperWM.ahk` doppelklicken. Läuft es schon, wird es neu gestartet.

Ob PaperWM läuft, erkennst du am grünen „H“ von AutoHotkey im Infobereich der Taskleiste (unten rechts, ggf. hinter dem Pfeil).

**Autostart einrichten:**

Über die Aufgabenplanung startet PaperWM sofort bei der Anmeldung. Eine Verknüpfung im Autostart-Ordner (`shell:startup`) funktioniert auch, Windows startet solche Einträge nach dem Hochfahren aber absichtlich erst spät. Die Aufgabe läuft außerdem mit Admin-Rechten, so dass PaperWM auch Admin-Fenster wie den Task-Manager kacheln kann.

PowerShell **als Administrator** öffnen, in den Ordner von PaperWM wechseln und ausführen:

```powershell
$ahk = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"   # ggf. Pfad anpassen
$a = New-ScheduledTaskAction -Execute $ahk -Argument "`"$PWD\PaperWM.ahk`"" -WorkingDirectory $PWD
$t = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0 -Priority 4
$p = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
Register-ScheduledTask PaperWM -Action $a -Trigger $t -Settings $s -Principal $p -Force
```

Zum Abschalten: `Unregister-ScheduledTask PaperWM` (ebenfalls als Administrator).

| Datei | Zweck |
| --- | --- |
| `PaperWM.ahk` | Das Skript selbst |
| `rescue.ahk` | Notfall: macht nach einem Absturz versteckte Fenster wieder sichtbar |
| `PaperWM.layout` | Gespeicherte Aufteilung der Workspaces, wird beim ersten Start angelegt |
| `PaperWM.log` | Fehlerprotokoll und Startzeit |

## Ausschalten

Ausgeschaltet wird über einen Rechtsklick auf das grüne „H“ im Infobereich der Taskleiste.

| Menüpunkt | Wirkung |
| --- | --- |
| Pausieren / Fortsetzen | Schaltet Kacheln und Tastenkürzel ab, Windows verhält sich wieder normal. Versteckte Fenster werden auf den linken Monitor geholt. Ein zweiter Klick schaltet PaperWM wieder ein und stellt die Aufteilung wieder her. |
| Alle Fenster zurückholen | Holt alle versteckten Fenster sichtbar auf den linken Monitor. PaperWM läuft weiter. |
| Neu laden | Startet das Skript neu, z. B. nach einer Änderung der Einstellungen. |
| Beenden | Beendet PaperWM bis zum nächsten Start. Die Aufteilung wird vorher gespeichert, versteckte Fenster werden zurückgeholt. |

- **Dauerhaft abschalten:** Beenden und zusätzlich den Autostart abschalten (siehe oben).
- **Nach einem Absturz** sind Fenster eventuell noch unsichtbar geschaltet. Sie stehen dann zwar in der Taskleiste, erscheinen aber nicht. `rescue.ahk` doppelklicken: Es macht sie wieder sichtbar und holt Fenster außerhalb der Bildschirme zurück. Ein erneuter Start von PaperWM erledigt das ebenfalls.

## Tastenkürzel: Fenster

| Taste | Wirkung |
| --- | --- |
| Windows+← / Windows+→ | Fokus auf die Spalte links / rechts |
| Windows+↑ / Windows+↓ | Fokus auf das Fenster darüber / darunter in der Spalte |
| Windows+. / Windows+, | Nächstes / vorheriges Fenster |
| Windows+Pos1 / Windows+Ende | Erstes / letztes Fenster |
| Windows+Strg+← / Windows+Strg+→ | Spalte nach links / rechts verschieben (auch Windows+Strg+, / . und Windows+Shift+, / .) |
| Windows+Strg+↑ / Windows+Strg+↓ | Fenster in der Spalte nach oben / unten verschieben |
| Windows+I | Fenster der rechten Spalte unten in die aktive Spalte holen |
| Windows+O | Unterstes Fenster der Spalte als eigene Spalte rechts ausgliedern |
| Windows+Shift+O | Aktives Fenster als eigene Spalte ausgliedern |
| Windows+R / Windows+Alt+R | Breite durchschalten: 38 % → 50 % → 62 % (vorwärts / rückwärts) |
| Windows+Shift+R / Windows+Alt+Shift+R | Höhe in der Spalte durchschalten |
| Windows++ / Windows+- | Breite um 100 px größer / kleiner (auch Ziffernblock + / -) |
| Windows+Shift++ / Windows+Shift+- | Höhe größer / kleiner |
| Windows+F | Volle Breite an / aus |
| Windows+Shift+F | Vollbild an / aus |
| Windows+C | Aktives Fenster mittig zentrieren |
| Windows+Shift+C | Fokusmodus umschalten: Standard / aktives Fenster immer zentriert |
| Windows+Ö / Windows+Ä | Streifen ein Stück nach links / rechts schieben |
| Windows+Shift+W | Wo neue Fenster erscheinen: rechts → links → Anfang → Ende → unten |
| Windows+Enter / Windows+N | Neues Fenster des aktiven Programms |
| Windows+Backspace | Aktives Fenster schließen |
| Windows+Mausrad | Fokus links / rechts (Extra, nicht in PaperWM) |

## Tastenkürzel: Workspaces und Monitore

Es gibt vier Workspaces, jeder Monitor zeigt einen davon. Beim Mitnehmen bleibt das aktive Fenster sichtbar, während der Workspace drumherum wechselt.

| Taste | Wirkung |
| --- | --- |
| Windows lange halten | Übersicht: alle Workspaces untereinander mit Live-Vorschauen der Fenster. Bei weiter gedrückter Windows-Taste wählen die Pfeiltasten ein Fenster, beim Loslassen springt PaperWM dorthin. Ein Klick wählt sofort, Windows+Esc bricht ab. Kurzes Tippen öffnet weiterhin das Startmenü. |
| Windows+Bild↓ / Windows+Bild↑ | Nächster / vorheriger Workspace |
| Windows+Strg+Bild↓ / Windows+Strg+Bild↑ | Aktives Fenster in den nächsten / vorherigen Workspace mitnehmen |
| Windows+^ | Zum zuletzt benutzten Workspace. Windows-Taste gedrückt halten und ^ mehrmals drücken blättert weiter. |
| Windows+Shift+^ | Dasselbe rückwärts |
| Windows+Strg+^ / Windows+Strg+Shift+^ | Dasselbe, das aktive Fenster wandert mit |
| Windows+T | Fenster aufnehmen. Dann mit gedrückter Windows-Taste zum Ziel wechseln, beim Loslassen wird es dort abgelegt. |
| Windows+Shift+← / → / ↑ / ↓ | Fokus auf den Monitor in dieser Richtung |
| Windows+Shift+Strg+← / → / ↑ / ↓ | Aktives Fenster auf den Monitor in dieser Richtung schieben |
| Windows+Alt+← / → / ↑ / ↓ | Workspaces mit dem Monitor in dieser Richtung tauschen |
| Strg+Alt+Shift+← / → / ↑ / ↓ | Aktiven Workspace auf den Monitor in dieser Richtung schieben |

## Tastenkürzel: Scratch-Layer, Alt-Tab und Maus

Der Scratch-Layer hält schwebende Fenster außerhalb des Streifens, etwa einen Rechner oder Notizen.

| Taste | Wirkung |
| --- | --- |
| Windows+Strg+Esc | Aktives Fenster zwischen Streifen und Scratch-Layer verschieben |
| Windows+Esc | Zuletzt benutztes Scratch-Fenster ein- / ausblenden |
| Windows+Shift+Esc | Ganzen Scratch-Layer ein- / ausblenden |
| Windows+Tab / Alt+Tab | Durch die zuletzt benutzten Fenster blättern (Windows bzw. Alt gedrückt halten) |
| Windows+Shift+Tab / Alt+Shift+Tab | Dasselbe rückwärts |
| Strg+Alt+Tab / Strg+Alt+Shift+Tab | Durch die Scratch-Fenster blättern |

**Mit der Maus:**

- Fensterrand ziehen: Die neue Breite wird übernommen.
- Fenster auf eine andere Spalte ziehen: Die Spalten werden umsortiert.
- Fenster auf den anderen Monitor ziehen: Es wandert in dessen Workspace.
- Klick auf ein Taskleisten-Symbol: Holt das Fenster in den Blick, auch von einem anderen Workspace.
- Klick auf die Vorschau eines angeschnittenen Fensters am Monitorrand: Holt das Fenster in den Blick.

## Einstellungen

Alle Einstellungen stehen am Anfang von `PaperWM.ahk`. Nach einer Änderung im Tray-Menü „Neu laden“ wählen.

| Einstellung | Bedeutung |
| --- | --- |
| `WINDOW_GAP`, `H_MARGIN`, `V_MARGIN`, `V_MARGIN_BOTTOM` | Abstand zwischen den Fenstern und zum Bildschirmrand (Standard 20 px). Alle px-Angaben gelten für 100 % Skalierung und werden pro Monitor umgerechnet. |
| `RESIZE_STEP`, `DRIFT_STEP`, `MIN_COL_WIDTH` | Schrittweite für Windows++/- und Windows+Ö/Ä, schmalste Spalte |
| `WIDTH_STEPS`, `HEIGHT_STEPS` | Stufen für Windows+R bzw. Windows+Shift+R |
| `NUM_WORKSPACES` | Anzahl der Workspaces (mindestens so viele wie Monitore) |
| `ANIM_MS` | Dauer der Animationen in ms, `0` = aus (Standard 180) |
| `OVERVIEW_DELAY` | Wie lange die Windows-Taste allein gehalten werden muss, bis die Übersicht erscheint, in ms, `0` = aus (Standard 400) |
| `HIGHLIGHT`, `HIGHLIGHT_COLOR`, `HIGHLIGHT_WIDTH` | Rahmen um das aktive Fenster: an/aus, Farbe (leer = Windows-Akzentfarbe, sonst z. B. `"4A90E2"`), Stärke |
| `HIGHLIGHT_DWM` | Zusätzlich den Windows-11-Fensterrand des aktiven Fensters einfärben |
| `FLOAT_EXES`, `FLOAT_CLASSES` | Programme bzw. Fensterklassen, die schweben statt gekachelt zu werden |
| `IGNORE_EXES`, `IGNORE_CLASSES` | Programme bzw. Fensterklassen, die PaperWM ganz ignoriert |
| `KEYMAP` | Alle Tastenkürzel |

## Wie es funktioniert und wo die Grenzen sind

- **Überschriebene Windows-Kürzel:** Solange PaperWM läuft, belegt es Windows+R (Ausführen), Windows+N, Windows+I, Windows+C, Windows+T, Windows+. (Emoji), Windows+Tab und Alt+Tab. Windows+V (Zwischenablage) bleibt frei. Zum vorübergehenden Benutzen im Tray-Menü pausieren.
- **Gehaltene Tasten:** Windows+T, mehrmaliges Windows+^ oder Windows+Tab und die Übersicht wirken nur, solange die Windows-Taste gedrückt bleibt.
- **Versteckte Fenster:** Fenster außerhalb des sichtbaren Bereichs und auf versteckten Workspaces werden unsichtbar geschaltet („cloaking“, derselbe Mechanismus wie bei den virtuellen Desktops von Windows). Sie bleiben dabei auf ihrem Monitor und in ihrer Größe, in Taskleiste und Alt+Tab. Fehlt dieser Mechanismus, werden sie ersatzweise rechts außerhalb aller Monitore geparkt.
- **Fenster am Rand zum Nachbarmonitor:** Unter Windows liegen alle Monitore auf einer gemeinsamen Fläche. Ein Fenster, das über die Kante ragt, erschiene also auf dem Nachbarmonitor. Deshalb ist das echte Fenster dort unsichtbar, und an seiner Stelle zeigt PaperWM eine Live-Vorschau in voller Größe, genau an der Monitorgrenze abgeschnitten. Nichts wird gestaucht, nichts ragt hinüber. Ein Klick auf die Vorschau holt das Fenster in den Blick. Am äußeren Rand ohne Nachbarmonitor ragt das echte Fenster einfach aus dem Bild. Die Erkennung richtet sich nach der tatsächlichen Monitoranordnung und funktioniert mit beliebig vielen Monitoren in jeder Größe.
  - Chrome, Edge, VS Code, Teams und andere Chromium/Electron-Apps zeichnen nicht, solange sie unsichtbar sind. Ihre Vorschau am Rand zeigt deshalb das letzte Bild, bis sie hereingescrollt werden.
  - Der farbige Rahmen um das aktive Fenster wird an der Monitorgrenze abgeschnitten.
- **Unterschiedliche Monitore:** Abstände und Schrittweiten werden mit der Skalierung des jeweiligen Monitors umgerechnet, Spaltenbreiten als Anteil der Monitorbreite gespeichert. Zieht ein Workspace auf einen größeren oder kleineren Monitor um, bleiben die Proportionen gleich.
- **Hervorhebung:** Um das aktive Fenster liegt ein Rahmen in der Windows-Akzentfarbe, wie bei PaperWM im Abstand zwischen den Fenstern.
- **Gespeicherte Aufteilung:** Workspaces, Spalten, Breiten, Höhen, die Zuordnung von Monitor zu Workspace und die Einstellungen landen in `PaperWM.layout`. Gespeichert wird kurz nach jeder Änderung, jede Minute und beim Beenden.
  - Nach einem Neustart von PaperWM werden Fenster über ihr Handle wiedererkannt, das klappt zuverlässig.
  - Nach einem Neustart von Windows werden sie über Programm und Fenstertitel erkannt, ersatzweise über Programm und Fensterklasse. Das ist nur so gut, wie die Titel gleich bleiben.
  - Minimierte Fenster, auch nach Windows+D, behalten ihren Platz und kommen beim Wiederherstellen genau dorthin zurück.
- **Animation:** Beim Scrollen und bei neuen Fenstern gleiten die Fenster an ihren Platz. Ändert sich die Größe eines Fensters, passiert das einmal am Anfang, danach wird nur verschoben, damit die Apps nicht ständig neu zeichnen müssen. Fenster, die unterwegs die Grenze zum Nachbarmonitor kreuzen, gleiten als abgeschnittene Live-Vorschau. Workspace-Wechsel gleiten senkrecht: Mit Windows+Bild↓ kommt der neue Workspace von unten, mit Windows+Bild↑ von oben. Liegt ein Monitor über oder unter dem aktuellen, wird nicht animiert.
- **Admin-Fenster** (z. B. der Task-Manager) werden ignoriert, solange das Skript nicht selbst als Admin läuft (beim Autostart über die Aufgabenplanung tut es das).
- **Fenster, die nicht kacheln:** Fenster mit fester Größe, Dialoge und Topmost-Fenster werden nicht gekachelt.
- **Virtuelle Desktops von Windows** besser nicht gleichzeitig benutzen. Die Workspaces ersetzen sie.
- **Snap:** Unter Einstellungen → System → Multitasking kann „Fenster andocken“ ausgeschaltet werden, damit Windows-Snap beim Ziehen nicht dazwischenfunkt.
- **Fehler** landen in `PaperWM.log`, ohne dass ein Dialog das Skript blockiert. Bei jedem Start steht dort, wie viele Sekunden nach dem Hochfahren PaperWM gestartet ist und wie lange die Einrichtung gedauert hat. Mit dem Startparameter `/debug` stehen dort zusätzlich die Zeiten jeder Aktion.
