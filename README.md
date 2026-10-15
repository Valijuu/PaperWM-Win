# PaperWM for Windows

**English** | [Deutsch](README.de.md)

Scrollable tiling in the style of [PaperWM](https://github.com/paperwm/PaperWM) for GNOME, as an AutoHotkey v2 script. Windows are arranged as columns on an endless horizontal strip, and the screen shows a section of it. Each monitor shows its own workspace. The shortcuts follow the PaperWM defaults.

Below, **Windows** means the Windows key. The keys `^`, `Ö` and `Ä` refer to the German QWERTZ layout. On other layouts they are the keys in the same position: `^` is the key left of `1`, `Ö` and `Ä` are the two keys right of `L`.

## Installation and start

1. Install [AutoHotkey v2](https://www.autohotkey.com/), for example with `winget install AutoHotkey.AutoHotkey`.
2. Clone this repo or download it as a ZIP.
3. Double-click `PaperWM.ahk`. If it is already running, it restarts.

You can tell PaperWM is running by AutoHotkey's green "H" in the notification area of the taskbar (bottom right, possibly behind the arrow).

**Start automatically with Windows:**

A scheduled task starts PaperWM right at sign-in. A shortcut in the startup folder (`shell:startup`) also works, but Windows deliberately runs those entries late after boot. The task also runs with admin rights, so PaperWM can tile admin windows such as Task Manager too.

Open PowerShell **as administrator**, change to the PaperWM folder and run:

```powershell
$ahk = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"   # adjust the path if needed
$a = New-ScheduledTaskAction -Execute $ahk -Argument "`"$PWD\PaperWM.ahk`"" -WorkingDirectory $PWD
$t = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0 -Priority 4
$p = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
Register-ScheduledTask PaperWM -Action $a -Trigger $t -Settings $s -Principal $p -Force
```

To turn it off: `Unregister-ScheduledTask PaperWM` (also as administrator).

| File | Purpose |
| --- | --- |
| `PaperWM.ahk` | The script itself |
| `rescue.ahk` | Emergency: makes hidden windows visible again after a crash |
| `PaperWM.layout` | Saved workspace layout, created on first start |
| `PaperWM.log` | Error log and start time |
| `Sessions` | Saved sessions (see "Sessions") |
| `PaperWM.last` | State at the last shutdown ("Letzte Sitzung", last session) |

## Tray menu and turning it off

Right-click the green "H" in the notification area of the taskbar (bottom right, next to the clock):

| Menu item | Effect |
| --- | --- |
| Pausieren / Fortsetzen (pause / resume) | Turns tiling and shortcuts off, Windows behaves normally again. Hidden windows are brought to the left monitor. A second click turns PaperWM back on and restores the layout. |
| Alle Fenster zurückholen (bring back all windows) | Brings all hidden windows visibly to the left monitor. PaperWM keeps running. |
| Sitzung speichern / laden / löschen (save / load / delete session) | See "Sessions". This is easier via the workspace indicator at the top left or the overview. |
| Neu laden (reload) | Restarts the script, for example after changing the settings. |
| Beenden (exit) | Exits PaperWM until the next start. The layout is saved first, hidden windows are brought back. |

- **Turn it off permanently:** exit and also remove the autostart (see above).
- **After a crash**, windows may still be switched invisible. They are listed in the taskbar but don't appear. Double-click `rescue.ahk`: it makes them visible again and brings back windows outside the screens. Starting PaperWM again does the same.

## Shortcuts: windows

| Key | Effect |
| --- | --- |
| Windows+← / Windows+→ | Focus the column to the left / right |
| Windows+↑ / Windows+↓ | Focus the window above / below in the column |
| Windows+. / Windows+, | Next / previous window |
| Windows+Home / Windows+End | First / last window |
| Windows+Ctrl+← / Windows+Ctrl+→ | Move the column left / right (also Windows+Ctrl+, / . and Windows+Shift+, / .) |
| Windows+Ctrl+↑ / Windows+Ctrl+↓ | Move the window up / down in the column |
| Windows+I | Pull the window of the right column into the bottom of the active column |
| Windows+O | Split the bottom window of the column off into its own column to the right |
| Windows+Shift+O | Split the active window off into its own column |
| Windows+R / Windows+Alt+R | Cycle the width: 38 % → 50 % → 62 % (forward / backward) |
| Windows+Shift+R / Windows+Alt+Shift+R | Cycle the height within the column |
| Windows++ / Windows+- | Width 100 px larger / smaller (also numpad + / -) |
| Windows+Shift++ / Windows+Shift+- | Height larger / smaller |
| Windows+F | Full width on / off |
| Windows+Shift+F | Fullscreen on / off |
| Windows+C | Center the active window |
| Windows+Shift+C | Toggle focus mode: default / active window always centered |
| Windows+Ö / Windows+Ä | Nudge the strip left / right |
| Windows+Shift+W | Where new windows appear: right → left → start → end → below |
| Windows+Enter / Windows+N | New window of the active program |
| Windows+Backspace | Close the active window |
| Windows+mouse wheel | Focus left / right (extra, not in PaperWM) |

## Shortcuts: workspaces and monitors

Each monitor shows one workspace. As in GNOME, workspaces come and go on their own: there is always exactly one empty workspace at the end. When you move a window into it, a new empty one is added. An empty workspace disappears as soon as no monitor shows it, and the rest move up. So you never have to delete anything. Exception: a workspace with its own name stays even when empty. When you take a window along, it stays visible while the workspace around it changes.

**Workspace indicator:** as in GNOME, the top left of each monitor shows a small pill with one dot per workspace. The workspace shown there is the elongated dash, white on the active monitor. Empty workspaces are darker. Next to it are the name of the workspace and two icons: 💾 saves the current session, ✎ opens a menu to rename the workspace and to load or delete sessions (the same menu is available by right-clicking). Clicking the dots or the name opens the overview. The indicator has its own strip at the top, and the windows start below it.

| Key | Effect |
| --- | --- |
| Tap Windows | Open / close the overview (see "Overview") |
| Windows+Page↓ / Windows+Page↑ | Next / previous workspace |
| Windows+F2 | Rename the current workspace (in the overview: F2 for the selected one). An empty name restores "Workspace n". |
| Windows+Ctrl+Page↓ / Windows+Ctrl+Page↑ | Take the active window to the next / previous workspace |
| Windows+^ | Go to the most recently used workspace. Holding Windows and pressing ^ repeatedly goes further back. |
| Windows+Shift+^ | The same, backwards |
| Windows+Ctrl+^ / Windows+Ctrl+Shift+^ | The same, taking the active window along |
| Windows+T | Pick up the window. Then switch to the target while holding Windows; releasing drops it there. |
| Windows+Shift+← / → / ↑ / ↓ | Focus the monitor in that direction |
| Windows+Shift+Ctrl+← / → / ↑ / ↓ | Move the active window to the monitor in that direction |
| Windows+Alt+← / → / ↑ / ↓ | Swap workspaces with the monitor in that direction |
| Ctrl+Alt+Shift+← / → / ↑ / ↓ | Move the active workspace to the monitor in that direction |

## Overview

A short tap on Windows (or a click on the workspace indicator at the top left) opens an overview as in GNOME: all workspaces stacked, with large live previews of the windows, all rows the same size. If not all workspaces fit on the screen, or a workspace is wider than the screen, the overview scrolls along with the selection as in niri.

At the top left are the buttons **Sitzung speichern** (save session), **Sitzung laden ▾** (load session) and **Hilfe** (help). The help shows all keys of the overview.

| Key | Effect |
| --- | --- |
| ← → ↑ ↓, Tab, mouse wheel | Select a window or workspace (including empty workspaces) |
| Enter or click | Jump to the selected window or workspace |
| Esc or tap Windows | Close the overview |
| Type text | Open Windows search with that text, as in GNOME |
| F2 | Rename the selected workspace |
| Ctrl+S | Save a session (only while the overview is open; otherwise Ctrl+S goes to your programs as usual) |
| F1 | Show / hide the help |

Because tapping Windows opens the overview, the Start menu is available via **Ctrl+Esc** or the Windows icon in the taskbar. If you prefer the Start menu as usual: `OVERVIEW_ON_TAP := false` (see "Settings").

## Shortcuts: scratch layer, Alt-Tab and mouse

The scratch layer keeps floating windows outside the strip, such as a calculator or notes.

| Key | Effect |
| --- | --- |
| Windows+Ctrl+Esc | Move the active window between the strip and the scratch layer |
| Windows+Esc | Show / hide the most recently used scratch window |
| Windows+Shift+Esc | Show / hide the whole scratch layer |
| Windows+Tab / Alt+Tab | Cycle through recently used windows (hold Windows or Alt) |
| Windows+Shift+Tab / Alt+Shift+Tab | The same, backwards |
| Ctrl+Alt+Tab / Ctrl+Alt+Shift+Tab | Cycle through the scratch windows |

**With the mouse:**

- Drag a window edge: the new width is kept.
- Drag a window onto another column: the columns are reordered.
- Drag a window to the other monitor: it moves into that monitor's workspace.
- Click a taskbar icon: brings the window into view, even from another workspace.
- Click the preview of a cut-off window at the monitor edge: brings the window into view.
- Workspace indicator at the top left: clicking the dots or the name opens the overview, 💾 saves a session, ✎ or right-click opens the menu (rename, load / delete session).
- In the overview: clicking a preview jumps to that window.

## Sessions

A session stores all workspaces with all windows and remembers how each program is started. When you load it, its workspaces are added as **new workspaces**; your current ones stay as they are. PaperWM starts the missing programs, puts every window in its place and jumps to the first loaded workspace. Programs that are already running (such as Teams via autostart) are reused instead of being started twice; their windows move into the new workspaces.

- **Save:** the 💾 icon on the workspace indicator at the top left, "Sitzung speichern" (save session) at the top left of the overview (or Ctrl+S, only while the overview is open), or the tray menu (green "H" at the bottom right next to the clock). Then enter a name, such as "Work" or "Uni".
- **Load:** the ✎ icon on the indicator → "Sitzung laden" (load session), "Sitzung laden ▾" in the overview, or the tray menu. It also lists "Letzte Sitzung" (last session): the state at the last shutdown.
- **Delete:** the ✎ icon on the indicator → "Sitzung löschen" (delete session), or the tray menu.
- **After boot**, PaperWM asks how to start: "Leer starten" (start empty), "Letzte Sitzung" (last session) or a saved session. Without a choice it continues with "start empty" after 15 seconds.

Limits:

- **Content** is restored by the programs themselves, not by PaperWM. Chrome reopens its tabs if "Continue where you left off" is set in Chrome. VS Code opens the last folder, Obsidian the vault, Explorer the saved folder. Other programs only open an empty window.
- If a program needs several windows, PaperWM starts it several times if needed. Programs that only allow one window get only one.
- Started programs run without admin rights, even if PaperWM itself runs as admin.

Sessions are stored as files in the `Sessions` folder.

## Settings

All settings are at the top of `PaperWM.ahk`. After a change, choose "Neu laden" (reload) in the tray menu.

| Setting | Meaning |
| --- | --- |
| `WINDOW_GAP`, `H_MARGIN`, `V_MARGIN`, `V_MARGIN_BOTTOM` | Gap between windows and to the screen edge (default 20 px). All px values are for 100 % scaling and are converted per monitor. |
| `RESIZE_STEP`, `DRIFT_STEP`, `MIN_COL_WIDTH` | Step size for Windows++/- and Windows+Ö/Ä, narrowest column |
| `WIDTH_STEPS`, `HEIGHT_STEPS` | Steps for Windows+R and Windows+Shift+R |
| `ANIM_MS` | Animation duration in ms, `0` = off (default 180) |
| `OVERVIEW_ON_TAP` | Tapping Windows opens the overview instead of the Start menu (default `true`) |
| `SHOW_INDICATOR`, `INDICATOR_SIZE` | Workspace indicator at the top left on / off, its height in px (default 21; the top margin grows with it) |
| `HIGHLIGHT`, `HIGHLIGHT_COLOR`, `HIGHLIGHT_WIDTH` | Frame around the active window: on/off, color (empty = Windows accent color, brightened if it is too dark, otherwise e.g. `"4A90E2"`), thickness |
| `HIGHLIGHT_DWM` | Also color the Windows 11 border of the active window |
| `FLOAT_EXES`, `FLOAT_CLASSES` | Programs or window classes that float instead of being tiled |
| `IGNORE_EXES`, `IGNORE_CLASSES` | Programs or window classes that PaperWM ignores entirely |
| `STARTUP_PROMPT`, `STARTUP_TIMEOUT` | Prompt after boot on / off, seconds until "start empty" (default 15) |
| `KEYMAP` | All shortcuts |

## How it works and where the limits are

- **Overridden Windows shortcuts:** while PaperWM runs, it takes over tapping Windows (Start menu, see the overview), Windows+R (Run), Windows+N, Windows+I, Windows+C, Windows+T, Windows+. (emoji), Windows+Tab and Alt+Tab. Windows+V (clipboard) stays free. To use them temporarily, pause PaperWM from the tray menu.
- **Held keys:** Windows+T and repeated Windows+^ or Windows+Tab only work while the Windows key stays pressed.
- **Hidden windows:** windows outside the visible area and on hidden workspaces are switched invisible ("cloaking", the same mechanism Windows uses for its virtual desktops). They stay on their monitor, keep their size, and remain in the taskbar and Alt+Tab. If this mechanism is unavailable, they are parked to the right outside all monitors instead.
- **Windows at the edge to a neighboring monitor:** on Windows, all monitors share one coordinate space, so a window that crosses the edge would show up on the neighboring monitor. That's why the real window is invisible there, and PaperWM shows a full-size live preview in its place, cut off exactly at the monitor boundary. Nothing is squeezed, nothing spills over. Clicking the preview brings the window into view. At an outer edge with no neighboring monitor, the real window simply extends off-screen. The detection follows the actual monitor arrangement and works with any number of monitors of any size.
  - Chrome, Edge, VS Code, Teams and other Chromium/Electron apps don't draw while they are invisible. Their edge preview therefore shows the last frame until they are scrolled into view.
  - The colored frame around the active window is cut off at the monitor boundary.
- **Different monitors:** gaps and step sizes are converted using each monitor's scaling, and column widths are stored as a fraction of the monitor width. When a workspace moves to a larger or smaller monitor, the proportions stay the same.
- **Highlight:** a frame in the Windows accent color surrounds the active window, in the gap between windows as in PaperWM. If the accent color is too dark to stand out on a dark wallpaper, it is brightened automatically.
- **Saved layout:** workspaces, columns, widths, heights, the monitor-to-workspace assignment and the settings are stored in `PaperWM.layout`. It is saved shortly after every change, every minute and on exit.
  - After restarting PaperWM, windows are recognized by their handle, which is reliable.
  - After restarting Windows, they are recognized by program and window title, falling back to program and window class. This is only as good as the titles stay the same.
  - Minimized windows, also after Windows+D, keep their place and return exactly there when restored.
- **Animation:** when scrolling and for new windows, windows glide into place. If a window's size changes, that happens once at the start; after that it is only moved, so apps don't have to redraw constantly. Windows that cross the boundary to a neighboring monitor on the way glide as a cut-off live preview. Workspace switches glide vertically: with Windows+Page↓ the new workspace comes from below, with Windows+Page↑ from above. If there is a monitor above or below the current one, there is no animation.
- **Admin windows** (such as Task Manager) are ignored unless the script itself runs as admin (it does when started via the scheduled task).
- **Windows that don't tile:** fixed-size windows, dialogs and topmost windows are not tiled.
- **Windows virtual desktops:** better not used at the same time. The workspaces replace them.
- **Snap:** under Settings → System → Multitasking you can turn off "Snap windows" so Windows Snap doesn't interfere when dragging.
- **Errors** go to `PaperWM.log` without a dialog blocking the script. On every start, the log records how many seconds after boot PaperWM started and how long setup took. With the start parameter `/debug`, it also records the time of every action.
