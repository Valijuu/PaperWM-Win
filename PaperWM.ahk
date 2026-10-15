;=============================================================================
; PaperWM für Windows – scrollendes Tiling nach dem Vorbild von PaperWM (GNOME)
; AutoHotkey v2 Prototyp
;
; Fenster liegen als Spalten auf einem endlosen horizontalen Streifen, der
; Bildschirm zeigt einen Ausschnitt davon. Jeder Monitor zeigt einen Workspace.
; Tastenkürzel = PaperWM-Defaults (siehe KEYMAP unten).
;=============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
DetectHiddenWindows true
SetWinDelay -1
KeyHistory 0
ListLines 0
A_MaxHotkeysPerInterval := 1000
InstallKeybdHook()

; Alle Koordinaten in physischen Pixeln (Per-Monitor-DPI-Awareness v2)
DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

;============================== Konfiguration ================================
; Pixelangaben gelten für 100 % Skalierung und werden pro Monitor mit dessen
; Skalierung umgerechnet (bei 150 % also z. B. 30 statt 20 px).
global WINDOW_GAP      := 20      ; Abstand zwischen Fenstern
global H_MARGIN        := 20      ; Rand links/rechts
global V_MARGIN        := 20      ; Rand oben
global V_MARGIN_BOTTOM := 20      ; Rand unten
global WIDTH_STEPS     := [0.38195, 0.5, 0.61804]   ; Super+R
global HEIGHT_STEPS    := [0.38195, 0.5, 0.61804]   ; Super+Shift+R
global RESIZE_STEP     := 100     ; px pro Super+Plus/Minus
global DRIFT_STEP      := 150     ; px pro Super+Ö/Ä
global MIN_COL_WIDTH   := 200     ; schmalste Spalte in px
global ANIM_MS         := 180     ; Dauer der Scroll-Animation in ms (0 = aus)
global WARP_MOUSE      := true    ; Maus beim Monitorwechsel mitnehmen
global OVERVIEW_ON_TAP := true    ; Tippen auf Windows öffnet die Übersicht statt des Startmenüs
global SHOW_INDICATOR  := true    ; Workspace-Anzeige oben links auf jedem Monitor
global SHOW_OSD        := true    ; Workspace-Anzeige einblenden

; Hervorhebung des aktiven Fensters
global HIGHLIGHT       := true    ; farbiger Rahmen im Abstand um das aktive Fenster
global HIGHLIGHT_COLOR := ""      ; "" = Windows-Akzentfarbe, sonst z. B. "4A90E2"
global HIGHLIGHT_WIDTH := 4       ; Rahmenstärke in px (kleiner als WINDOW_GAP halten)
global HIGHLIGHT_DWM   := true    ; zusätzlich den Windows-11-Fensterrand einfärben

; Workspace-Aufteilung wird hier gespeichert und beim Start wiederhergestellt
global LAYOUT_FILE     := A_ScriptDir "\PaperWM.layout"
global SESSION_DIR     := A_ScriptDir "\Sessions"         ; gespeicherte Sitzungen
global LAST_FILE       := A_ScriptDir "\PaperWM.last"     ; Stand beim letzten Herunterfahren
global BOOT_FILE       := A_ScriptDir "\PaperWM.boot"     ; erkennt den ersten Start nach dem Hochfahren
global STARTUP_PROMPT  := true    ; nach dem Hochfahren fragen: leer / letzte / gespeicherte Sitzung
global STARTUP_TIMEOUT := 15      ; Sekunden bis „Leer starten“ automatisch gewählt wird
global DEBUG           := InList("/debug", A_Args)   ; Zeitmessung ins PaperWM.log

; Fenster, die nie gekachelt werden (Shell, Overlays …)
global IGNORE_CLASSES := ["Shell_TrayWnd", "Shell_SecondaryTrayWnd", "Progman", "WorkerW"
    , "Windows.UI.Core.CoreWindow", "MultitaskingViewFrame", "XamlExplorerHostIslandWindow"
    , "TaskListThumbnailWnd", "ForegroundStaging", "NotifyIconOverflowWindow"
    , "TopLevelWindowForOverflowXamlIsland", "#32768", "tooltips_class32"]
global IGNORE_EXES := ["ShellExperienceHost.exe", "StartMenuExperienceHost.exe", "SearchHost.exe"
    , "SearchApp.exe", "TextInputHost.exe", "LockApp.exe", "Widgets.exe"]

; Fenster, die schweben (Scratch-Layer) statt gekachelt zu werden.
; Topmost-Fenster (z. B. Bild-im-Bild) schweben automatisch.
global FLOAT_EXES    := []                ; z. B. ["KeePassXC.exe"]
global FLOAT_CLASSES := ["#32770"]        ; Standard-Dialoge

; Programme, die zum Öffnen eines neuen Fensters Argumente brauchen (Super+Enter)
global NEW_WINDOW_ARGS := Map("Code.exe", "-n", "Cursor.exe", "-n")

; Tastenkürzel: # = Super, ^ = Strg, + = Umschalt, ! = Alt
; Tastennamen sind layoutunabhängig gewählt (deutsches QWERTZ):
;   vkBE = .   vkBC = ,   vkBB = +   vkBD = -   SC029 = ^ (Above_Tab)
;   SC027 = Ö, SC028 = Ä (für drift; [ und ] brauchen auf QWERTZ AltGr)
global KEYMAP := [
    ["#vkBE", "switch-next"], ["#vkBC", "switch-previous"],
    ["#Left", "switch-left"], ["#Right", "switch-right"],
    ["#Up", "switch-up"], ["#Down", "switch-down"],
    ["#Home", "switch-first"], ["#End", "switch-last"],
    ["#Tab", "live-alt-tab"], ["!Tab", "live-alt-tab"],
    ["#+Tab", "live-alt-tab-backward"], ["!+Tab", "live-alt-tab-backward"],
    ["^!Tab", "live-alt-tab-scratch"], ["+^!Tab", "live-alt-tab-scratch-backward"],
    ["#^vkBE", "move-right"], ["#+vkBE", "move-right"], ["#^Right", "move-right"],
    ["#^vkBC", "move-left"], ["#+vkBC", "move-left"], ["#^Left", "move-left"],
    ["#^Up", "move-up"], ["#^Down", "move-down"],
    ["#i", "slurp-in"], ["#o", "barf-out"], ["#+o", "barf-out-active"],
    ["#t", "take-window"],
    ["#r", "cycle-width"], ["#!r", "cycle-width-backwards"],
    ["#+r", "cycle-height"], ["#!+r", "cycle-height-backwards"],
    ["#vkBB", "resize-w-inc"], ["#vkBD", "resize-w-dec"],
    ["#+vkBB", "resize-h-inc"], ["#+vkBD", "resize-h-dec"],
    ["#NumpadAdd", "resize-w-inc"], ["#NumpadSub", "resize-w-dec"],
    ["#f", "toggle-maximize-width"], ["#+f", "paper-toggle-fullscreen"],
    ["#c", "center-horizontally"],
    ["#SC027", "drift-left"], ["#SC028", "drift-right"],
    ["#+c", "switch-focus-mode"], ["#+w", "switch-open-window-position"],
    ["#Enter", "new-window"], ["#n", "new-window"], ["#BackSpace", "close-window"],
    ["#Escape", "toggle-scratch-window"], ["#+Escape", "toggle-scratch-layer"],
    ["#F2", "rename-workspace"],
    ["#^Escape", "toggle-scratch"],
    ["#SC029", "previous-workspace"], ["#+SC029", "previous-workspace-backward"],
    ["#^SC029", "move-previous-workspace"], ["#+^SC029", "move-previous-workspace-backward"],
    ["#PgDn", "switch-down-workspace"], ["#PgUp", "switch-up-workspace"],
    ["#^PgDn", "move-down-workspace"], ["#^PgUp", "move-up-workspace"],
    ["#+Right", "switch-monitor-right"], ["#+Left", "switch-monitor-left"],
    ["#+Up", "switch-monitor-above"], ["#+Down", "switch-monitor-below"],
    ["#+^Right", "move-monitor-right"], ["#+^Left", "move-monitor-left"],
    ["#+^Up", "move-monitor-above"], ["#+^Down", "move-monitor-below"],
    ["#!Right", "swap-monitor-right"], ["#!Left", "swap-monitor-left"],
    ["#!Up", "swap-monitor-above"], ["#!Down", "swap-monitor-below"],
    ["^!+Right", "move-space-monitor-right"], ["^!+Left", "move-space-monitor-left"],
    ["^!+Up", "move-space-monitor-above"], ["^!+Down", "move-space-monitor-below"],
    ["#WheelDown", "switch-right"], ["#WheelUp", "switch-left"]
]

;================================ Zustand ====================================
class Space {
    __New(idx) {
        this.idx := idx
        this.cols := []        ; Array von Column
        this.focusCol := 0     ; 0 = leer
        this.scrollX := 0      ; Streifen-Koordinate am linken Rand des Arbeitsbereichs
        this.mon := 0          ; anzeigender Monitor (0 = versteckt)
        this.lastMon := 1
        this.lastScroll := 0   ; scrollX beim letzten Layout (Startpunkt der Animation)
        this.name := ""        ; eigener Name ("" = "Workspace n")
    }
}

SpaceName(sp) => sp.name != "" ? sp.name : "Workspace " sp.idx

class Column {
    __New(hwnd, width) {
        this.wins := [hwnd]
        this.fracs := [1.0]    ; Höhenanteile der Fenster
        this.width := width    ; Anteil an der nutzbaren Monitorbreite (0–1)
        this.focusRow := 1
        this.prevWidth := 0    ; für Super+F (ebenfalls Anteil)
        this.full := false     ; Super+Shift+F
        this.ord := 0          ; Sortierschlüssel, damit minimierte Fenster ihren Platz behalten
    }
}

global MONS := []          ; Monitore, links→rechts sortiert
global SPACES := []        ; Workspaces
global WINS := Map()       ; hwnd → Space (gekachelte Fenster)
global WIN_MRU := []       ; zuletzt fokussierte Fenster (Super+Tab)
global SPACE_MRU := []     ; zuletzt benutzte Workspaces (Super+^)
global TAKEN := []         ; mit Super+T aufgenommene Fenster
global OPEN_POSITIONS := ["right", "left", "start", "end", "down"]
global G := {active: 0, scratch: [], q: [], openPos: "right", focusCenter: false, paused: false
    , focusGrace: 0, hooks: [], parkX: 0, parkY: 0, osd: 0, osdText: 0, dirty: false
    , launch: Map()        ; hwnd → wie das Programm gestartet wird (für Sitzungen)
    , restore: 0, frozen: false, loadMenu: Menu(), delMenu: Menu()
    , minimized: Map()     ; hwnd → Platz im Streifen, solange das Fenster minimiert ist
    , placed: Map()        ; hwnd → zuletzt gesetzte Position (spart Abfragen)
    , borders: Map()       ; hwnd → unsichtbare Fensterränder
    , canCloak: false      ; Fenster lassen sich unsichtbar schalten (sonst: weit weg parken)
    , views: 0             ; IApplicationViewCollection der Shell (zum Cloaken)
    , peeks: Map()         ; hwnd → Vorschau {gui, thumb, key} (angeschnittene Fenster)
    , peekSrc: Map()       ; Vorschau-Fenster → Quellfenster (für Klicks)
    , anims: Map()         ; Space → laufende Animation
    , animPos: Map()       ; hwnd → aktuelle Zwischenposition während einer Animation
    , planOf: Map()        ; hwnd → letzter Layout-Plan (für die Hervorhebung)
    , self: DllCall("GetCurrentProcessId")}
global NAV := {active: false, kind: "", list: [], idx: 1, mon: 0, hwnd: 0}
global HL := {gui: 0, key: "", region: "", dwm: 0, cref: 0}
global OV := {active: false, opened: 0, down: 0, clean: false, ih: 0, kh: 0, searching: 0, buf: ""
    , ctrls: [], rows: [], scroll: 0, scrollAnim: 0, pad: 0, viewW: 0, viewH: 0, contentH: 0, top: 0, clip: 0, buttons: [], gui: 0, thumbs: [], items: [], sel: 0, mon: 1, frame: []}
global IND := Map()        ; Monitor → Workspace-Anzeige {gui, key}

global ACTIONS := Map(
    "switch-next", () => SwitchLinear(1),
    "switch-previous", () => SwitchLinear(-1),
    "switch-left", () => SwitchCol(-1),
    "switch-right", () => SwitchCol(1),
    "switch-up", () => SwitchRow(-1),
    "switch-down", () => SwitchRow(1),
    "switch-first", () => SwitchEdge(false),
    "switch-last", () => SwitchEdge(true),
    "live-alt-tab", () => LiveAltTab(1),
    "live-alt-tab-backward", () => LiveAltTab(-1),
    "live-alt-tab-scratch", () => LiveAltTab(1, true),
    "live-alt-tab-scratch-backward", () => LiveAltTab(-1, true),
    "move-left", () => MoveCol(-1),
    "move-right", () => MoveCol(1),
    "move-up", () => MoveRow(-1),
    "move-down", () => MoveRow(1),
    "slurp-in", SlurpIn,
    "barf-out", () => BarfOut(false),
    "barf-out-active", () => BarfOut(true),
    "take-window", TakeWindow,
    "cycle-width", () => CycleWidth(1),
    "cycle-width-backwards", () => CycleWidth(-1),
    "cycle-height", () => CycleHeight(1),
    "cycle-height-backwards", () => CycleHeight(-1),
    "resize-w-inc", () => ResizeW(1),
    "resize-w-dec", () => ResizeW(-1),
    "resize-h-inc", () => ResizeH(1),
    "resize-h-dec", () => ResizeH(-1),
    "toggle-maximize-width", ToggleMaxWidth,
    "paper-toggle-fullscreen", ToggleFullscreen,
    "center-horizontally", () => Refocus(CurSpace(), true),
    "drift-left", () => Drift(-1),
    "drift-right", () => Drift(1),
    "switch-focus-mode", ToggleFocusMode,
    "switch-open-window-position", CycleOpenPosition,
    "new-window", NewWindow,
    "close-window", CloseWindow,
    "toggle-scratch-window", ToggleScratchWindow,
    "toggle-scratch-layer", ToggleScratchLayer,
    "toggle-scratch", ToggleScratch,
    "rename-workspace", () => SetTimer(RenameSpace.Bind(CurSpace()), -1),
    "previous-workspace", () => PrevWorkspace(1),
    "previous-workspace-backward", () => PrevWorkspace(-1),
    "move-previous-workspace", () => PrevWorkspace(1, true),
    "move-previous-workspace-backward", () => PrevWorkspace(-1, true),
    "switch-down-workspace", () => SwitchWorkspace(1),
    "switch-up-workspace", () => SwitchWorkspace(-1),
    "move-down-workspace", () => MoveWorkspace(1),
    "move-up-workspace", () => MoveWorkspace(-1),
    "switch-monitor-right", () => SwitchMonitor("right"),
    "switch-monitor-left", () => SwitchMonitor("left"),
    "switch-monitor-above", () => SwitchMonitor("up"),
    "switch-monitor-below", () => SwitchMonitor("down"),
    "move-monitor-right", () => MoveMonitor("right"),
    "move-monitor-left", () => MoveMonitor("left"),
    "move-monitor-above", () => MoveMonitor("up"),
    "move-monitor-below", () => MoveMonitor("down"),
    "swap-monitor-right", () => SwapMonitor("right"),
    "swap-monitor-left", () => SwapMonitor("left"),
    "swap-monitor-above", () => SwapMonitor("up"),
    "swap-monitor-below", () => SwapMonitor("down"),
    "move-space-monitor-right", () => MoveSpaceMonitor("right"),
    "move-space-monitor-left", () => MoveSpaceMonitor("left"),
    "move-space-monitor-above", () => MoveSpaceMonitor("up"),
    "move-space-monitor-below", () => MoveSpaceMonitor("down")
)

;================================= Start =====================================
OnError(LogError)      ; Fehler ins Log statt blockierendem Dialog
t0 := A_TickCount
firstBoot := FirstStartSinceBoot()
if firstBoot && FileExist(LAYOUT_FILE)            ; Stand vom letzten Mal als „Letzte Sitzung“
    try FileCopy(LAYOUT_FILE, LAST_FILE, 1)
InitHighlight()
CloakInit()
Init()
for km in KEYMAP
    Hotkey(km[1], MakeHandler(ACTIONS[km[2]]))
for k in ["LWin", "RWin"]                 ; Tippen auf Windows: Übersicht
    Hotkey("~" k, OverviewPress), Hotkey("~" k " Up", OverviewRelease)
HotIf(OverviewIsOpen)                     ; Tasten, solange die Übersicht offen ist
for k in ["Left", "Right", "Up", "Down", "Tab", "+Tab", "Enter", "NumpadEnter", "Escape", "WheelUp", "WheelDown", "F2", "^s"]
    Hotkey(k, OverviewHotkey)
HotIf()

cb := CallbackCreate(WinEventProc, "F", 7)
for r in [[0x0003, 0x0003], [0x000A, 0x000B], [0x0016, 0x0017], [0x8001, 0x8003], [0x800C, 0x800C], [0x8017, 0x8018]]
    G.hooks.Push(DllCall("SetWinEventHook", "uint", r[1], "uint", r[2], "ptr", 0, "ptr", cb
        , "uint", 0, "uint", 0, "uint", 0x2, "ptr"))   ; OUTOFCONTEXT | SKIPOWNPROCESS

OnMessage(0x7E, (*) => SetTimer(OnDisplayChange, -1000))   ; WM_DISPLAYCHANGE
OnMessage(0x5555, (*) => SetTimer(DumpState, -1))          ; Debug: Zustand in PaperWM.state.txt schreiben
OnMessage(0x5556, DebugOverview)                            ; Debug: Übersicht ohne Halten öffnen/Taste senden
OnMessage(0x5557, (*) => DEBUG ? SetTimer(RestoreSession.Bind(SessionFile("_test")), -1) : 0)  ; Debug: Sitzung „_test“ laden
OnMessage(0x21, PeekMouseActivate)                          ; WM_MOUSEACTIVATE: Vorschau nicht aktivieren
OnMessage(0x201, PeekClick)                                 ; WM_LBUTTONDOWN auf einer Vorschau
OnMessage(0x204, IndicatorRightClick)                       ; WM_RBUTTONDOWN: Workspace umbenennen
SetTimer(Sanity, 2000)
SetTimer(PeriodicSave, 60000)                               ; zusätzlich regelmäßig speichern (Titel aktuell halten)
OnExit(Cleanup)

A_IconTip := "PaperWM für Windows"
A_TrayMenu.Delete()
A_TrayMenu.Add("Pausieren / Fortsetzen", TogglePause)
A_TrayMenu.Add("Alle Fenster zurückholen", (*) => RescueAll())
A_TrayMenu.Add()
A_TrayMenu.Add("Sitzung speichern …", (*) => SetTimer(SaveSessionPrompt, -1))
A_TrayMenu.Add("Sitzung laden", G.loadMenu)
A_TrayMenu.Add("Sitzung löschen", G.delMenu)
BuildSessionMenus()
A_TrayMenu.Add()
A_TrayMenu.Add("Neu laden", (*) => Reload())
A_TrayMenu.Add("Beenden", (*) => ExitApp())

TidySpaces()
UpdateIndicator()
UpdateHighlight()
SaveLayout()
Osd("PaperWM aktiv – " WINS.Count " Fenster")
Log(Format("Start: {:.1f} s nach Systemstart, Einrichtung {} ms, {} Fenster, Cloak {}"
    , t0 / 1000, A_TickCount - t0, WINS.Count, G.canCloak ? "an" : "aus"))
if firstBoot && STARTUP_PROMPT
    SetTimer(StartupPrompt, -1000)

Init() {
    old := LoadMonitors()
    st := LoadLayout()
    n := Max(MONS.Length, st ? st.n : 0)     ; leere entfernt TidySpaces danach wieder
    loop n
        SPACES.Push(Space(A_Index))

    ; Monitor → Workspace wie zuletzt (erkannt an der Monitorposition)
    pref := Map()
    if st {
        for i, m in MONS
            for sm in st.mons
                if sm.rect = Format("{},{},{},{}", m.ml, m.mt, m.mr, m.mb) && sm.space >= 1 && sm.space <= n
                    pref[i] := sm.space
        if IndexOf(OPEN_POSITIONS, st.settings.Get("openPos", ""))
            G.openPos := st.settings["openPos"]
        G.focusCenter := st.settings.Get("focusCenter", "0") = "1"
        for idx in st.mru
            if idx >= 1 && idx <= n && !IndexOf(SPACE_MRU, SPACES[idx])
                SPACE_MRU.Push(SPACES[idx])
    }
    for sp in SPACES
        if !IndexOf(SPACE_MRU, sp)
            SPACE_MRU.Push(sp)
    AssignSpaces(old, pref)

    ; Kandidaten: kachelbare Fenster (Z-Reihenfolge, oberstes zuerst) und minimierte
    cands := Map(), order := [], minCands := Map(), used := Map()
    for h in WinGetList() {
        ; Reste eines Absturzes: unsichtbar geschaltete Fenster wieder zeigen, Zuschnitt und
        ; abgeschalteten Hintergrund älterer Versionen zurücksetzen
        UncloakWin(h)
        if p := DllCall("GetPropW", "ptr", h, "str", "PaperWM.Backdrop", "ptr") {
            DllCall("SetWindowRgn", "ptr", h, "ptr", 0, "int", 1)
            v := p - 1
            if v != 1
                DllCall("dwmapi\DwmSetWindowAttribute", "ptr", h, "uint", 38, "int*", v, "uint", 4)
            DllCall("RemovePropW", "ptr", h, "str", "PaperWM.Backdrop", "ptr")
            SetBorderColor(h, 0xFFFFFFFF)
        }
        if IsTileable(h) {
            cands[h] := WinInfo(h)
            order.Push(h)
        } else if IsTileable(h, true)
            minCands[h] := WinInfo(h)
    }

    ; Gespeicherte Aufteilung wiederherstellen
    if st {
        recs := []
        for idx, ws in st.spaces
            for c in ws.cols
                for r in c.wins
                    recs.Push(r)
        for r in st.scratch
            recs.Push(r)
        MatchRecords(recs, cands, used)
        MatchRecords(st.minimized, minCands, Map())

        for idx, ws in st.spaces {
            if idx > n
                continue
            sp := SPACES[idx]
            for c in ws.cols {
                ; Achtung: AHK-Variablen sind case-insensitiv, "wins" wäre die globale WINS
                found := [], fracs := [], sum := 0
                for r in c.wins
                    if r.match {
                        found.Push(r.match), fracs.Push(r.frac)
                        sum += r.frac
                    }
                if !found.Length
                    continue
                col := Column(found[1], SavedWidth(c.width, sp))
                col.wins := found, col.fracs := []
                for f in fracs
                    col.fracs.Push(sum > 0 ? f / sum : 1 / found.Length)
                col.full := c.full, col.prevWidth := c.prevWidth ? SavedWidth(c.prevWidth, sp) : 0, col.ord := c.ord
                col.focusRow := Clamp(c.focusRow, 1, found.Length)
                sp.cols.Push(col)
                for h in found
                    WINS[h] := sp
            }
            sp.scrollX := ws.scrollX, sp.name := ws.name
            sp.focusCol := Clamp(ws.focusCol, sp.cols.Length ? 1 : 0, sp.cols.Length)
        }
        for r in st.scratch
            if r.match
                G.scratch.Push(r.match)
        for z in st.minimized
            if z.match && z.space >= 1 && z.space <= n
                G.minimized[z.match] := {sp: SPACES[z.space], ord: z.ord, row: z.row, width: SavedWidth(z.width, SPACES[z.space])}
    }

    ; Übrige Fenster: pro Monitor nach x-Position sortiert anhängen
    buckets := []
    loop MONS.Length
        buckets.Push([])
    for h in order {
        if used.Has(h)
            continue
        if IsFloatRule(h) {
            G.scratch.Push(h)
            continue
        }
        fr := FrameRect(h)
        mi := MonAt((fr.l + fr.r) // 2, (fr.t + fr.b) // 2) || 1
        buckets[mi].Push({h: h, x: fr.l, w: fr.r - fr.l})
    }
    for mi, list in buckets {
        sp := MONS[mi].space
        top := list.Length ? list[1].h : 0
        SortByX(list)
        for e in list
            InsertWin(sp, e.h, "end", e.w)
        if top && !st
            sp.focusCol := Locate(top).ci
    }
    for h in order
        if WINS.Has(h)
            WIN_MRU.Push(h)

    for sp in SPACES {
        EnsureVisible(sp)
        Layout(sp)
    }
    fg := DllCall("GetForegroundWindow", "ptr")
    if st && st.active >= 1 && st.active <= n && SPACES[st.active].mon
        G.active := SPACES[st.active]
    else
        G.active := MONS[MonAtMouse()].space
    if WINS.Has(fg)
        RevealWindow(fg, false)
    MoveToFront(SPACE_MRU, G.active)
}

WinInfo(h) {
    info := {exe: "", cls: "", title: ""}
    try info.exe := WinGetProcessName(h), info.cls := WinGetClass(h), info.title := WinGetTitle(h)
    return info
}

; Ordnet gespeicherte Fenster den aktuell offenen zu: zuerst über das Handle
; (überlebt Neustarts des Skripts), dann über Programm + Titel, dann Programm + Klasse
; (nach einem Windows-Neustart).
MatchRecords(recs, cands, used) {
    loop 3 {
        pass := A_Index
        for r in recs {
            if r.match
                continue
            if pass = 1 {
                if cands.Has(r.hwnd) && !used.Has(r.hwnd) && cands[r.hwnd].exe = r.exe
                    r.match := r.hwnd, used[r.hwnd] := true
                continue
            }
            for h, c in cands {
                if used.Has(h) || c.exe != r.exe
                    continue
                if (pass = 2 && c.title == r.title) || (pass = 3 && c.cls = r.cls) {
                    r.match := h, used[h] := true
                    break
                }
            }
        }
    }
}

;========================= Aufteilung speichern/laden ========================
; Spätestens 1,5 s nach der ersten Änderung speichern. Ein anstehendes Speichern wird nicht
; verschoben, sonst käme es bei ständigen Fensterereignissen (z. B. Titel) nie dazu.
MarkDirty() {
    if !G.dirty
        G.dirty := true, SetTimer(SaveLayout, -1500)
}

SaveLayout() {
    Critical "On"
    G.dirty := false
    if !SPACES.Length || G.frozen               ; frozen: Sitzung wird gerade geladen
        return
    WriteFile(LAYOUT_FILE, LayoutText())
}

; Datei ersetzen, ohne dass bei einem Absturz eine halbe Datei übrig bleibt
WriteFile(path, text) {
    tmp := path ".tmp"
    try {
        if FileExist(tmp)
            FileDelete(tmp)
        FileAppend(text, tmp, "UTF-8")
        FileMove(tmp, path, 1)
        return true
    } catch Error as e {
        Log("Speichern von " path ": " e.Message)
        return false
    }
}

; Aktueller Zustand als Text: Workspaces, Spalten, Fenster samt Startinformationen
LayoutText() {
    s := "V`t2`n"
    s .= "S`topenPos`t" G.openPos "`nS`tfocusCenter`t" (G.focusCenter ? 1 : 0) "`n"
    s .= "N`t" SPACES.Length "`nA`t" (G.active ? G.active.idx : 1) "`n"
    for i, m in MONS
        s .= Format("M`t{}`t{},{},{},{}`t{}`n", i, m.ml, m.mt, m.mr, m.mb, m.space ? m.space.idx : 0)
    mru := "R"
    for sp in SPACE_MRU
        mru .= "`t" sp.idx
    s .= mru "`n"
    for sp in SPACES {
        s .= Format("W`t{}`t{}`t{}`t{}`n", sp.idx, Round(sp.scrollX), sp.focusCol, sp.name)
        for col in sp.cols {
            s .= Format("C`t{}`t{}`t{}`t{}`t{}`n", Round(col.width, 5), col.full ? 1 : 0, col.focusRow, Round(col.prevWidth, 5), col.ord)
            for ri, h in col.wins
                s .= "H`t" h "`t" Round(col.fracs[ri], 4) "`t" WinIdent(h) "`t" LaunchIdent(h) "`n"
        }
    }
    for h in G.scratch
        s .= "X`t" h "`t" WinIdent(h) "`t" LaunchIdent(h) "`n"
    for h, z in G.minimized
        s .= Format("Z`t{}`t{}`t{}`t{}`t{}`t{}`n", z.sp.idx, z.ord, z.row, Round(z.width, 5), h, WinIdent(h))
    return s
}

WinIdent(h) {
    i := WinInfo(h)
    return i.exe "`t" i.cls "`t" RegExReplace(i.title, "[\t\r\n]", " ")
}

LoadLayout(file := LAYOUT_FILE) {
    if !FileExist(file)
        return 0
    st := {settings: Map(), n: 0, active: 1, mons: [], mru: [], spaces: Map(), scratch: [], minimized: []}
    ws := 0, col := 0
    try {
        loop parse FileRead(file, "UTF-8"), "`n", "`r" {
            f := StrSplit(A_LoopField, "`t")
            if f.Length < 2
                continue
            switch f[1], true {
                case "S": st.settings[f[2]] := Fld(f, 3)
                case "N": st.n := Num(f[2])
                case "A": st.active := Num(f[2])
                case "M": st.mons.Push({rect: Fld(f, 3), space: Num(Fld(f, 4))})
                case "R":
                    loop f.Length - 1
                        st.mru.Push(Num(f[A_Index + 1]))
                case "W":
                    ws := {scrollX: Num(Fld(f, 3)), focusCol: Num(Fld(f, 4)), cols: [], name: Fld(f, 5)}
                    st.spaces[Num(f[2])] := ws, col := 0
                case "C":
                    if ws {
                        col := {width: Flt(f[2]), full: Fld(f, 3) = "1", focusRow: Num(Fld(f, 4))
                            , prevWidth: Flt(Fld(f, 5)), ord: Flt(Fld(f, 6)), wins: []}
                        ws.cols.Push(col)
                    }
                case "H":
                    if col
                        col.wins.Push({hwnd: Num(f[2]), frac: Float(Fld(f, 3) = "" ? 1 : Fld(f, 3))
                            , exe: Fld(f, 4), cls: Fld(f, 5), title: Fld(f, 6), match: 0
                            , path: Fld(f, 7), args: Fld(f, 8), aumid: Fld(f, 9)})
                case "X":
                    st.scratch.Push({hwnd: Num(f[2]), exe: Fld(f, 3), cls: Fld(f, 4), title: Fld(f, 5), match: 0
                        , path: Fld(f, 6), args: Fld(f, 7), aumid: Fld(f, 8)})
                case "Z":
                    st.minimized.Push({space: Num(f[2]), ord: Float(Fld(f, 3) = "" ? 0 : Fld(f, 3)), row: Num(Fld(f, 4))
                        , width: Flt(Fld(f, 5)), hwnd: Num(Fld(f, 6)), exe: Fld(f, 7), cls: Fld(f, 8), title: Fld(f, 9), match: 0})
            }
        }
    } catch Error as e {
        Log("Layout laden: " e.Message " (Zeile " e.Line ")")
        return 0
    }
    return st
}

Fld(f, i) => i <= f.Length ? f[i] : ""

PeriodicSave() => SaveLayout()     ; eigene Funktion, damit MarkDirty diesen Timer nicht ersetzt

;=============================== Sitzungen ===================================
; Eine Sitzung ist ein gespeichertes Layout (alle Workspaces und Fenster) samt der Angabe,
; wie jedes Programm gestartet wird. Beim Laden werden schon offene Fenster
; wiederverwendet, fehlende Programme gestartet und alles an seinen Platz gelegt.
; Beim ersten Start nach dem Hochfahren fragt PaperWM, womit es losgehen soll.

; Wie das Programm des Fensters h wieder gestartet wird (Pfad, Parameter, App-ID)
LaunchInfo(h) {
    if (li := G.launch.Get(h, 0)) && !li.dyn
        return li
    li := {path: "", args: "", aumid: "", dyn: false}
    try li.path := WinGetProcessPath(h)
    li.aumid := ViewAumid(h)
    cls := ""
    try cls := WinGetClass(h)
    if cls = "CabinetWClass" {                  ; Datei-Explorer: geöffneten Ordner merken
        li.dyn := true
        try for w in ComObject("Shell.Application").Windows
            if w.HWND = h {
                li.args := '"' w.Document.Folder.Self.Path '"'
                break
            }
    } else if li.path != "" && !IsPackaged(li.path)
        try li.args := ProcessArgs(WinGetPID(h))
    G.launch[h] := li
    return li
}

; Für die Layout-Datei: Pfad, Parameter, App-ID (ohne Tabs und Zeilenumbrüche)
LaunchIdent(h) {
    li := LaunchInfo(h), s := ""
    for v in [li.path, li.args, li.aumid]
        s .= (A_Index > 1 ? "`t" : "") RegExReplace(v, "[\t\r\n]", " ")
    return s
}

; Store-Apps und App-Rahmen lassen sich nur über ihre App-ID starten
IsPackaged(path) => InStr(path, "\WindowsApps\") || InStr(path, "\ApplicationFrameHost.exe")

; App-ID (AppUserModelID) des Fensters über die Shell (IApplicationView, Methode 17)
ViewAumid(h) {
    if !G.views
        return ""
    view := 0, p := 0, s := ""
    try {
        ComCall(6, G.views, "ptr", h, "ptr*", &view)              ; GetViewForHwnd
        ComCall(17, view, "ptr*", &p)                             ; GetAppUserModelId
        if p
            s := StrGet(p, "UTF-16"), DllCall("ole32\CoTaskMemFree", "ptr", p)
    }
    if view
        ObjRelease(view)
    return s
}

; Startparameter eines Prozesses (Kommandozeile ohne das Programm selbst)
ProcessArgs(pid) {
    for p in ComObjGet("winmgmts:").ExecQuery("SELECT CommandLine FROM Win32_Process WHERE ProcessId=" pid) {
        cl := ""
        try cl := Trim(p.CommandLine)
        if SubStr(cl, 1, 1) = '"'
            cl := SubStr(cl, InStr(cl, '"', , 2) + 1)
        else
            cl := (i := InStr(cl, " ")) ? SubStr(cl, i + 1) : ""
        return Trim(cl)
    }
    return ""
}

; Startet das Programm eines gespeicherten Fensters. Läuft PaperWM als Admin, startet die
; Shell das Programm, damit es nicht ebenfalls Admin-Rechte bekommt.
LaunchRecord(r) {
    if r.aumid != "" && (r.path = "" || IsPackaged(r.path))
        target := "shell:AppsFolder\" r.aumid, args := ""
    else if r.path != ""
        target := r.path, args := r.args
    else
        return false
    try {
        if A_IsAdmin
            ShellRun(target, args)
        else
            Run('"' target '"' (args != "" ? " " args : ""))
        return true
    } catch Error as e {
        Log("Start von " target ": " e.Message)
        return false
    }
}

; ShellExecute über den Explorer (läuft ohne Admin-Rechte), nach Lexikos
ShellRun(file, args := "") {
    desktop := ComObject("Shell.Application").Windows.FindWindowSW(0, 0, 8, 0, 1)  ; SWC_DESKTOP
    tlb := ComObjQuery(desktop, "{4C96BE40-915C-11CF-99D3-00AA004AE837}"        ; SID_STopLevelBrowser
        , "{000214E2-0000-0000-C000-000000000046}")                            ; IID_IShellBrowser
    ComCall(15, tlb, "ptr*", sv := ComValue(13, 0))          ; QueryActiveShellView
    iid := Buffer(16)
    NumPut("int64", 0x20400, "int64", 0x46000000000000C0, iid)   ; IID_IDispatch
    ComCall(15, sv, "uint", 0, "ptr", iid, "ptr*", sfvd := ComValue(9, 0))   ; GetItemObject
    sfvd.Application.ShellExecute(file, args)
}

LaunchKey(r) => r.aumid != "" && (r.path = "" || IsPackaged(r.path)) ? "app:" r.aumid
    : r.path != "" ? r.path "|" r.args : ""

; Alle Fenster einer Sitzung: gekachelte und Scratch-Fenster in Dateireihenfolge
SessionRecords(st) {
    recs := []
    idx := []
    for i in st.spaces
        idx.Push(i)
    for i in idx
        for c in st.spaces[i].cols
            for r in c.wins
                recs.Push(r)
    for r in st.scratch
        recs.Push(r)
    return recs
}

; Kachelbare Fenster, die gerade offen sind (Kandidaten für die Zuordnung)
OpenCandidates(skip) {
    cands := Map()
    for h in WinGetList()
        if !skip.Has(h) && IsTileable(h)
            cands[h] := WinInfo(h)
    return cands
}

; Lädt eine Sitzung: offene Fenster wiederverwenden, fehlende Programme starten, warten,
; dann das Layout schreiben und PaperWM neu laden (Init legt alles an seinen Platz)
RestoreSession(file, *) {
    if G.restore || !(st := LoadLayout(file))
        return
    recs := SessionRecords(st), used := Map()
    for r in recs
        r.hwnd := 0                               ; alte Handles gelten nicht mehr
    MatchRecords(recs, OpenCandidates(used), used)
    groups := Map()
    for r in recs
        if !r.match && (k := LaunchKey(r)) != "" {
            if !groups.Has(k)
                groups[k] := {first: r, recs: [], launched: 0, last: 0}
            groups[k].recs.Push(r)
        }
    for k, grp in groups
        if LaunchRecord(grp.first)
            grp.launched := 1, grp.last := A_TickCount
    G.restore := {file: file, recs: recs, used: used, groups: groups, start: A_TickCount}
    Osd("Sitzung wird geladen …")
    SetTimer(RestoreTick, 500)
}

RestoreTick() {
    Critical "On"
    rs := G.restore
    if !rs {
        SetTimer(RestoreTick, 0)
        return
    }
    open := []
    for r in rs.recs
        if !r.match
            open.Push(r)
    if open.Length
        MatchRecords(open, OpenCandidates(rs.used), rs.used)
    missing := 0, total := 0
    for r in rs.recs
        if LaunchKey(r) != "" || r.match
            total++, missing += !r.match
    elapsed := A_TickCount - rs.start
    if missing && elapsed < 30000 {
        ; Brauchen Programme mehrere Fenster (z. B. drei Chrome-Fenster) und kommt nichts
        ; mehr nach, ein weiteres Mal starten
        if elapsed > 6000
            for k, grp in rs.groups {
                need := 0
                for r in grp.recs
                    need += !r.match
                if need && grp.launched < grp.recs.Length && A_TickCount - grp.last > 4000
                    if LaunchRecord(grp.first)
                        grp.launched++, grp.last := A_TickCount
            }
        Osd(Format("Sitzung wird geladen … {} von {} Fenstern", total - missing, total))
        return
    }
    SetTimer(RestoreTick, 0)
    if missing
        Log(Format("Sitzung: {} Fenster sind nicht erschienen", missing))
    if DEBUG
        for r in rs.recs
            Log(Format("Sitzung: {} / {} → {}", r.exe, r.cls, r.match))
    ; Layout mit den zugeordneten Fenstern schreiben (H/X-Zeilen in Dateireihenfolge)
    out := "", i := 0
    loop parse FileRead(rs.file, "UTF-8"), "`n", "`r" {
        line := A_LoopField
        if line = ""
            continue
        f := StrSplit(line, "`t")
        if (f[1] = "H" || f[1] = "X") && ++i <= rs.recs.Length {
            f[2] := rs.recs[i].match
            line := ""
            for v in f
                line .= (A_Index > 1 ? "`t" : "") v
        }
        out .= line "`n"
    }
    G.restore := 0
    ; Nicht mehr speichern bis zum Neuladen: Reload() kehrt sofort zurück, und das Aufräumen
    ; beim Beenden würde sonst den alten Stand über die Sitzung schreiben
    G.frozen := true
    if WriteFile(LAYOUT_FILE, out)
        Reload()
    SetTimer(() => G.frozen := false, -5000)      ; nur falls das Neuladen scheitert
}

SessionFile(name) => SESSION_DIR "\" name ".session"

SessionList() {
    names := []
    loop files SESSION_DIR "\*.session"
        names.Push(SubStr(A_LoopFileName, 1, -8))
    return names
}

; Tray: aktuellen Zustand als Sitzung speichern
SaveSessionPrompt(*) {
    ib := InputBox("Name der Sitzung (z. B. Arbeit, Uni):", "Sitzung speichern", "w360 h130")
    if ib.Result != "OK"
        return
    name := Trim(RegExReplace(ib.Value, '[\\/:*?"<>|\t\r\n]', ""))
    if name = ""
        return
    if FileExist(SessionFile(name))
        && MsgBox("Die Sitzung „" name "“ gibt es schon. Überschreiben?", "Sitzung speichern", "YesNo Icon?") != "Yes"
        return
    DirCreate(SESSION_DIR)
    Critical "On"
    if WriteFile(SessionFile(name), LayoutText())
        Osd("Sitzung „" name "“ gespeichert")
    BuildSessionMenus()
}

DeleteSession(name, *) {
    if MsgBox("Sitzung „" name "“ löschen?", "Sitzung löschen", "YesNo Icon?") != "Yes"
        return
    try FileDelete(SessionFile(name))
    BuildSessionMenus()
}

; Untermenüs „Sitzung laden“ und „Sitzung löschen“ im Tray
BuildSessionMenus() {
    G.loadMenu.Delete(), G.delMenu.Delete()
    names := SessionList()
    if FileExist(LAST_FILE)
        G.loadMenu.Add("Letzte Sitzung (" FormatTime(FileGetTime(LAST_FILE), "dd.MM. HH:mm") ")"
            , (*) => RestoreSession(LAST_FILE))
    for name in names {
        G.loadMenu.Add(name, RestoreSession.Bind(SessionFile(name)))
        G.delMenu.Add(name, DeleteSession.Bind(name))
    }
    if !names.Length {
        G.delMenu.Add("(keine)", (*) => 0), G.delMenu.Disable("(keine)")
        if !FileExist(LAST_FILE)
            G.loadMenu.Add("(keine)", (*) => 0), G.loadMenu.Disable("(keine)")
    }
}

; Erster Start seit dem Hochfahren? (Startzeitpunkt von Windows in PaperWM.boot gemerkt)
FirstStartSinceBoot() {
    boot := DateAdd(A_Now, -(A_TickCount // 1000), "Seconds")
    prev := ""
    try prev := Trim(FileRead(BOOT_FILE))
    if prev != "" && IsNumber(prev) && Abs(DateDiff(boot, prev, "Seconds")) < 120
        return false
    try FileDelete(BOOT_FILE)
    try FileAppend(boot, BOOT_FILE)
    return true
}

; Abfrage nach dem Hochfahren: leer starten, letzte Sitzung oder gespeicherte Sitzung.
; Ohne Eingabe geht es nach STARTUP_TIMEOUT Sekunden mit „Leer starten“ weiter.
StartupPrompt() {
    opts := [{label: "Leer starten", file: ""}]
    if FileExist(LAST_FILE)
        opts.Push({label: "Letzte Sitzung (" FormatTime(FileGetTime(LAST_FILE), "dd.MM. HH:mm") ")", file: LAST_FILE})
    for name in SessionList()
        opts.Push({label: name, file: SessionFile(name)})
    if opts.Length < 2
        return
    labels := []
    for o in opts
        labels.Push(o.label)
    host := Gui("+AlwaysOnTop -MinimizeBox", "PaperWM")
    host.SetFont("s11", "Segoe UI")
    host.Add("Text", "w380", "Womit möchtest du starten?")
    lb := host.Add("ListBox", "w380 r" Min(opts.Length, 10) " Choose1", labels)
    cd := host.Add("Text", "w380 cGray")
    btn := host.Add("Button", "w120 Default", "Starten")
    left := STARTUP_TIMEOUT
    tick := 0
    done(idx) {
        SetTimer(tick, 0)
        try host.Destroy()
        if idx && opts[idx].file != ""
            RestoreSession(opts[idx].file)
    }
    stop(*) {                                     ; Auswahl begonnen: kein Countdown mehr
        SetTimer(tick, 0)
        cd.Value := ""
    }
    countdown() {
        if --left <= 0
            return done(1)
        cd.Value := "„Leer starten“ in " left " s"
    }
    tick := countdown
    lb.OnEvent("Change", stop)
    lb.OnEvent("DoubleClick", (*) => done(lb.Value))
    btn.OnEvent("Click", (*) => done(lb.Value))
    host.OnEvent("Close", (*) => done(0))
    host.OnEvent("Escape", (*) => done(0))
    cd.Value := "„Leer starten“ in " left " s"
    host.Show()
    SetTimer(tick, 1000)
}

Num(s) => IsNumber(s) ? Round(s) : 0

Flt(s) => IsNumber(s) ? Float(s) : 0

; Spaltenbreite aus der Layout-Datei: ältere Versionen speicherten Pixel statt Anteilen
SavedWidth(v, sp) {
    if v <= 0
        return DefaultWidth(SpaceMon(sp))
    return v > 2 ? Clamp(v / UsableW(SpaceMon(sp)), 0.05, 1) : v
}

;=============================== Monitore ====================================
LoadMonitors() {
    old := []
    for m in MONS
        old.Push(m.space)
    list := []
    loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
        MonitorGet(A_Index, &ml, &mt, &mr, &mb)
        list.Push({l: l, t: t, r: r, b: b, ml: ml, mt: mt, mr: mr, mb: mb, space: 0
            , scale: MonScale((ml + mr) // 2, (mt + mb) // 2)})
    }
    ; links→rechts, oben→unten
    i := 2
    while i <= list.Length {
        j := i
        while j > 1 && (list[j - 1].l > list[j].l || (list[j - 1].l = list[j].l && list[j - 1].t > list[j].t)) {
            tmp := list[j - 1], list[j - 1] := list[j], list[j] := tmp
            j--
        }
        i++
    }
    MONS.Length := 0
    for m in list
        MONS.Push(m)
    ; Parkposition: rechts außerhalb des gesamten virtuellen Bildschirms
    G.parkX := SysGet(76) + SysGet(78) + 100
    G.parkY := SysGet(77) + 100
    return old
}

; Skalierung des Monitors an Punkt x/y (1.0 = 100 %)
MonScale(x, y) {
    hmon := DllCall("MonitorFromPoint", "int64", (y << 32) | (x & 0xFFFFFFFF), "uint", 2, "ptr")
    dx := 96, dy := 96
    DllCall("shcore\GetDpiForMonitor", "ptr", hmon, "int", 0, "uint*", &dx, "uint*", &dy)
    return dx / 96
}

; Pixelwert aus der Konfiguration für Monitor m umrechnen
Px(v, m) => Round(v * m.scale)

AssignSpaces(old, pref := 0) {
    for sp in SPACES
        sp.mon := 0
    for i, m in MONS {
        sp := 0
        if pref && pref.Has(i)
            sp := SPACES[pref[i]]
        else if i <= old.Length
            sp := old[i]
        if !sp || sp.mon
            sp := FreeSpace()
        if !sp {
            sp := Space(SPACES.Length + 1)
            SPACES.Push(sp), SPACE_MRU.Push(sp)
        }
        m.space := sp, sp.mon := i, sp.lastMon := i
    }
}

FreeSpace() {
    for sp in SPACES
        if !sp.mon
            return sp
    return 0
}

; Wie bei GNOME: Leere Workspaces verschwinden, sobald sie nirgends angezeigt werden, und
; am Ende steht immer genau ein leerer. Workspaces mit minimierten Fenstern bleiben.
TidySpaces() {
    if NAV.active || OV.active || G.paused || !MONS.Length
        return
    held := Map()
    for h, z in G.minimized
        held[z.sp] := true
    keep := [], spare := 0
    for sp in SPACES
        if sp.cols.Length || sp.mon || held.Has(sp) || sp.name != ""   ; benannte bleiben
            keep.Push(sp)
        else if !spare
            spare := sp
    last := keep.Length ? keep[keep.Length] : 0
    if !last || last.cols.Length || held.Has(last)
        keep.Push(spare || Space(0))
    if keep.Length = SPACES.Length {
        same := true
        for i, sp in keep
            if SPACES[i] != sp
                same := false
        if same
            return
    }
    for sp in SPACES
        if !IndexOf(keep, sp)
            StopAnim(sp), RemoveVal(SPACE_MRU, sp)
    SPACES.Length := 0
    for i, sp in keep {
        sp.idx := i
        SPACES.Push(sp)
        if !IndexOf(SPACE_MRU, sp)
            SPACE_MRU.Push(sp)
    }
    MarkDirty()
}

;============================ Workspace-Anzeige ==============================
; Wie bei GNOME: oben links auf jedem Monitor eine dunkle Pille mit einem Punkt pro
; Workspace. Der dort angezeigte ist eine längliche Pille (weiß, wenn der Monitor aktiv
; ist), leere Workspaces sind dunkler. Liegt im oberen Rand über den Fenstern.
; Ein Klick öffnet die Übersicht auf diesem Monitor.
UpdateIndicator() {
    if !SHOW_INDICATOR || G.paused
        return
    for i, m in MONS {
        key := ""
        for sp in SPACES
            key .= sp = m.space ? "A" : sp.cols.Length ? "x" : "o"
        key .= (m.space = G.active ? "*" : "") "@" m.l "," m.t "," m.scale ":" SpaceName(m.space)
        entry := IND.Get(i, 0)
        if entry && entry.key = key
            continue
        if entry
            try entry.gui.Destroy()
        IND[i] := DrawIndicator(m, key)
    }
    gone := []
    for i in IND
        if i > MONS.Length
            gone.Push(i)
    for i in gone {
        try IND[i].gui.Destroy()
        IND.Delete(i)
    }
}

; Gezeichnet mit GDI+ (geglättete Kanten) in ein halbtransparentes Fenster (Layered Window)
DrawIndicator(m, key) {
    GdipInit()
    s := m.scale, hh := Round(16 * s), d := Round(8 * s), pill := Round(22 * s), gap := Round(5 * s)
    pad := (hh - d) // 2, fpx := 11 * s, active := m.space = G.active
    label := SpaceName(m.space)
    tw := GdipText(0, label, fpx)                            ; nur messen
    w := pad + Round(8 * s) + tw + hh // 2
    for sp in SPACES
        w += (sp = m.space ? pill : d) + gap
    w -= gap
    ; 32-Bit-Bild mit Alphakanal
    hdc := DllCall("CreateCompatibleDC", "ptr", 0, "ptr")
    bi := Buffer(40, 0)
    NumPut("uint", 40, "int", w, "int", -hh, "ushort", 1, "ushort", 32, bi)
    bits := 0
    hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", bi, "uint", 0, "ptr*", &bits, "ptr", 0, "uint", 0, "ptr")
    obm := DllCall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")
    gr := 0
    DllCall("gdiplus\GdipCreateFromHDC", "ptr", hdc, "ptr*", &gr)
    DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gr, "int", 4)      ; AntiAlias
    GdipPill(gr, 0xE0141414, 0, 0, w, hh)
    x := pad
    for sp in SPACES {
        cur := sp = m.space
        c := cur ? (active ? 0xFFFFFFFF : 0xFFB4B4B4) : sp.cols.Length ? 0xFF8C8C8C : 0xFF4C4C4C
        GdipPill(gr, c, x, pad, cur ? pill : d, d)
        x += (cur ? pill : d) + gap
    }
    GdipText(gr, label, fpx, active ? 0xFFFFFFFF : 0xFFB4B4B4, x - gap + Round(8 * s), 0, tw + 4, hh)
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
    ; im oberen Rand über den Fenstern, links bündig mit dem Streifen
    gx := m.l + Px(H_MARGIN, m), gy := m.t + Max(0, (Px(V_MARGIN, m) - hh) // 2)
    host := Gui("-Caption +ToolWindow +E0x08080000 -DPIScale")      ; NOACTIVATE | LAYERED
    pt := Buffer(8), NumPut("int", gx, "int", gy, pt)
    sz := Buffer(8), NumPut("int", w, "int", hh, sz)
    blend := Buffer(4), NumPut("uchar", 0, "uchar", 0, "uchar", 255, "uchar", 1, blend)  ; AC_SRC_ALPHA
    DllCall("UpdateLayeredWindow", "ptr", host.Hwnd, "ptr", 0, "ptr", pt, "ptr", sz, "ptr", hdc
        , "int64*", 0, "uint", 0, "ptr", blend, "uint", 2)
    host.Show(Format("x{} y{} w{} h{} NoActivate", gx, gy, w, hh))
    DllCall("SelectObject", "ptr", hdc, "ptr", obm)
    DllCall("DeleteObject", "ptr", hbm)
    DllCall("DeleteDC", "ptr", hdc)
    return {gui: host, key: key}
}

GdipInit() {
    static token := 0
    if token
        return
    DllCall("LoadLibrary", "str", "gdiplus", "ptr")
    si := Buffer(24, 0)
    NumPut("uint", 1, si)                                      ; GdiplusVersion
    DllCall("gdiplus\GdiplusStartup", "ptr*", &token, "ptr", si, "ptr", 0)
}

; Gefüllte Pille (bzw. Kreis, wenn w <= h) mit Farbe argb
GdipPill(gr, argb, x, y, w, h) {
    br := 0, path := 0
    DllCall("gdiplus\GdipCreateSolidFill", "uint", argb, "ptr*", &br)
    if w <= h
        DllCall("gdiplus\GdipFillEllipse", "ptr", gr, "ptr", br, "float", x, "float", y, "float", w, "float", h)
    else {
        DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &path)
        DllCall("gdiplus\GdipAddPathArc", "ptr", path, "float", x, "float", y, "float", h, "float", h, "float", 90, "float", 180)
        DllCall("gdiplus\GdipAddPathArc", "ptr", path, "float", x + w - h, "float", y, "float", h, "float", h, "float", 270, "float", 180)
        DllCall("gdiplus\GdipClosePathFigure", "ptr", path)
        DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", br, "ptr", path)
        DllCall("gdiplus\GdipDeletePath", "ptr", path)
    }
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
}

; Text in Segoe UI (Größe px), senkrecht zentriert im Rechteck x/y/w/h. Ohne gr wird nur
; gemessen. Gibt die Breite des Texts zurück.
GdipText(gr, text, px, argb := 0, x := 0, y := 0, w := 0, h := 0) {
    fam := 0, font := 0, fmt := 0, br := 0, tmpDC := 0, own := !gr
    if own {                                                  ; Messen: Hilfs-Grafik
        tmpDC := DllCall("CreateCompatibleDC", "ptr", 0, "ptr")
        DllCall("gdiplus\GdipCreateFromHDC", "ptr", tmpDC, "ptr*", &gr)
    }
    DllCall("gdiplus\GdipSetTextRenderingHint", "ptr", gr, "int", 4)  ; AntiAlias (für Transparenz)
    DllCall("gdiplus\GdipCreateFontFamilyFromName", "wstr", "Segoe UI", "ptr", 0, "ptr*", &fam)
    DllCall("gdiplus\GdipCreateFont", "ptr", fam, "float", px, "int", 0, "int", 2, "ptr*", &font)  ; Pixel
    DllCall("gdiplus\GdipCreateStringFormat", "int", 0x1000, "int", 0, "ptr*", &fmt)               ; NoWrap
    DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", fmt, "int", 1)                          ; Mitte
    rect := Buffer(16)
    NumPut("float", x, "float", y, "float", w || 1000, "float", h || 100, rect)
    if own {
        bound := Buffer(16, 0)
        DllCall("gdiplus\GdipMeasureString", "ptr", gr, "wstr", text, "int", -1, "ptr", font, "ptr", rect
            , "ptr", fmt, "ptr", bound, "ptr", 0, "ptr", 0)
        width := Ceil(NumGet(bound, 8, "float"))
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
        DllCall("DeleteDC", "ptr", tmpDC)
    } else {
        DllCall("gdiplus\GdipCreateSolidFill", "uint", argb, "ptr*", &br)
        DllCall("gdiplus\GdipDrawString", "ptr", gr, "wstr", text, "int", -1, "ptr", font, "ptr", rect, "ptr", fmt, "ptr", br)
        DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
        width := w
    }
    DllCall("gdiplus\GdipDeleteStringFormat", "ptr", fmt)
    DllCall("gdiplus\GdipDeleteFont", "ptr", font)
    DllCall("gdiplus\GdipDeleteFontFamily", "ptr", fam)
    return width
}

; Rechtsklick auf die Workspace-Anzeige: Menü mit Umbenennen und Sitzungen
IndicatorRightClick(wParam, lParam, msg, hwnd) {
    if mi := IndicatorMon(hwnd) {
        SetTimer(SpaceMenu.Bind(MONS[mi].space), -1)
        return 0
    }
}

SpaceMenu(sp) {
    mn := Menu()
    mn.Add(SpaceName(sp) " umbenennen …", (*) => SetTimer(RenameSpace.Bind(sp), -1))
    mn.Add()
    mn.Add("Sitzung speichern …", (*) => SetTimer(SaveSessionPrompt, -1))
    mn.Add("Sitzung laden", G.loadMenu)
    mn.Add("Sitzung löschen", G.delMenu)
    mn.Show()
}

; Fragt einen Namen für Workspace sp ab (leer = Standardname "Workspace n")
RenameSpace(sp) {
    if G.paused || !IndexOf(SPACES, sp)
        return
    ib := InputBox("Name für " SpaceName(sp) " (leer = Standardname):", "Workspace umbenennen", "w360 h130", sp.name)
    if ib.Result != "OK" || !IndexOf(SPACES, sp)
        return
    sp.name := Trim(RegExReplace(ib.Value, "[\t\r\n]+", " "))
    Critical "On"
    AfterChange()
    Osd(SpaceName(sp), sp.mon)
}

IndicatorClear() {
    for i, entry in IND
        try entry.gui.Destroy()
    IND.Clear()
}

; Monitor, dessen Workspace-Anzeige hwnd ist (0 = keine)
IndicatorMon(hwnd) {
    for i, entry in IND
        if entry.gui.Hwnd = hwnd
            return i
    return 0
}

OnDisplayChange() {
    Critical "On"
    AssignSpaces(LoadMonitors())
    G.placed.Clear()
    G.borders.Clear()          ; DPI kann sich geändert haben
    for sp in SPACES {
        EnsureVisible(sp)
        Layout(sp)
    }
    if !G.active || !G.active.mon
        G.active := MONS[1].space
    AfterChange()
}

MonAt(x, y) {
    for i, m in MONS
        if x >= m.ml && x < m.mr && y >= m.mt && y < m.mb
            return i
    return 0
}

MonAtMouse() {
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "ptr", pt)
    return MonAt(NumGet(pt, 0, "int"), NumGet(pt, 4, "int")) || 1
}

CurMonIdx() => (G.active && G.active.mon) ? G.active.mon : MonAtMouse()

SpaceMon(sp) => MONS[sp.mon ? sp.mon : Clamp(sp.lastMon, 1, MONS.Length)]

NeighborMon(idx, dir) {
    m := MONS[idx], cx := (m.ml + m.mr) / 2, cy := (m.mt + m.mb) / 2
    best := 0, bestD := 0
    for i, o in MONS {
        if i = idx
            continue
        dx := (o.ml + o.mr) / 2 - cx, dy := (o.mt + o.mb) / 2 - cy
        switch dir {
            case "right": ok := dx > 0 && Abs(dx) >= Abs(dy)
            case "left": ok := dx < 0 && Abs(dx) >= Abs(dy)
            case "down": ok := dy > 0 && Abs(dy) > Abs(dx)
            default: ok := dy < 0 && Abs(dy) > Abs(dx)
        }
        d := Abs(dx) + Abs(dy)
        if ok && (!best || d < bestD)
            best := i, bestD := d
    }
    return best
}

WarpTo(mi) {
    if WARP_MOUSE {
        m := MONS[mi]
        DllCall("SetCursorPos", "int", (m.l + m.r) // 2, "int", (m.t + m.b) // 2)
    }
}

; Zeigt sp auf Monitor monIdx. Ist sp schon auf einem anderen Monitor sichtbar,
; werden die beiden Workspaces getauscht, sonst wird der bisherige versteckt.
; dir: 1 = neuer Workspace gleitet von unten herein (wie Super+Bild↓), -1 = von oben,
; 0 = ohne Animation. keep: mitgenommenes Fenster, das dabei sichtbar bleibt.
ShowSpace(sp, monIdx, dir := 0, keep := 0) {
    m := MONS[monIdx], old := m.space
    if old = sp
        return
    ; Gleiten nur, wenn kein Monitor darüber/darunter liegt (sonst würde es hinüberragen)
    slide := dir && !sp.mon && ANIM_MS > 0 && !NeighborMon(monIdx, "up") && !NeighborMon(monIdx, "down")
    if sp.mon {
        other := sp.mon
        MONS[other].space := old
        if old
            old.mon := other, old.lastMon := other
    } else if old {
        old.mon := 0
    }
    m.space := sp, sp.mon := monIdx, sp.lastMon := monIdx
    if old {
        EnsureVisible(old)
        if slide
            SlideOut(old, monIdx, -dir)
        else
            Layout(old)
    }
    EnsureVisible(sp)
    if slide
        SlideIn(sp, dir, keep)
    else
        Layout(sp)
}

WsDir(from, to) => to.idx > from.idx ? 1 : -1

CurSpace() {
    sp := G.active
    if !sp || !sp.mon {
        sp := MONS[MonAtMouse()].space
        G.active := sp
    }
    return sp
}

;============================ Fensterfilter ==================================
; allowMin: auch minimierte Fenster zulassen (zum Wiedererkennen beim Start)
IsTileable(h, allowMin := false) {
    try {
        if !DllCall("IsWindowVisible", "ptr", h)
            return false
        if DllCall("GetAncestor", "ptr", h, "uint", 2, "ptr") != h     ; GA_ROOT
            return false
        style := WinGetStyle(h), ex := WinGetExStyle(h)
        if (style & 0x40000000) || !(style & 0x40000)                   ; WS_CHILD / nicht skalierbar
            return false
        if (ex & 0x80) || (ex & 0x08000000)                             ; TOOLWINDOW / NOACTIVATE
            return false
        if DllCall("GetWindow", "ptr", h, "uint", 4, "ptr") && !(ex & 0x40000)   ; Dialog mit Besitzer
            return false
        if IsCloaked(h) || (!allowMin && WinGetMinMax(h) = -1) || WinGetTitle(h) = ""
            return false
        pid := WinGetPID(h)
        if pid = G.self
            return false
        if InList(WinGetClass(h), IGNORE_CLASSES) || InList(WinGetProcessName(h), IGNORE_EXES)
            return false
        if !A_IsAdmin && IsElevated(pid)    ; Admin-Fenster lassen sich nicht verschieben
            return false
        return true
    }
    return false
}

IsFloatRule(h) {
    try return (WinGetExStyle(h) & 0x8) || InList(WinGetProcessName(h), FLOAT_EXES)
        || InList(WinGetClass(h), FLOAT_CLASSES)
    return false
}

; Von Windows/einer App unsichtbar geschaltet (eigene Cloaks zählen nicht)
IsCloaked(h) {
    if IsOwnCloaked(h)
        return false
    c := 0
    DllCall("dwmapi\DwmGetWindowAttribute", "ptr", h, "uint", 14, "uint*", &c, "uint", 4)
    return c != 0
}

IsElevated(pid) {
    static cache := Map()
    if cache.Has(pid)
        return cache[pid]
    res := true
    if hp := DllCall("OpenProcess", "uint", 0x1000, "int", 0, "uint", pid, "ptr") {
        tok := 0
        if DllCall("advapi32\OpenProcessToken", "ptr", hp, "uint", 0x8, "ptr*", &tok) {
            buf := Buffer(4, 0), len := 0
            if DllCall("advapi32\GetTokenInformation", "ptr", tok, "int", 20, "ptr", buf, "uint", 4, "uint*", &len)
                res := NumGet(buf, "uint") != 0
            DllCall("CloseHandle", "ptr", tok)
        }
        DllCall("CloseHandle", "ptr", hp)
    }
    cache[pid] := res
    return res
}

;============================== Geometrie ====================================
WinRect(h) {
    buf := Buffer(16, 0)
    DllCall("GetWindowRect", "ptr", h, "ptr", buf)
    return {l: NumGet(buf, 0, "int"), t: NumGet(buf, 4, "int"), r: NumGet(buf, 8, "int"), b: NumGet(buf, 12, "int")}
}

; Sichtbarer Rahmen ohne die unsichtbaren Resize-Ränder von Windows 10/11
FrameRect(h) {
    buf := Buffer(16, 0)
    if DllCall("dwmapi\DwmGetWindowAttribute", "ptr", h, "uint", 9, "ptr", buf, "uint", 16) != 0
        return WinRect(h)
    return {l: NumGet(buf, 0, "int"), t: NumGet(buf, 4, "int"), r: NumGet(buf, 8, "int"), b: NumGet(buf, 12, "int")}
}

UsableW(m) => m.r - m.l - 2 * Px(H_MARGIN, m)

ColWidth(col, m) => col.full ? m.r - m.l : Clamp(Round(col.width * UsableW(m)), Px(MIN_COL_WIDTH, m), UsableW(m))

; Pixelbreite → Anteil an der nutzbaren Breite von Monitor m
WidthFrac(w, m) => Clamp(w, Px(MIN_COL_WIDTH, m), UsableW(m)) / UsableW(m)

; Anteil einer Stufe aus WIDTH_STEPS, so dass zwei Spalten mit Abstand genau aufgehen
StepWidth(s, m) => (s * (UsableW(m) + Px(WINDOW_GAP, m)) - Px(WINDOW_GAP, m)) / UsableW(m)

DefaultWidth(m) => StepWidth(WIDTH_STEPS[2], m)

ColX(sp, ci, m) {
    x := 0
    loop ci - 1
        x += ColWidth(sp.cols[A_Index], m) + Px(WINDOW_GAP, m)
    return x
}

; Scrollt den Streifen so wenig wie möglich, damit die fokussierte Spalte ganz sichtbar ist
EnsureVisible(sp, center := false) {
    if !(col := FocusedCol(sp))
        return
    m := SpaceMon(sp), vw := m.r - m.l, hm := Px(H_MARGIN, m)
    x := ColX(sp, sp.focusCol, m), w := ColWidth(col, m)
    if col.full
        sp.scrollX := x
    else if center || G.focusCenter
        sp.scrollX := Round(x + w / 2 - vw / 2)
    else if x - hm < sp.scrollX
        sp.scrollX := x - hm
    else if x + w + hm > sp.scrollX + vw
        sp.scrollX := x + w + hm - vw
}

; Rechtecke aller Fenster eines Workspaces auf Monitor m: x relativ zum Streifenanfang,
; y relativ zur Monitoroberkante. width = Gesamtbreite des Streifens.
StripRects(sp, m) {
    rects := [], x := 0, gap := Px(WINDOW_GAP, m)
    for ci, col in sp.cols {
        w := ColWidth(col, m)
        if col.full
            top := 0, colH := m.mb - m.mt
        else
            top := m.t - m.mt + Px(V_MARGIN, m), colH := m.b - m.t - Px(V_MARGIN, m) - Px(V_MARGIN_BOTTOM, m)
        n := col.wins.Length, avail := colH - gap * (n - 1), y := top
        for ri, h in col.wins {
            hh := ri = n ? top + colH - y : Round(avail * col.fracs[ri])
            rects.Push({hwnd: h, ci: ci, x: x, y: y, w: w, h: hh})
            y += hh + gap
        }
        x += w + gap
    }
    rects.width := Max(0, x - gap)
    return rects
}

ComputePlans(sp) {
    m := MONS[sp.mon], plans := []
    stripL := m.l - sp.scrollX                    ; Bildschirm-x des Streifenanfangs
    for r in StripRects(sp, m) {
        sx := stripL + r.x, y := m.mt + r.y, w := r.w, hh := r.h
        ; Fenster behalten immer ihre volle Größe. peek: ragt in einen Nachbarmonitor →
        ; echtes Fenster unsichtbar, stattdessen eine am Monitorrand abgeschnittene
        ; Live-Vorschau. Am äußeren Rand des Desktops hängt das echte Fenster einfach
        ; über den Bildschirmrand hinaus.
        p := {hwnd: r.hwnd, x: sx, y: y, w: w, h: hh, sx: sx, show: true, peek: false}
        if sx >= m.r || sx + w <= m.l
            p.show := false
        else if HitsOtherMon(sx, y, w, hh, sp.mon) {
            if G.canCloak
                p.peek := true
            else
                p.show := false
        }
        plans.Push(p)
    }
    return plans
}

HitsOtherMon(x, y, w, h, self) {
    for i, o in MONS
        if i != self && x < o.mr && x + w > o.ml && y < o.mb && y + h > o.mt
            return true
    return false
}

Layout(sp, anim := false) {
    StopAnim(sp)
    if !sp.mon {
        for col in sp.cols
            for h in col.wins {
                G.planOf[h] := {show: false}
                MapDel(G.animPos, h)
                try HideWin(h)
            }
        sp.lastScroll := sp.scrollX
        return
    }
    plans := ComputePlans(sp)
    if anim && ANIM_MS > 0
        StartAnim(sp, plans)
    else
        ApplyPlans(sp, plans)
    sp.lastScroll := sp.scrollX
}

;------------------------------ Animation ------------------------------------
; Gleitet die Fenster eines Workspaces von ihrer aktuellen Position zum Ziel.
; Fenster, die dabei ganz auf ihrem Monitor bleiben, werden echt verschoben (die Größe
; einmal am Anfang, danach nur noch verschieben – die Apps müssen nicht neu zeichnen).
; Alle anderen sind währenddessen unsichtbar und gleiten als Live-Vorschau ("Geist"),
; die am Monitorrand abgeschnitten wird. So ragt auch mitten in der Animation nichts auf
; den Nachbarmonitor. Startet eine neue Animation, geht es nahtlos von der aktuellen
; Zwischenposition weiter.
StartAnim(sp, plans) {
    d := sp.scrollX - sp.lastScroll, items := []
    for p in plans {
        h := p.hwnd
        prev := G.animPos.Get(h, 0) || G.planOf.Get(h, 0)
        shown := prev && prev.show
        G.planOf[h] := p
        if !shown && !p.show
            continue                                    ; bleibt versteckt
        if shown
            fx := prev.x, fy := prev.y, fw := prev.w, fh := prev.h
        else
            fx := p.sx + d, fy := p.y, fw := p.w, fh := p.h  ; kommt mit dem Streifen herein
        if p.show
            tx := p.x, ty := p.y, tw := p.w, th := p.h
        else
            tx := p.sx, ty := p.y, tw := fw, th := fh      ; gleitet mit dem Streifen hinaus
        if shown && fx = tx && fy = ty && fw = tw && fh = th
            continue
        items.Push(AnimItem(h, fx, fy, tx, ty, tw, th, !shown || fw != tw || fh != th, sp.mon))
    }
    if !items.Length {
        ApplyPlans(sp, plans)
        return
    }
    PrepItems(items, sp.mon)
    G.anims[sp] := {plans: plans, items: items, start: A_TickCount, mon: sp.mon}
    SetTimer(AnimTick, 10)
    AnimTick()
}

; Geist wird ein Fenster, das schon unsichtbar ist oder unterwegs einen Nachbarmonitor berührt
AnimItem(h, fx, fy, tx, ty, w, hh, resize, mon) {
    l := Min(fx, tx), t := Min(fy, ty)
    ghost := G.canCloak && (IsOwnCloaked(h) || HitsOtherMon(l, t, Max(fx, tx) + w - l, Max(fy, ty) + hh - t, mon))
    return {h: h, fx: fx, fy: fy, tx: tx, ty: ty, w: w, hh: hh, resize: resize, ghost: ghost}
}

; Vor dem ersten Schritt: Geister unsichtbar schalten und das echte Fenster gleich in
; Zielgröße auf den eigenen Monitor setzen (moveGhosts), die übrigen auf ihre Zielgröße
PrepItems(items, mon, moveGhosts := true) {
    for it in items {
        MapDel(G.placed, it.h)
        try {
            if DllCall("IsZoomed", "ptr", it.h)
                DllCall("ShowWindow", "ptr", it.h, "int", 4)
            if it.ghost && !CloakWin(it.h)
                it.ghost := false                        ; lässt sich nicht unsichtbar schalten
            if it.ghost {
                if moveGhosts
                    PlaceOnMon(it.h, it.tx, it.ty, it.w, it.hh, mon)
            } else if it.resize
                AnimMove(it.h, it.fx, it.fy, it.w, it.hh, mon, true)
        }
    }
}

; Workspace-Wechsel: sichtbare Fenster des alten Workspaces gleiten senkrecht hinaus
; (dir -1 = nach oben) und werden danach versteckt
SlideOut(sp, mon, dir) {
    StopAnim(sp)
    m := MONS[mon], dy := dir * (m.mb - m.mt), items := []
    for col in sp.cols
        for h in col.wins {
            prev := G.animPos.Get(h, 0) || G.planOf.Get(h, 0)
            G.planOf[h] := {show: false}
            MapDel(G.placed, h)
            if prev && prev.show {
                it := AnimItem(h, prev.x, prev.y, prev.x, prev.y + dy, prev.w, prev.h, false, mon)
                it.ghost := G.canCloak                   ; nur die Vorschau gleitet, das Fenster bleibt
                items.Push(it)
            } else
                try HideWin(h)
        }
    sp.lastScroll := sp.scrollX
    if items.Length {
        PrepItems(items, mon, false)
        G.anims[sp] := {items: items, start: A_TickCount, mon: mon, finish: Layout.Bind(sp)}
        SetTimer(AnimTick, 10)
    }
}

; Workspace-Wechsel: Fenster des neuen Workspaces gleiten senkrecht herein
; (dir 1 = von unten). keep bleibt an seiner Position und rutscht nur an seinen Platz.
SlideIn(sp, dir, keep := 0) {
    StopAnim(sp)
    m := MONS[sp.mon], dy := dir * (m.mb - m.mt), items := []
    plans := ComputePlans(sp)
    for p in plans {
        h := p.hwnd
        prev := G.animPos.Get(h, 0) || (h = keep ? G.planOf.Get(h, 0) : 0)
        G.planOf[h] := p
        if !p.show
            continue
        if prev && prev.show
            fx := prev.x, fy := prev.y
        else
            fx := p.x, fy := p.y + dy
        items.Push(AnimItem(h, fx, fy, p.x, p.y, p.w, p.h, true, sp.mon))
    }
    sp.lastScroll := sp.scrollX
    if !items.Length {
        ApplyPlans(sp, plans)
        return
    }
    PrepItems(items, sp.mon)
    G.anims[sp] := {plans: plans, items: items, start: A_TickCount, mon: sp.mon}
    SetTimer(AnimTick, 10)
    AnimTick()
}

AnimTick() {
    Critical "On"
    fg := DllCall("GetForegroundWindow", "ptr"), done := []
    for sp, a in G.anims {
        t := Min(1, (A_TickCount - a.start) / ANIM_MS)
        e := 1 - (1 - t) ** 3                                ; ease-out
        for it in a.items {
            y := Round(it.fy + (it.ty - it.fy) * e)
            x := Round(it.fx + (it.tx - it.fx) * e)
            vis := true
            try {
                if it.ghost
                    vis := PeekShow(it.h, x, y, it.w, it.hh, MONS[a.mon])
                else
                    vis := AnimMove(it.h, x, y, it.w, it.hh, a.mon)
            }
            G.animPos[it.h] := {x: x, y: y, w: it.w, h: it.hh, show: vis}
            if it.h = fg
                UpdateHighlight()
        }
        if t >= 1
            done.Push(sp)
    }
    for sp in done {
        a := G.anims[sp]
        G.anims.Delete(sp)
        if a.HasOwnProp("finish")
            a.finish.Call()
        else
            ApplyPlans(sp, a.plans)
    }
    if done.Length
        UpdateHighlight()
    if !G.anims.Count
        SetTimer(AnimTick, 0)
}

StopAnim(sp) {
    if G.anims.Has(sp)
        G.anims.Delete(sp)
}

; Verschiebt ohne Prüfungen (für Animationsschritte); size: auch Größe setzen
MoveRaw(h, x, y, w, hh, size := false) {
    bd := Borders(h)
    DllCall("SetWindowPos", "ptr", h, "ptr", 0, "int", x - bd.l, "int", y - bd.t
        , "int", w + bd.l + bd.r, "int", hh + bd.t + bd.b, "uint", size ? 0x4214 : 0x4215)
}

; Animationsschritt für ein echtes Fenster. Würde es in einen Nachbarmonitor ragen (nur
; ohne Cloak-Möglichkeit), wird es so lange geparkt. Gibt zurück, ob es sichtbar ist.
AnimMove(h, x, y, w, hh, mon, size := false) {
    if HitsOtherMon(x, y, w, hh, mon) {
        MoveRaw(h, G.parkX, G.parkY, w, hh, size)
        return false
    }
    MoveRaw(h, x, y, w, hh, size)
    return true
}

; Unsichtbare Ränder einmal pro Fenster messen (die DWM-Abfrage ist vergleichsweise teuer)
Borders(h) {
    if bd := G.borders.Get(h, 0)
        return bd
    wr := WinRect(h), fr := FrameRect(h)
    bd := {l: fr.l - wr.l, t: fr.t - wr.t, r: wr.r - fr.r, b: wr.b - fr.b}
    if bd.l < 0 || bd.l > 50 || bd.t < 0 || bd.t > 50 || bd.r < 0 || bd.r > 50 || bd.b < 0 || bd.b > 50
        bd := {l: 0, t: 0, r: 0, b: 0}
    G.borders[h] := bd
    return bd
}

; Setzt alle Fenster eines Workspaces exakt auf ihre Zielposition
ApplyPlans(sp, plans) {
    m := MONS[sp.mon]
    for p in plans {
        h := p.hwnd
        G.planOf[h] := p
        MapDel(G.animPos, h)
        try {
            if p.show && !p.peek {
                ; unsichtbares Fenster erst fertig platzieren, dann zeigen (kein Flackern)
                PlaceWindow(h, p.x, p.y, p.w, p.h, !IsOwnCloaked(h))
                UncloakWin(h)
                PeekHide(h)
            } else if CloakWin(h) {
                PlaceOnMon(h, p.x, p.y, p.w, p.h, sp.mon)
                if p.peek
                    PeekShow(h, p.x, p.y, p.w, p.h, m)
                else
                    PeekHide(h)
            } else {
                p.show := false
                PeekHide(h)
                ParkWindow(h)
            }
        }
    }
}

; Setzt ein unsichtbares Fenster in voller Größe so nah wie möglich an x/y, aber ganz auf
; Monitor mon. So bekommt es vom Nachbarmonitor keine andere Skalierung (WM_DPICHANGED)
; und muss beim Hereinscrollen nicht neu skaliert werden.
PlaceOnMon(h, x, y, w, hh, mon) {
    m := MONS[mon]
    PlaceWindow(h, Clamp(x, m.ml, Max(m.ml, m.mr - w)), Clamp(y, m.mt, Max(m.mt, m.mb - hh)), w, hh)
}

;--------------------------- Unsichtbar schalten -----------------------------
; Wie die virtuellen Desktops von Windows (und komorebi): IApplicationView::SetCloak der
; Shell. Undokumentiert, funktioniert aber im Gegensatz zu DWMWA_CLOAK auch für Fenster
; anderer Programme. Das Fenster bleibt in Taskleiste und Alt+Tab, Live-Vorschauen davon
; funktionieren weiter. Ein Merker am Fenster selbst sorgt dafür, dass rescue.ahk und ein
; Neustart von PaperWM es nach einem Absturz wieder sichtbar machen.
CloakInit() {
    G.views := 0, G.canCloak := false
    try {
        shell := ComObject("{C2F03A33-21F5-47FA-B4BB-156362A2F239}", "{6D5140C1-7436-11CE-8034-00AA006009FA}")
        iid := GuidBuf("{1841C6D7-4F9D-42C0-AF41-8747538F10E5}"), coll := 0
        ComCall(3, shell, "ptr", iid, "ptr", iid, "ptr*", &coll)     ; IServiceProvider::QueryService
        G.views := coll, G.canCloak := coll != 0
    } catch Error as e
        Log("Unsichtbar schalten nicht verfügbar, Fenster werden geparkt: " e.Message)
}

GuidBuf(s) {
    b := Buffer(16)
    DllCall("ole32\CLSIDFromString", "str", s, "ptr", b)
    return b
}

ShellCloak(h, on) {
    loop 2 {                                   ; nach einem Neustart des Explorers neu verbinden
        if !G.views
            return false
        view := 0
        try {
            ComCall(6, G.views, "ptr", h, "ptr*", &view)              ; GetViewForHwnd
            ComCall(12, view, "int", 1, "int", on ? 2 : 0)            ; IApplicationView::SetCloak
            ObjRelease(view)
            return true
        } catch {
            if view
                ObjRelease(view)
        }
        if A_Index = 1 && !DllCall("IsWindow", "ptr", h)
            return false
        if A_Index = 1 {
            ObjRelease(G.views)
            CloakInit()
        }
    }
    return false
}

IsOwnCloaked(h) => DllCall("GetPropW", "ptr", h, "str", "PaperWM.Cloaked", "ptr") != 0

CloakWin(h) {
    if IsOwnCloaked(h)
        return true
    if !G.canCloak
        return false
    ; Merker vorher setzen: das Cloak-Ereignis kommt sofort und darf nicht als
    ; "Fenster verschwunden" gelten
    DllCall("SetPropW", "ptr", h, "str", "PaperWM.Cloaked", "ptr", 1)
    if ShellCloak(h, true)
        return true
    DllCall("RemovePropW", "ptr", h, "str", "PaperWM.Cloaked", "ptr")
    return false
}

UncloakWin(h) {
    if !IsOwnCloaked(h)
        return
    ShellCloak(h, false)
    DllCall("RemovePropW", "ptr", h, "str", "PaperWM.Cloaked", "ptr")
}

; Alle von PaperWM unsichtbar geschalteten Fenster wieder zeigen (Beenden/Pause)
UncloakAll() {
    for h in WinGetList()
        UncloakWin(h)
    hs := []
    for h in G.peeks
        hs.Push(h)
    for h in hs
        PeekDestroy(h)
}

; Versteckt ein Fenster: unsichtbar schalten (bleibt, wo es ist), sonst außerhalb aller
; Monitore parken. Beides lässt es in Taskleiste und Alt+Tab.
HideWin(h) {
    PeekHide(h)
    if !CloakWin(h)
        ParkWindow(h)
}

;------------------------------- Vorschau ------------------------------------
; Zeigt Fenster h (Rahmen bei x/y, Größe w×hh) als Live-Vorschau (DWM-Thumbnail),
; abgeschnitten an den Grenzen von Monitor m. Das echte Fenster ist dabei unsichtbar.
; Gibt zurück, ob etwas davon zu sehen ist.
PeekShow(h, x, y, w, hh, m) {
    vl := Max(x, m.ml), vt := Max(y, m.mt), vr := Min(x + w, m.mr), vb := Min(y + hh, m.mb)
    if vr <= vl || vb <= vt {
        PeekHide(h)
        return false
    }
    if !(pk := G.peeks.Get(h, 0)) {
        host := Gui("-Caption +ToolWindow +E0x08000000 -DPIScale")   ; nicht aktivierbar
        host.BackColor := "202020"
        thumb := 0
        if DllCall("dwmapi\DwmRegisterThumbnail", "ptr", host.Hwnd, "ptr", h, "ptr*", &thumb) != 0 {
            host.Destroy()
            return false
        }
        pk := G.peeks[h] := {gui: host, thumb: thumb, key: ""}
        G.peekSrc[host.Hwnd] := h
    }
    key := vl "," vt "," vr "," vb "," x "," y
    if pk.key = key
        return true
    pk.key := key
    ; Ziel = ganzes Vorschaufenster, Quelle = sichtbarer Ausschnitt (relativ zum Fensterrahmen)
    DllCall("dwmapi\DwmUpdateThumbnailProperties", "ptr", pk.thumb
        , "ptr", ThumbProps([0, 0, vr - vl, vb - vt], [vl - x, vt - y, vr - x, vb - y]))
    ; direkt hinter das (unsichtbare) Quellfenster einsortieren | NOACTIVATE | SHOWWINDOW
    DllCall("SetWindowPos", "ptr", pk.gui.Hwnd, "ptr", h, "int", vl, "int", vt
        , "int", vr - vl, "int", vb - vt, "uint", 0x50)
    return true
}

; DWM_THUMBNAIL_PROPERTIES: Ziel- und optional Quellrechteck [l, t, r, b], deckend, sichtbar,
; mit Titelleiste. Ohne Quelle wird das ganze Fenster ins Ziel skaliert.
ThumbProps(dest, src := 0) {
    props := Buffer(48, 0)
    NumPut("uint", src ? 0x1F : 0x1D, props, 0)
    NumPut("int", dest[1], "int", dest[2], "int", dest[3], "int", dest[4], props, 4)
    if src
        NumPut("int", src[1], "int", src[2], "int", src[3], "int", src[4], props, 20)
    NumPut("uchar", 255, props, 36)
    NumPut("int", 1, "int", 0, props, 40)
    return props
}

PeekHide(h) {
    if (pk := G.peeks.Get(h, 0)) && pk.key != "" {
        pk.key := ""
        DllCall("ShowWindow", "ptr", pk.gui.Hwnd, "int", 0)
    }
}

PeekDestroy(h) {
    if pk := G.peeks.Get(h, 0) {
        DllCall("dwmapi\DwmUnregisterThumbnail", "ptr", pk.thumb)
        MapDel(G.peekSrc, pk.gui.Hwnd)
        pk.gui.Destroy()
        G.peeks.Delete(h)
    }
}

; Sichtbare Vorschau des Fensters h (0 = keine)
PeekHwnd(h) => (pk := G.peeks.Get(h, 0)) && pk.key != "" ? pk.gui.Hwnd : 0

PeekMouseActivate(wParam, lParam, msg, hwnd) {
    if G.peekSrc.Has(hwnd) || (OV.gui && hwnd = OV.gui.Hwnd) || IndicatorMon(hwnd)
        return 3                                        ; MA_NOACTIVATE
}

; Klick auf eine Vorschau holt das Fenster in den Blick
PeekClick(wParam, lParam, msg, hwnd) {
    if mi := IndicatorMon(hwnd) {                       ; Workspace-Anzeige: Übersicht
        SetTimer(OverviewToggle.Bind(mi), -1)
        return 0
    }
    if OV.gui && hwnd = OV.gui.Hwnd {
        OverviewClick(lParam << 48 >> 48, lParam << 32 >> 48)
        return 0
    }
    if !G.peekSrc.Has(hwnd)
        return
    h := G.peekSrc[hwnd]
    SetTimer(() => RunAction(() => RevealWindow(h)), -1)
    return 0
}

; x/y/w/h beziehen sich auf den sichtbaren Rahmen. async: nicht auf die App warten
PlaceWindow(h, x, y, w, hh, async := true) {
    key := x "," y "," w "," hh
    c := G.placed.Get(h, 0)
    if c && c.key = key && A_TickCount - c.t < 1500
        return                                         ; gerade erst so gesetzt
    if DllCall("IsZoomed", "ptr", h)
        DllCall("ShowWindow", "ptr", h, "int", 4)     ; SW_SHOWNOACTIVATE: Maximierung aufheben
    bd := Borders(h)
    nx := x - bd.l, ny := y - bd.t, nw := w + bd.l + bd.r, nh := hh + bd.t + bd.b
    G.placed[h] := {key: key, t: A_TickCount, w: nw, h: nh}
    ; Größe unverändert? Bei frischem Cache ohne Abfrage, sonst nachmessen
    if c && c.HasOwnProp("w") && A_TickCount - c.t < 1500
        sameSize := c.w = nw && c.h = nh, samePos := false
    else {
        wr := WinRect(h)
        sameSize := wr.r - wr.l = nw && wr.b - wr.t = nh
        samePos := wr.l = nx && wr.t = ny
    }
    ; NOZORDER | NOACTIVATE | NOOWNERZORDER (+ ASYNCWINDOWPOS, + NOSIZE wenn möglich)
    if !(sameSize && samePos)
        DllCall("SetWindowPos", "ptr", h, "ptr", 0, "int", nx, "int", ny, "int", nw, "int", nh
            , "uint", 0x214 | (async ? 0x4000 : 0) | (sameSize ? 0x1 : 0))
}

; Parkt ein Fenster außerhalb aller Monitore (nur ohne Cloak-Möglichkeit)
ParkWindow(h) {
    if (c := G.placed.Get(h, 0)) && c.key = "park" && A_TickCount - c.t < 1500
        return
    G.placed[h] := {key: "park", t: A_TickCount}
    if WinGetMinMax(h) = 1
        DllCall("ShowWindow", "ptr", h, "int", 4)
    wr := WinRect(h)
    if wr.l = G.parkX && wr.t = G.parkY
        return
    DllCall("SetWindowPos", "ptr", h, "ptr", 0, "int", G.parkX, "int", G.parkY, "int", 0, "int", 0, "uint", 0x4215)
}

;=========================== Strip-Verwaltung ================================
Locate(h) {
    if !WINS.Has(h)
        return 0
    sp := WINS[h]
    for ci, col in sp.cols
        for ri, x in col.wins
            if x = h
                return {sp: sp, ci: ci, ri: ri, col: col}
    return 0
}

FocusedCol(sp) => (sp.focusCol >= 1 && sp.focusCol <= sp.cols.Length) ? sp.cols[sp.focusCol] : 0

FocusedHwnd(sp) {
    if !(col := FocusedCol(sp))
        return 0
    return col.wins[Clamp(col.focusRow, 1, col.wins.Length)]
}

EqualFracs(col) {
    col.fracs := []
    loop col.wins.Length
        col.fracs.Push(1 / col.wins.Length)
}

; Vergibt der Spalte i einen Sortierschlüssel zwischen ihren Nachbarn
AssignOrd(sp, i) {
    n := sp.cols.Length
    if i > 1 && i < n {
        p := sp.cols[i - 1].ord, q := sp.cols[i + 1].ord
        if q - p < 1e-9 {
            for k, c in sp.cols
                c.ord := k
            return
        }
        sp.cols[i].ord := (p + q) / 2
    } else if i > 1
        sp.cols[i].ord := sp.cols[i - 1].ord + 1
    else if i < n
        sp.cols[i].ord := sp.cols[i + 1].ord - 1
    else
        sp.cols[i].ord := 0
}

; width: Anteil an der nutzbaren Breite (≤ 1), Pixel (> 1) oder 0 = Standardbreite
InsertWin(sp, h, pos := "right", width := 0) {
    m := SpaceMon(sp)
    if width <= 0
        width := DefaultWidth(m)
    else if width > 1
        width := WidthFrac(width, m)
    WINS[h] := sp
    MapDel(G.placed, h)
    if pos = "down" && (col := FocusedCol(sp)) {
        col.wins.InsertAt(col.focusRow + 1, h)
        col.focusRow += 1
        EqualFracs(col)
        return
    }
    switch pos {
        case "left": i := Max(sp.focusCol, 1)
        case "start": i := 1
        case "end": i := sp.cols.Length + 1
        default: i := sp.focusCol + 1
    }
    sp.cols.InsertAt(i, Column(h, Min(width, 1)))
    AssignOrd(sp, i)
    sp.focusCol := i
}

; Fügt ein wiederhergestelltes (vorher minimiertes) Fenster an seinem alten Platz ein
RestoreSlot(h, z) {
    sp := z.sp, idx := sp.cols.Length + 1
    WINS[h] := sp
    MapDel(G.placed, h)
    for i, c in sp.cols {
        if c.ord = z.ord {                       ; Spalte gibt es noch → wieder einreihen
            c.wins.InsertAt(Clamp(z.row, 1, c.wins.Length + 1), h)
            EqualFracs(c)
            sp.focusCol := i, c.focusRow := Clamp(z.row, 1, c.wins.Length)
            return sp
        }
        if c.ord > z.ord {
            idx := i
            break
        }
    }
    col := Column(h, z.width)
    col.ord := z.ord
    sp.cols.InsertAt(idx, col)
    sp.focusCol := idx
    return sp
}

RemoveWin(h) {
    if !(loc := Locate(h))
        return 0
    sp := loc.sp, col := loc.col
    col.wins.RemoveAt(loc.ri)
    WINS.Delete(h)
    MapDel(G.planOf, h)
    if col.wins.Length {
        EqualFracs(col)
        if loc.ri < col.focusRow
            col.focusRow -= 1
        col.focusRow := Clamp(col.focusRow, 1, col.wins.Length)
    } else {
        sp.cols.RemoveAt(loc.ci)
        if loc.ci < sp.focusCol || (loc.ci = sp.focusCol && sp.focusCol > 1)
            sp.focusCol -= 1
        sp.focusCol := Clamp(sp.focusCol, sp.cols.Length ? 1 : 0, sp.cols.Length)
    }
    return loc
}

Manage(h, force := false) {
    if G.paused || WINS.Has(h) || IndexOf(G.scratch, h) || IndexOf(TAKEN, h) || !IsTileable(h)
        return
    if G.minimized.Has(h) {                   ; war minimiert → alter Platz
        sp := RestoreSlot(h, G.minimized[h])
        MapDel(G.minimized, h)
    } else {
        if !force && IsFloatRule(h) {
            G.scratch.InsertAt(1, h)
            return
        }
        sp := CurSpace()
        fr := FrameRect(h)
        InsertWin(sp, h, G.openPos, fr.r - fr.l)
    }
    MoveToFront(WIN_MRU, h)
    EnsureVisible(sp)
    Layout(sp, true)
    SetTimer(Relayout.Bind(sp), -400)      ; nochmal, falls die App sich selbst positioniert
}

Unmanage(h) {
    sp := WINS[h]
    wasFocused := FocusedHwnd(sp) = h
    RemoveWin(h)
    RemoveVal(WIN_MRU, h)
    MapDel(G.placed, h)
    try UncloakWin(h)                 ; z. B. minimiert: wieder sichtbar wiederherstellen
    PeekHide(h)
    EnsureVisible(sp)
    Layout(sp, true)
    if wasFocused && sp = G.active && sp.mon {
        ; Windows aktiviert jetzt selbst irgendein Fenster (evtl. auf einem versteckten
        ; Workspace). Diesen automatischen Fokuswechsel kurz ignorieren und selbst fokussieren.
        G.focusGrace := A_TickCount + 400
        SetTimer(FocusLater.Bind(sp), -80)
    }
}

Relayout(sp) {
    Critical "On"
    G.placed.Clear()
    try Layout(sp)
    UpdateHighlight()
}

FocusLater(sp) {
    Critical "On"
    if sp = G.active && sp.mon
        try FocusSpace(sp)
    G.focusGrace := 0
    UpdateHighlight()
}

; Schneller Weg: SetForegroundWindow direkt, WinActivate nur als Rückfallebene
Activate(h) {
    if !h || DllCall("GetForegroundWindow", "ptr") = h || DllCall("IsIconic", "ptr", h)
        return
    DllCall("SetForegroundWindow", "ptr", h)
    if DllCall("GetForegroundWindow", "ptr") != h
        try WinActivate(h)
}

FocusSpace(sp) {
    G.active := sp
    if !NAV.active
        MoveToFront(SPACE_MRU, sp)
    if h := FocusedHwnd(sp)
        Activate(h)
    else
        Activate(DllCall("GetShellWindow", "ptr"))   ; leerer Workspace: Desktop fokussieren
}

Refocus(sp, center := false) {
    EnsureVisible(sp, center)
    Layout(sp, true)
    FocusSpace(sp)
}

; Holt ein Fenster in den Blick: Workspace anzeigen, Fokus setzen, scrollen
RevealWindow(h, doActivate := true) {   ; Achtung: "activate" wäre die Funktion Activate()
    if !(loc := Locate(h))
        return
    sp := loc.sp
    if !sp.mon {
        mi := CurMonIdx(), cur := MONS[mi].space
        ShowSpace(sp, mi, cur ? WsDir(cur, sp) : 0)
    }
    sp.focusCol := loc.ci, loc.col.focusRow := loc.ri
    G.active := sp
    if !NAV.active
        MoveToFront(SPACE_MRU, sp)
    EnsureVisible(sp)
    Layout(sp, true)
    if doActivate
        Activate(h)
}

;================================ Events =====================================
WinEventProc(hook, event, hwnd, idObject, idChild, thread, time) {
    if (idObject & 0xFFFFFFFF) || (idChild & 0xFFFFFFFF) || !hwnd
        return
    G.q.Push([event, hwnd])
    SetTimer(ProcessEvents, -15)
}

ProcessEvents() {
    Critical "On"
    q := G.q
    G.q := []
    if G.paused
        return
    t0 := QPC()
    for e in q {
        try HandleEvent(e[1], e[2])
        catch Error as err
            Log("Event " Format("0x{:X}", e[1]) ": " err.Message " (Zeile " err.Line ")")
    }
    AfterChange()
    if DEBUG
        Log(Format("events x{} {:.1f} ms", q.Length, QPC() - t0))
}

HandleEvent(ev, h) {
    switch ev {
        case 0x8002, 0x8018, 0x800C, 0x0017:      ; SHOW, UNCLOAKED, NAMECHANGE, MINIMIZEEND
            Manage(h)
        case 0x0016:                               ; MINIMIZESTART: Platz merken
            if loc := Locate(h) {
                G.minimized[h] := {sp: loc.sp, ord: loc.col.ord, row: loc.ri, width: loc.col.width}
                Unmanage(h)
            }
        case 0x8001, 0x8003, 0x8017:               ; DESTROY, HIDE, CLOAKED
            if ev = 0x8017 && !IsCloaked(h)        ; von PaperWM selbst unsichtbar geschaltet
                return
            if WINS.Has(h)
                Unmanage(h)
            if ev != 0x8017 {
                RemoveVal(G.scratch, h)
                RemoveVal(TAKEN, h)
            }
            if ev = 0x8001
                MapDel(G.minimized, h), MapDel(G.placed, h), MapDel(G.borders, h), PeekDestroy(h)
        case 0x0003:                               ; FOREGROUND
            OnFocus(h)
        case 0x000A:                               ; MOVESIZESTART: Rahmen beim Ziehen ausblenden
            if WINS.Has(h)
                HideHighlight()
        case 0x000B:                               ; MOVESIZEEND
            MapDel(G.placed, h), MapDel(G.borders, h)   ; evtl. auf Monitor mit anderer DPI gezogen
            OnMoveSizeEnd(h)
    }
}

OnFocus(h) {
    ; Anderswo geklickt: Übersicht schließen (nicht durch einen verspäteten Fokuswechsel
    ; direkt nach dem Öffnen)
    if OV.active && A_TickCount - OV.opened > 300
        OverviewClose()
    if A_TickCount < G.focusGrace       ; automatischer Fokuswechsel nach dem Schließen
        return
    if WINS.Has(h) {
        if !NAV.active
            MoveToFront(WIN_MRU, h)
        ; Meist hat die Aktion selbst schon fokussiert und gescrollt → nichts zu tun
        loc := Locate(h)
        if loc.sp.mon && loc.sp = G.active && loc.sp.focusCol = loc.ci && loc.col.focusRow = loc.ri
            return
        RevealWindow(h, false)
        return
    }
    if IndexOf(G.scratch, h) {
        if !NAV.active
            MoveToFront(G.scratch, h)
        return
    }
    if IndexOf(TAKEN, h)
        return
    if IsTileable(h) {
        Manage(h)
        return
    }
    try {
        if InList(WinGetClass(h), ["Shell_TrayWnd", "Shell_SecondaryTrayWnd", "Progman", "WorkerW"])
            return
        fr := FrameRect(h)
        if mi := MonAt((fr.l + fr.r) // 2, (fr.t + fr.b) // 2)
            G.active := MONS[mi].space
    }
}

; Fenster wurde mit der Maus bewegt oder skaliert
OnMoveSizeEnd(h) {
    if !(loc := Locate(h))
        return
    sp := loc.sp, col := loc.col, fr := FrameRect(h)
    mi := MonAt((fr.l + fr.r) // 2, (fr.t + fr.b) // 2)
    if mi && sp.mon && mi != sp.mon {               ; auf anderen Monitor gezogen
        t := MONS[mi].space
        RemoveWin(h)
        InsertWin(t, h, "right", fr.r - fr.l)
        EnsureVisible(sp), Layout(sp)
        EnsureVisible(t), Layout(t)
        G.active := t
        return
    }
    m := SpaceMon(sp), newW := fr.r - fr.l
    if !col.full && Abs(newW - ColWidth(col, m)) > 4 {
        col.width := WidthFrac(newW, m)                ; Breite übernehmen
    } else if col.wins.Length = 1 && sp.mon {
        ; verschoben: Spalte an der Drop-Position einsortieren
        cx := (fr.l + fr.r) // 2 - m.l + sp.scrollX, x := 0, target := loc.ci, gap := Px(WINDOW_GAP, m)
        for i, c in sp.cols {
            w := ColWidth(c, m)
            if cx >= x && cx < x + w + gap {
                target := i
                break
            }
            x += w + gap
        }
        if target != loc.ci {
            sp.cols.RemoveAt(loc.ci)
            sp.cols.InsertAt(target, col)
            AssignOrd(sp, target)
        }
    }
    sp.focusCol := IndexOf(sp.cols, col), col.focusRow := loc.ri
    EnsureVisible(sp)
    Layout(sp, true)
}

Sanity() {
    Critical "On"
    dead := []
    for h, sp in WINS {
        alive := false
        try alive := DllCall("IsWindow", "ptr", h) && DllCall("IsWindowVisible", "ptr", h)
            && WinGetMinMax(h) != -1 && !IsCloaked(h)
        if !alive
            dead.Push(h)
    }
    for h in dead
        try Unmanage(h)
    for arr in [G.scratch, TAKEN, WIN_MRU] {
        i := arr.Length
        while i >= 1 {
            if !DllCall("IsWindow", "ptr", arr[i])
                arr.RemoveAt(i)
            i--
        }
    }
    for m in [G.minimized, G.placed, G.planOf, G.borders, G.animPos, G.launch] {
        gone := []
        for h in m
            if !DllCall("IsWindow", "ptr", h)
                gone.Push(h)
        for h in gone
            m.Delete(h)
    }
    gone := []
    for h in G.peeks
        if !DllCall("IsWindow", "ptr", h) || !WINS.Has(h)
            gone.Push(h)
    for h in gone
        PeekDestroy(h)
    if dead.Length
        UpdateHighlight()
}

;=========================== Hervorhebung ====================================
InitHighlight() {
    if !HIGHLIGHT
        return
    ; Eine zu dunkle Akzentfarbe wäre auf dunklem Hintergrund kaum zu sehen → aufhellen
    rgb := HIGHLIGHT_COLOR != "" ? HIGHLIGHT_COLOR : Brighten(AccentColor(), 0.6)
    v := Integer("0x" rgb)
    HL.cref := ((v & 0xFF) << 16) | (v & 0xFF00) | ((v >> 16) & 0xFF)     ; RRGGBB → COLORREF
    ; Werkzeugfenster, nicht aktivierbar, klickdurchlässig
    HL.gui := Gui("+ToolWindow -Caption +E0x08000020 -DPIScale")
    HL.gui.BackColor := rgb
    WinSetTransparent(255, HL.gui)
}

; Rahmenfarbe für die Übersicht (dunkler Hintergrund): Akzentfarbe, notfalls aufgehellt
OverviewColor() => Brighten(HIGHLIGHT_COLOR != "" ? HIGHLIGHT_COLOR : AccentColor(), 0.6)


; Mischt die Farbe RRGGBB so weit mit Weiß, dass ihre Helligkeit mindestens minL (0–1) ist
Brighten(rgb, minL) {
    v := Integer("0x" rgb), rr := (v >> 16) & 0xFF, gg := (v >> 8) & 0xFF, bb := v & 0xFF
    lum := (0.299 * rr + 0.587 * gg + 0.114 * bb) / 255
    if lum >= minL
        return rgb
    f := (minL - lum) / (1 - lum)                ; Anteil Weiß
    return Format("{:02X}{:02X}{:02X}", Round(rr + (255 - rr) * f), Round(gg + (255 - gg) * f), Round(bb + (255 - bb) * f))
}

AccentColor() {
    try {
        c := RegRead("HKCU\Software\Microsoft\Windows\DWM", "AccentColor")
        return Format("{:02X}{:02X}{:02X}", c & 0xFF, (c >> 8) & 0xFF, (c >> 16) & 0xFF)
    }
    return "4A90E2"
}

; Legt einen farbigen Rahmen direkt hinter das aktive Fenster. Er ist etwas größer
; als das Fenster und daher nur im Abstand zwischen den Fenstern sichtbar.
UpdateHighlight() {
    if !HL.gui
        return
    fg := DllCall("GetForegroundWindow", "ptr")
    if G.paused || !WINS.Has(fg) || !WINS[fg].mon {
        HideHighlight()
        return
    }
    p := G.animPos.Get(fg, 0) || G.planOf.Get(fg, 0)    ; während einer Animation: Zwischenposition
    if p && !p.show {
        HideHighlight()
        return
    }
    if p
        x := p.x, y := p.y, w := p.w, hh := p.h
    else {
        r := FrameRect(fg)
        x := r.l, y := r.t, w := r.r - r.l, hh := r.b - r.t
    }
    m := MONS[WINS[fg].mon]
    t := Px(HIGHLIGHT_WIDTH, m)
    x -= t, y -= t, w += 2 * t, hh += 2 * t
    ; Nur auf dem eigenen Monitor zeichnen: ragt das Fenster (angeschnitten oder mitten in
    ; der Animation) in den Nachbarmonitor, wird der Rahmen an der Grenze abgeschnitten
    cl := Max(0, m.ml - x), cr := Min(w, m.mr - x)
    if cr <= cl {
        HideHighlight()
        return
    }
    key := fg ":" x "," y "," w "," hh "," cl "," cr
    if key = HL.key
        return
    HL.key := key
    rkey := w "x" hh ":" cl "," cr
    if HL.region != rkey {
        d := 2 * (8 + t)                              ; Windows 11 rundet Ecken mit 8 px
        rgn := DllCall("CreateRoundRectRgn", "int", 0, "int", 0, "int", w, "int", hh, "int", d, "int", d, "ptr")
        if cl > 0 || cr < w {
            cut := DllCall("CreateRectRgn", "int", cl, "int", 0, "int", cr, "int", hh, "ptr")
            DllCall("CombineRgn", "ptr", rgn, "ptr", rgn, "ptr", cut, "int", 1)   ; RGN_AND
            DllCall("DeleteObject", "ptr", cut)
        }
        if DllCall("SetWindowRgn", "ptr", HL.gui.Hwnd, "ptr", rgn, "int", 1)
            HL.region := rkey                          ; Region gehört jetzt dem System
        else
            DllCall("DeleteObject", "ptr", rgn)
    }
    ; direkt hinter fg (bzw. hinter dessen Vorschau) einsortieren | NOACTIVATE | SHOWWINDOW
    behind := PeekHwnd(fg) || fg
    DllCall("SetWindowPos", "ptr", HL.gui.Hwnd, "ptr", behind, "int", x, "int", y, "int", w, "int", hh, "uint", 0x50)
    SetDwmBorder(fg)
}

HideHighlight() {
    if !HL.gui || HL.key = ""
        return
    HL.key := ""
    DllCall("ShowWindow", "ptr", HL.gui.Hwnd, "int", 0)
    SetDwmBorder(0)
}

; Windows 11: Fensterrand des aktiven Fensters einfärben, beim vorherigen zurücksetzen
SetDwmBorder(h) {
    if !HIGHLIGHT_DWM || HL.dwm = h
        return
    if HL.dwm   ; vorheriges Fenster: Standardrand
        SetBorderColor(HL.dwm, 0xFFFFFFFF)
    if h
        SetBorderColor(h, HL.cref)
    HL.dwm := h
}

; DWMWA_BORDER_COLOR: 0xFFFFFFFF = Standard, 0xFFFFFFFE = kein Rand, sonst COLORREF
SetBorderColor(h, c) {
    buf := Buffer(4)
    NumPut("uint", c, buf)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", h, "uint", 34, "ptr", buf, "uint", 4)
}

;=============================== Übersicht ===================================
; Wie bei GNOME: Einmal auf die Windows-Taste tippen zeigt alle Workspaces untereinander
; als verkleinerte Streifen mit Live-Vorschauen. Pfeiltasten/Tab wählen, Enter oder Klick
; springt hin, Esc oder erneutes Tippen schließt. Wer stattdessen Text tippt, landet mit
; diesem Text in der Windows-Suche. Das Startmenü öffnet sich beim Tippen auf Windows
; deshalb nicht mehr (weiterhin über Strg+Esc oder die Taskleiste).
; Auch per Klick auf die Workspace-Anzeige oben links.
OverviewPress(*) {
    if OV.down || G.paused || !OVERVIEW_ON_TAP
        return                                 ; Tastenwiederholung beim Halten ignorieren
    OV.down := A_TickCount, OV.clean := true
    ; Dummy-Taste bei gedrückter Windows-Taste: Windows sieht eine Kombination und öffnet
    ; beim Loslassen kein Startmenü. Windows+X-Kürzel funktionieren weiter.
    Send("{Blind}{vkE8}")
    ; Jede andere Taste, solange Windows gedrückt ist, zählt nicht als Tippen. A_PriorKey
    ; taugt dafür nicht: Ohne Tastenwiederholung steht dort die Taste vor der Windows-Taste.
    ih := InputHook("V L0")
    ih.KeyOpt("{All}", "N")
    ih.OnKeyDown := (hook, vk, sc) => (vk != 0x5B && vk != 0x5C && vk != 0xE8) ? OV.clean := false : 0
    ih.Start()
    OV.ih := ih
}

OverviewRelease(*) {
    if !OV.down
        return
    clean := OV.clean
    OV.down := 0
    if OV.ih
        OV.ih.Stop(), OV.ih := 0
    if clean && !G.paused && !NAV.active
        SetTimer(OverviewToggle, -1)
}

OverviewToggle(mi := 0) {
    Critical "On"
    if OV.active {
        OverviewClose()
        return
    }
    try OverviewOpen(mi)
    catch Error as e {
        Log("Übersicht: " e.Message " (Zeile " e.Line ")")
        OverviewClose()
    }
}

; Tasten, solange die Übersicht offen ist (mit oder ohne Windows-Taste)
OverviewIsOpen(*) => OV.active

OverviewHotkey(hk) {
    Critical "On"
    if OV.active
        OverviewKey(hk)
}

; Text in der Übersicht: Übersicht schließen, Windows-Suche öffnen und den Text dort
; eintippen. Bis die Suche da ist, sammelt der InputHook weitere Zeichen.
OverviewChar(hook, ch) {
    if !OV.searching {
        if Ord(ch) < 32                        ; Steuerzeichen (Enter, Tab, Esc) erledigen die Hotkeys
            return
        OV.searching := A_TickCount, OV.buf := ch
        OverviewClose(true)
        Send("#s")
        SetTimer(SearchFlush, 50)
        return
    }
    OV.buf .= ch
}

SearchFlush() {
    found := WinActive("ahk_exe SearchHost.exe")
    if !found && A_TickCount - OV.searching < 3000
        return                                 ; Suche noch nicht offen
    SetTimer(SearchFlush, 0)
    if OV.kh
        OV.kh.Stop(), OV.kh := 0
    buf := OV.buf, OV.buf := "", OV.searching := 0
    if found                                   ; nie in ein anderes Fenster tippen
        SendText(buf)
    else
        Log("Windows-Suche ging nicht auf, Eingabe verworfen")
}

; mi: Monitor, auf dem die Übersicht erscheint (0 = aktueller)
; Wie bei niri: Belegte Workspaces bekommen eine große, feste Zeilenhöhe (etwa zwei passen
; auf den Bildschirm), leere nur eine schmale. Jede Zeile füllt ihre Höhe, ein breiter
; Streifen ragt dafür seitlich hinaus und zeigt zunächst den Ausschnitt, der auch auf dem
; Monitor zu sehen ist. Die Auswahl scrollt die Übersicht senkrecht und ihre Zeile
; waagerecht mit. Positionen sind Inhaltskoordinaten: angezeigt wird x - xoff der Zeile
; und y - OV.scroll.
OverviewOpen(mi := 0) {
    mi := mi || CurMonIdx(), m := MONS[mi], sc := m.scale
    mw := m.mr - m.ml, mh := m.mb - m.mt
    pad := Round(20 * sc), labH := Round(24 * sc), rowGap := Round(10 * sc)
    host := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000 -DPIScale")
    host.BackColor := "161616"
    host.SetFont("s11 cC8C8C8", "Segoe UI")
    ; Kopfleiste: Tastenhinweis links, Sitzungs-Schaltflächen rechts (scrollen nicht mit)
    bh := Round(30 * sc), bw := Round(180 * sc), gap := Round(8 * sc)
    hdr := bh + pad                                 ; Inhalt beginnt darunter
    OV.buttons := []
    for b in [["Sitzung laden ▾", "load"], ["Sitzung speichern", "save"]] {
        bx := mw - pad - A_Index * bw - (A_Index - 1) * gap
        host.Add("Text", Format("x{} y{} w{} h{} Center 0x200 Background2A2A2A cFFFFFF", bx, pad, bw, bh), b[1])
        OV.buttons.Push({x: bx, y: pad, w: bw, h: bh, act: b[2]})
    }
    host.Add("Text", Format("x{} y{} w{} h{} 0x200 c8A8A8A", pad, pad, Max(0, mw - 3 * pad - 2 * bw - gap), bh)
        , "Pfeile/Tab wählen · Enter öffnen · F2 umbenennen · Strg+S Sitzung speichern · Esc schließen")
    weights := [], total := 0
    for sp in SPACES
        weights.Push(sp.cols.Length ? 1 : 0.3), total += weights[weights.Length]
    free := mh - 2 * pad - hdr - (SPACES.Length - 1) * rowGap
    unit := Max(free / total, (mh - 2 * pad - hdr - rowGap) / 2.25)   ; Höhe einer belegten Zeile
    fg := DllCall("GetForegroundWindow", "ptr"), items := [], thumbs := [], ctrls := [], rows := []
    sel := 0, top := pad + hdr, availW := mw - 2 * pad
    for row, sp in SPACES {
        rowH := unit * weights[row]
        rw := {top: Round(top), bottom: Round(top + rowH), xoff: 0, maxOff: 0}
        rows.Push(rw)
        sm := SpaceMon(sp), rects := StripRects(sp, sm)
        label := SpaceName(sp) (rects.Length ? "" : "  (leer)")
        c := host.Add("Text", Format("x{} y{} w{} h{} BackgroundTrans{}", pad, Round(top), availW, labH
            , sp = G.active ? " cFFFFFF" : ""), label)
        ctrls.Push({c: c, x: pad, y: Round(top), w: availW, h: labH})
        y0 := Round(top + labH), availH := rowH - labH
        top += rowH + rowGap
        if !rects.Length {                     ; leerer Workspace: Platzhalter zum Auswählen
            hh := Round(availH), w := Round(hh * (sm.mr - sm.ml) / (sm.mb - sm.mt))
            c := host.Add("Text", Format("x{} y{} w{} h{} Background242424", pad, y0, w, hh))
            ctrls.Push({c: c, x: pad, y: y0, w: w, h: hh})
            items.Push({h: 0, sp: sp, row: row, x: pad, y: y0, w: w, hh: hh})
            if sp = G.active && !sel
                sel := items.Length
            continue
        }
        ; Maßstab: Fensterbereich (ohne Ränder oben/unten) füllt die Zeilenhöhe, das
        ; breiteste einzelne Fenster passt noch ganz hinein
        yMin := rects[1].y, yMax := 0, wMax := 0
        for r in rects
            yMin := Min(yMin, r.y), yMax := Max(yMax, r.y + r.h), wMax := Max(wMax, r.w)
        s := Min(availH / (yMax - yMin), availW / wMax)
        rw.maxOff := Max(0, Round(rects.width * s) - availW)
        rw.xoff := Clamp(Round(sp.scrollX * s), 0, rw.maxOff)  ; Ausschnitt wie auf dem Monitor
        for r in rects {
            x := pad + Round(r.x * s), y := y0 + Round((r.y - yMin) * s), w := Round(r.w * s), hh := Round(r.h * s)
            thumb := 0
            if DllCall("dwmapi\DwmRegisterThumbnail", "ptr", host.Hwnd, "ptr", r.hwnd, "ptr*", &thumb) = 0
                thumbs.Push({t: thumb, row: row, x: x, y: y, w: w, h: hh, sw: r.w, sh: r.h})
            items.Push({h: r.hwnd, sp: sp, row: row, x: x, y: y, w: w, hh: hh})
            if r.hwnd = fg
                sel := items.Length
        }
    }
    ; Auswahlrahmen aus vier Balken: Vorschauen liegen immer über den Controls
    OV.frame := []
    loop 4
        OV.frame.Push(host.Add("Text", "x0 y0 w0 h0 Background" OverviewColor()))
    OV.active := true, OV.gui := host, OV.thumbs := thumbs, OV.ctrls := ctrls, OV.items := items
    OV.rows := rows, OV.mon := mi, OV.pad := pad, OV.viewW := mw, OV.viewH := mh
    OV.top := pad + hdr, OV.clip := pad + bh + gap   ; Inhaltsbeginn, darüber wird abgeschnitten
    OV.contentH := Round(top - rowGap + pad), OV.scroll := 0, OV.opened := A_TickCount
    ; Text abfangen (nicht an die App weitergeben) → Windows-Suche. Pfeile, Enter, Tab und
    ; Esc sind Hotkeys und haben Vorrang.
    kh := InputHook("L0")
    kh.OnChar := OverviewChar
    kh.Start()
    OV.kh := kh
    OV.sel := sel || 1
    OverviewPlace()                            ; Vorschauen erstmals platzieren
    OverviewSelect(OV.sel, false)
    HideHighlight()
    host.Show(Format("x{} y{} w{} h{} NoActivate", m.ml, m.mt, mw, mh))
}

; Auswahl setzen und sie senkrecht wie waagerecht in den sichtbaren Bereich scrollen
OverviewSelect(i, animate := true) {
    OV.sel := i
    it := OV.items[i], rw := OV.rows[it.row], pad := OV.pad
    to := OV.scroll
    if rw.top - OV.top < to
        to := rw.top - OV.top
    else if rw.bottom + pad > to + OV.viewH
        to := rw.bottom + pad - OV.viewH
    to := Clamp(to, 0, Max(0, OV.contentH - OV.viewH))
    xto := rw.xoff
    if it.x - xto < pad
        xto := it.x - pad
    else if it.x + it.w - xto > OV.viewW - pad
        xto := it.x + it.w - (OV.viewW - pad)
    xto := Clamp(xto, 0, rw.maxOff)
    if to = OV.scroll && xto = rw.xoff {
        OverviewFrame()
        return
    }
    if !animate || ANIM_MS <= 0 {
        OV.scroll := to, rw.xoff := xto
        OverviewPlace()
        return
    }
    OV.scrollAnim := {start: A_TickCount, from: OV.scroll, to: to, rw: rw, xfrom: rw.xoff, xto: xto}
    SetTimer(OverviewScrollTick, 10)
    OverviewScrollTick()
}

OverviewScrollTick() {
    if !OV.active || !OV.scrollAnim {
        SetTimer(OverviewScrollTick, 0)
        return
    }
    a := OV.scrollAnim, t := Min(1, (A_TickCount - a.start) / ANIM_MS), e := 1 - (1 - t) ** 3
    OV.scroll := Round(a.from + (a.to - a.from) * e)
    a.rw.xoff := Round(a.xfrom + (a.xto - a.xfrom) * e)
    OverviewPlace()
    if t >= 1
        OV.scrollAnim := 0, SetTimer(OverviewScrollTick, 0)
}

; Alles nach OV.scroll und den waagerechten Verschiebungen der Zeilen anordnen. Was unter
; die Kopfleiste geschoben wird, wird an OV.clip abgeschnitten.
OverviewPlace() {
    for e in OV.ctrls {
        y := e.y - OV.scroll, h := e.h
        if y < OV.clip
            h -= OV.clip - y, y := OV.clip
        if h > 0
            e.c.Move(e.x, y, e.w, h)
        else
            e.c.Move(e.x, -10000, e.w, 1)               ; ganz unter der Kopfleiste
    }
    for e in OV.thumbs {
        x := e.x - OV.rows[e.row].xoff, y := e.y - OV.scroll, h := e.h, cut := 0
        if y < OV.clip
            cut := Min(h, OV.clip - y), y := OV.clip, h -= cut
        props := cut ? ThumbProps([x, y, x + e.w, y + h], [0, Round(cut * e.sh / e.h), e.sw, e.sh])
            : ThumbProps([x, y, x + e.w, y + h])
        DllCall("dwmapi\DwmUpdateThumbnailProperties", "ptr", e.t, "ptr", props)
    }
    OverviewFrame()
}

; Auswahlrahmen um das gewählte Element
OverviewFrame() {
    it := OV.items[OV.sel], sc := MONS[OV.mon].scale
    t := Max(2, Round(3 * sc)), d := Max(1, Round(2 * sc))          ; Stärke, Abstand
    l := it.x - OV.rows[it.row].xoff - d - t, tp := it.y - OV.scroll - d - t
    fw := it.w + 2 * (d + t), fh := it.hh + 2 * (d + t)
    OV.frame[1].Move(l, tp, fw, t)
    OV.frame[2].Move(l, tp + fh - t, fw, t)
    OV.frame[3].Move(l, tp, t, fh)
    OV.frame[4].Move(l + fw - t, tp, t, fh)
    for c in OV.frame
        c.Redraw()
}

; Tasten in der Übersicht, mit oder ohne gehaltene Windows-Taste
OverviewKey(hk) {
    switch StrReplace(hk, "#") {
        case "Left": OverviewMove(-1, 0)
        case "Right": OverviewMove(1, 0)
        case "Up", "WheelUp": OverviewMove(0, -1)
        case "Down", "WheelDown": OverviewMove(0, 1)
        case "Tab": OverviewSelect(Mod(OV.sel, OV.items.Length) + 1)
        case "+Tab": OverviewSelect(Mod(OV.sel - 2 + OV.items.Length, OV.items.Length) + 1)
        case "Enter", "NumpadEnter": OverviewApply(OV.sel)
        case "Escape": OverviewClose()
        case "F2":                             ; Workspace der Auswahl umbenennen
            sp := OV.items[OV.sel].sp
            OverviewClose()
            SetTimer(RenameSpace.Bind(sp), -1)
        case "^s": OverviewButton("save")
    }
}

; Schaltflächen der Kopfleiste
OverviewButton(act) {
    mi := OV.mon, b := 0
    for e in OV.buttons
        if e.act = act
            b := e
    OverviewClose()
    if act = "save"
        SetTimer(SaveSessionPrompt, -1)
    else if b {                                 ; Menü direkt unter der Schaltfläche
        x := MONS[mi].ml + b.x, y := MONS[mi].mt + b.y + b.h
        SetTimer(() => (CoordMode("Menu", "Screen"), G.loadMenu.Show(x, y)), -1)
    }
}

; dx: vorheriges/nächstes Element derselben Zeile, dy: Zeile wechseln (das Element, das
; auf dem Bildschirm am nächsten darunter/darüber liegt)
OverviewMove(dx, dy) {
    cur := OV.items[OV.sel]
    if dx {
        j := OV.sel + dx
        if j >= 1 && j <= OV.items.Length && OV.items[j].row = cur.row
            OverviewSelect(j)
        return
    }
    row := cur.row + dy, best := 0, bestD := 0
    cx := cur.x - OV.rows[cur.row].xoff + cur.w / 2
    for i, it in OV.items {
        if it.row != row
            continue
        dist := Abs(it.x - OV.rows[row].xoff + it.w / 2 - cx)
        if !best || dist < bestD
            best := i, bestD := dist
    }
    if best
        OverviewSelect(best)
}

; Nur mit /debug: wParam 0 = öffnen, 1–4 = Pfeil links/rechts/oben/unten, 5 = Auswahl anwenden
DebugOverview(wParam, *) {
    if !DEBUG
        return
    SetTimer(() => (Critical("On")
        , !wParam ? OverviewOpen() : wParam = 5 ? OverviewApply(OV.sel)
        : OV.active ? OverviewKey(["Left", "Right", "Up", "Down"][wParam]) : 0), -1)
    return 0
}

OverviewClick(x, y) {
    for b in OV.buttons
        if x >= b.x && x < b.x + b.w && y >= b.y && y < b.y + b.h {
            SetTimer(OverviewButton.Bind(b.act), -1)
            return
        }
    if y < OV.clip                             ; Kopfleiste
        return
    y += OV.scroll                             ; Bildschirm → Inhaltskoordinaten
    for i, it in OV.items {
        cx := x + OV.rows[it.row].xoff
        if cx >= it.x && cx < it.x + it.w && y >= it.y && y < it.y + it.hh {
            SetTimer(OverviewApply.Bind(i), -1)
            return
        }
    }
}

OverviewApply(i) {
    Critical "On"
    if !OV.active || i > OV.items.Length
        return
    it := OV.items[i], mi := OV.mon
    OverviewClose()
    try {
        if it.h
            RevealWindow(it.h)
        else {
            cur := MONS[mi].space
            ShowSpace(it.sp, mi, cur && cur != it.sp ? WsDir(cur, it.sp) : 0)
            FocusSpace(it.sp)
            Osd(SpaceName(it.sp), mi)
        }
    } catch Error as e
        Log("Übersicht: " e.Message " (Zeile " e.Line ")")
    AfterChange()
}

; keepKeys: Texteingabe weiter abfangen (Übergang zur Windows-Suche)
OverviewClose(keepKeys := false) {
    if !keepKeys && OV.kh
        OV.kh.Stop(), OV.kh := 0
    if !OV.active
        return
    OV.active := false, OV.scrollAnim := 0
    SetTimer(OverviewScrollTick, 0)
    for e in OV.thumbs
        DllCall("dwmapi\DwmUnregisterThumbnail", "ptr", e.t)
    OV.thumbs := [], OV.ctrls := [], OV.frame := []
    try OV.gui.Destroy()
    OV.gui := 0
    UpdateHighlight()
}

;=========================== Navigation (Super halten) =======================
StartNav(kind) {
    NAV.active := true, NAV.kind := kind
    SetTimer(NavCheck, 30)
}

NavCheck() {
    if GetKeyState("LWin", "P") || GetKeyState("RWin", "P") || GetKeyState("Alt", "P")
        return
    Critical "On"
    SetTimer(NavCheck, 0)
    try EndNav()
    AfterChange()
}

EndNav() {
    NAV.active := false
    sp := CurSpace()
    if TAKEN.Length {                      ; Super+T: aufgenommene Fenster ablegen
        for h in TAKEN
            if DllCall("IsWindow", "ptr", h) {
                fr := FrameRect(h)
                InsertWin(sp, h, "right", fr.r - fr.l)
            }
        TAKEN.Length := 0
        EnsureVisible(sp)
        Layout(sp, true)
        FocusSpace(sp)
    }
    MoveToFront(SPACE_MRU, sp)
    h := DllCall("GetForegroundWindow", "ptr")
    if WINS.Has(h)
        MoveToFront(WIN_MRU, h)
    else if IndexOf(G.scratch, h)
        MoveToFront(G.scratch, h)
}

;================================ Aktionen ===================================
MakeHandler(fn) => (*) => RunAction(fn)

RunAction(fn) {
    Critical "On"
    OV.clean := false                      ; Windows+Kürzel zählt nicht als Tippen auf Windows
    if G.paused
        return
    if OV.active {                         ; Übersicht offen: Pfeile wählen, Esc bricht ab
        OverviewKey(A_ThisHotkey)
        return
    }
    t0 := QPC()
    try {
        fn()
        if DEBUG
            Log(Format("{} {:.1f} ms", A_ThisHotkey, QPC() - t0))
    }
    catch Error as e {
        Log(A_ThisHotkey ": " e.Message " (Zeile " e.Line ")")
        Osd("Fehler: " e.Message)
    }
    AfterChange()
}

; Nach jeder Änderung: leere Workspaces aufräumen, Anzeige und Hervorhebung nachziehen
AfterChange() {
    TidySpaces()
    UpdateIndicator()
    UpdateHighlight()
    MarkDirty()
}

SwitchCol(d) {
    sp := CurSpace()
    if !sp.cols.Length
        return
    sp.focusCol := Clamp(sp.focusCol + d, 1, sp.cols.Length)
    Refocus(sp)
}

SwitchRow(d) {
    sp := CurSpace()
    if !(col := FocusedCol(sp))
        return
    col.focusRow := Clamp(col.focusRow + d, 1, col.wins.Length)
    Refocus(sp)
}

; Super+. / Super+, : nächstes/vorheriges Fenster in Lesereihenfolge
SwitchLinear(d) {
    sp := CurSpace()
    if !(col := FocusedCol(sp))
        return
    if d > 0 {
        if col.focusRow < col.wins.Length
            col.focusRow += 1
        else if sp.focusCol < sp.cols.Length
            sp.focusCol += 1, sp.cols[sp.focusCol].focusRow := 1
    } else {
        if col.focusRow > 1
            col.focusRow -= 1
        else if sp.focusCol > 1
            sp.focusCol -= 1, sp.cols[sp.focusCol].focusRow := sp.cols[sp.focusCol].wins.Length
    }
    Refocus(sp)
}

SwitchEdge(last) {
    sp := CurSpace()
    if !sp.cols.Length
        return
    sp.focusCol := last ? sp.cols.Length : 1
    Refocus(sp)
}

MoveCol(d) {
    sp := CurSpace(), i := sp.focusCol, j := i + d
    if !i || j < 1 || j > sp.cols.Length
        return
    tmp := sp.cols[i], sp.cols[i] := sp.cols[j], sp.cols[j] := tmp
    o := sp.cols[i].ord, sp.cols[i].ord := sp.cols[j].ord, sp.cols[j].ord := o
    sp.focusCol := j
    Refocus(sp)
}

MoveRow(d) {
    sp := CurSpace()
    if !(col := FocusedCol(sp))
        return
    i := col.focusRow, j := i + d
    if j < 1 || j > col.wins.Length
        return
    tmp := col.wins[i], col.wins[i] := col.wins[j], col.wins[j] := tmp
    tmp := col.fracs[i], col.fracs[i] := col.fracs[j], col.fracs[j] := tmp
    col.focusRow := j
    Refocus(sp)
}

; Super+I: oberstes Fenster der rechten Spalte unten in die aktive Spalte holen
SlurpIn() {
    sp := CurSpace(), i := sp.focusCol
    if !i || i >= sp.cols.Length
        return
    col := sp.cols[i], nxt := sp.cols[i + 1]
    col.wins.Push(nxt.wins.RemoveAt(1))
    EqualFracs(col)
    if nxt.wins.Length {
        EqualFracs(nxt)
        nxt.focusRow := Clamp(nxt.focusRow, 1, nxt.wins.Length)
    } else
        sp.cols.RemoveAt(i + 1)
    Refocus(sp)
}

; Super+O: unterstes Fenster als eigene Spalte rechts ausstoßen
; Super+Shift+O: aktives Fenster ausstoßen
BarfOut(active) {
    sp := CurSpace()
    if !(col := FocusedCol(sp)) || col.wins.Length < 2
        return
    h := col.wins.RemoveAt(active ? col.focusRow : col.wins.Length)
    EqualFracs(col)
    col.focusRow := Clamp(col.focusRow, 1, col.wins.Length)
    sp.cols.InsertAt(sp.focusCol + 1, Column(h, col.width))
    AssignOrd(sp, sp.focusCol + 1)
    if active
        sp.focusCol += 1
    Refocus(sp)
}

TakeWindow() {
    sp := CurSpace()
    if !(h := FocusedHwnd(sp))
        return
    if !NAV.active
        StartNav("take")
    RemoveWin(h)
    TAKEN.Push(h)
    try HideWin(h)
    EnsureVisible(sp)
    Layout(sp, true)
    FocusSpace(sp)
    Osd(TAKEN.Length " Fenster aufgenommen – Super loslassen zum Ablegen")
}

CycleWidth(dir) {
    sp := CurSpace()
    if !(col := FocusedCol(sp))
        return
    m := SpaceMon(sp), cur := ColWidth(col, m), u := UsableW(m), ws := []
    for s in WIDTH_STEPS
        ws.Push(Round(StepWidth(s, m) * u))
    col.width := WidthFrac(NextStep(ws, cur, dir, 5), m)
    col.full := false, col.prevWidth := 0
    Refocus(sp)
}

CycleHeight(dir) {
    sp := CurSpace()
    if !(col := FocusedCol(sp)) || col.wins.Length < 2
        return
    SetFrac(col, col.focusRow, NextStep(HEIGHT_STEPS, col.fracs[col.focusRow], dir, 0.01))
    Refocus(sp)
}

NextStep(steps, cur, dir, tol) {
    if dir > 0 {
        for s in steps
            if s > cur + tol
                return s
        return steps[1]
    }
    i := steps.Length
    while i >= 1 {
        if steps[i] < cur - tol
            return steps[i]
        i--
    }
    return steps[steps.Length]
}

; Setzt den Höhenanteil eines Fensters, die anderen teilen sich den Rest
SetFrac(col, r, f) {
    n := col.wins.Length, f := Clamp(f, 0.1, 0.9), rest := 0
    for i, x in col.fracs
        if i != r
            rest += x
    for i, x in col.fracs
        if i != r
            col.fracs[i] := rest > 0 ? (1 - f) * x / rest : (1 - f) / (n - 1)
    col.fracs[r] := f
}

ResizeW(d) {
    sp := CurSpace()
    if !(col := FocusedCol(sp))
        return
    m := SpaceMon(sp)
    col.width := WidthFrac(ColWidth(col, m) + d * Px(RESIZE_STEP, m), m)
    col.full := false
    Refocus(sp)
}

ResizeH(d) {
    sp := CurSpace()
    if !(col := FocusedCol(sp)) || col.wins.Length < 2
        return
    SetFrac(col, col.focusRow, col.fracs[col.focusRow] + d * 0.05)
    Refocus(sp)
}

ToggleMaxWidth() {
    sp := CurSpace()
    if !(col := FocusedCol(sp))
        return
    if col.prevWidth
        col.width := col.prevWidth, col.prevWidth := 0
    else
        col.prevWidth := col.width, col.width := 1
    col.full := false
    Refocus(sp)
}

ToggleFullscreen() {
    sp := CurSpace()
    if !(col := FocusedCol(sp))
        return
    col.full := !col.full
    Refocus(sp)
}

Drift(d) {
    sp := CurSpace()
    sp.scrollX += d * Px(DRIFT_STEP, SpaceMon(sp))
    Layout(sp, true)
}

ToggleFocusMode() {
    G.focusCenter := !G.focusCenter
    Osd("Fokusmodus: " (G.focusCenter ? "zentriert" : "Standard"))
    Refocus(CurSpace())
}

CycleOpenPosition() {
    i := IndexOf(OPEN_POSITIONS, G.openPos)
    G.openPos := OPEN_POSITIONS[Mod(i, OPEN_POSITIONS.Length) + 1]
    names := Map("right", "rechts", "left", "links", "start", "Anfang", "end", "Ende", "down", "unten")
    Osd("Neue Fenster öffnen: " names[G.openPos])
}

NewWindow() {
    h := DllCall("GetForegroundWindow", "ptr")
    if !WINS.Has(h) && !IndexOf(G.scratch, h)
        return
    name := WinGetProcessName(h), path := WinGetProcessPath(h)
    if name = "explorer.exe" {
        Run("explorer.exe")
        return
    }
    if name = "ApplicationFrameHost.exe" || InStr(path, "\WindowsApps\") {
        Send("^n")                         ; Store-Apps lassen sich nicht direkt starten
        return
    }
    try Run('"' path '" ' (NEW_WINDOW_ARGS.Has(name) ? NEW_WINDOW_ARGS[name] : ""))
    catch
        Send("^n")
}

CloseWindow() {
    h := DllCall("GetForegroundWindow", "ptr")
    if WINS.Has(h) || IndexOf(G.scratch, h)
        WinClose(h)
}

;------------------------------- Scratch -------------------------------------
LiveScratch() {
    i := G.scratch.Length
    while i >= 1 {
        if !DllCall("IsWindow", "ptr", G.scratch[i])
            G.scratch.RemoveAt(i)
        i--
    }
    return G.scratch
}

; Super+Strg+Esc: aktives Fenster zwischen Kacheln und Scratch-Layer verschieben
ToggleScratch() {
    if !(h := DllCall("GetForegroundWindow", "ptr"))
        return
    if IndexOf(G.scratch, h) {
        RemoveVal(G.scratch, h)
        Manage(h, true)
        return
    }
    if !WINS.Has(h)
        return
    sp := WINS[h]
    RemoveWin(h)
    RemoveVal(WIN_MRU, h)
    MapDel(G.placed, h)
    UncloakWin(h), PeekHide(h)
    G.scratch.InsertAt(1, h)
    m := SpaceMon(sp), w := Round((m.r - m.l) * 0.6), hh := Round((m.b - m.t) * 0.7)
    PlaceWindow(h, m.l + (m.r - m.l - w) // 2, m.t + (m.b - m.t - hh) // 2, w, hh)
    EnsureVisible(sp)
    Layout(sp, true)
    WinActivate(h)
}

; Super+Esc: zuletzt benutztes Scratch-Fenster ein-/ausblenden
ToggleScratchWindow() {
    list := LiveScratch()
    if !list.Length
        return
    h := list[1]
    if DllCall("GetForegroundWindow", "ptr") = h && WinGetMinMax(h) != -1 {
        WinMinimize(h)
        FocusSpace(CurSpace())
    } else {
        if WinGetMinMax(h) = -1
            WinRestore(h)
        WinActivate(h)
    }
}

; Super+Shift+Esc: ganzen Scratch-Layer ein-/ausblenden
ToggleScratchLayer() {
    list := LiveScratch()
    if !list.Length
        return
    visible := false
    for h in list
        if WinGetMinMax(h) != -1
            visible := true
    if visible {
        for h in list
            WinMinimize(h)
        FocusSpace(CurSpace())
        return
    }
    i := list.Length
    while i >= 1 {
        WinRestore(list[i])
        WinActivate(list[i])
        i--
    }
}

;------------------------------- Alt-Tab -------------------------------------
LiveAltTab(dir, scratch := false) {
    kind := scratch ? "tab-scratch" : "tab"
    if !(NAV.active && NAV.kind = kind) {
        StartNav(kind)
        NAV.list := []
        for h in (scratch ? G.scratch : WIN_MRU)
            if DllCall("IsWindow", "ptr", h)
                NAV.list.Push(h)
        if a := IndexOf(NAV.list, DllCall("GetForegroundWindow", "ptr"))
            NAV.list.InsertAt(1, NAV.list.RemoveAt(a))
        NAV.idx := 1
    }
    n := NAV.list.Length
    if !n
        return
    NAV.idx := Mod(NAV.idx - 1 + dir + n, n) + 1
    h := NAV.list[NAV.idx]
    if scratch {
        if WinGetMinMax(h) = -1
            WinRestore(h)
        WinActivate(h)
    } else
        RevealWindow(h)
}

;------------------------------ Workspaces -----------------------------------
SwitchWorkspace(d) {
    sp := CurSpace(), i := sp.idx + d
    if i < 1 || i > SPACES.Length
        return
    ShowSpace(SPACES[i], sp.mon, d)
    FocusSpace(SPACES[i])
    Osd(SpaceName(SPACES[i]))
}

MoveWorkspace(d) {
    sp := CurSpace(), i := sp.idx + d
    if i < 1 || i > SPACES.Length || !(h := FocusedHwnd(sp))
        return
    MoveWinToSpace(h, SPACES[i], sp.mon)
    Osd(SpaceName(SPACES[i]))
}

; Nimmt Fenster h in Workspace t mit (t wird auf monIdx angezeigt)
MoveWinToSpace(h, t, monIdx) {
    sp := WINS[h]
    here := G.planOf.Get(h, 0)              ; aktuelle Position: das Fenster gleitet von hier
    loc := RemoveWin(h)
    InsertWin(t, h, "right", loc.col.width)
    if here
        G.planOf[h] := here
    EnsureVisible(sp)
    if t.mon {                               ; Ziel auf anderem Monitor sichtbar → tauschen
        ShowSpace(t, monIdx)
        Layout(sp)
    } else
        ShowSpace(t, monIdx, WsDir(sp, t), h)
    FocusSpace(t)
}

; Super+^ : durch die zuletzt benutzten Workspaces blättern (solange Super gehalten)
; Super+Strg+^ : dabei das aktive Fenster mitnehmen
PrevWorkspace(dir, take := false) {
    kind := take ? "ws-take" : "ws"
    if !(NAV.active && NAV.kind = kind) {
        sp := CurSpace()
        StartNav(kind)
        NAV.list := SPACE_MRU.Clone()
        MoveToFront(NAV.list, sp)
        NAV.idx := 1, NAV.mon := sp.mon
        NAV.hwnd := take ? FocusedHwnd(sp) : 0
    }
    n := NAV.list.Length
    if n < 2
        return
    NAV.idx := Mod(NAV.idx - 1 + dir + n, n) + 1
    t := NAV.list[NAV.idx]
    if NAV.hwnd && WINS.Has(NAV.hwnd)
        MoveWinToSpace(NAV.hwnd, t, NAV.mon)
    else {
        cur := MONS[NAV.mon].space
        ShowSpace(t, NAV.mon, cur ? WsDir(cur, t) : 0)
        FocusSpace(t)
    }
    Osd(SpaceName(t))
}

;------------------------------- Monitore ------------------------------------
SwitchMonitor(dir) {
    sp := CurSpace()
    if !(ni := NeighborMon(sp.mon, dir))
        return
    t := MONS[ni].space
    FocusSpace(t)
    WarpTo(ni)
    if !t.cols.Length
        Osd(SpaceName(t), ni)
}

MoveMonitor(dir) {
    sp := CurSpace()
    if !(h := FocusedHwnd(sp)) || !(ni := NeighborMon(sp.mon, dir))
        return
    t := MONS[ni].space
    loc := RemoveWin(h)
    InsertWin(t, h, "right", loc.col.width)
    EnsureVisible(sp)
    Layout(sp, true)
    EnsureVisible(t)
    Layout(t, true)
    FocusSpace(t)
    WarpTo(ni)
}

; Super+Alt+Pfeil: Workspaces zweier Monitore tauschen
SwapMonitor(dir) {
    sp := CurSpace()
    if !(ni := NeighborMon(sp.mon, dir))
        return
    ShowSpace(sp, ni)
    FocusSpace(sp)
    WarpTo(ni)
}

; Strg+Alt+Shift+Pfeil: aktiven Workspace auf anderen Monitor schieben
MoveSpaceMonitor(dir) {
    sp := CurSpace(), from := sp.mon
    if !(ni := NeighborMon(from, dir))
        return
    ShowSpace(sp, ni)
    if f := FreeSpace()
        ShowSpace(f, from)
    FocusSpace(sp)
    WarpTo(ni)
}

;=============================== Sonstiges ===================================
Osd(text, monIdx := 0) {
    if !SHOW_OSD || !MONS.Length
        return
    if !G.osd {
        G.osd := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale")
        G.osd.BackColor := "1E1E1E"
        G.osd.MarginX := 24, G.osd.MarginY := 14
        G.osd.SetFont("s14 cWhite", "Segoe UI")
        G.osdText := G.osd.Add("Text", "w520 Center")
    }
    G.osdText.Value := text
    m := MONS[Clamp(monIdx || CurMonIdx(), 1, MONS.Length)]
    G.osd.Show(Format("NoActivate AutoSize x{} y{}", (m.l + m.r) // 2 - 284, m.t + 60))
    WinSetTransparent(225, G.osd)
    SetTimer(HideOsd, -1100)
}

HideOsd() => G.osd.Hide()

; Macht alle versteckten Fenster wieder sichtbar und holt die außerhalb der Monitore
; auf den ersten Monitor zurück
RescueAll() {
    UncloakAll()
    if !MONS.Length
        return
    m := MONS[1], k := 0, hs := []
    for h, sp in WINS
        hs.Push(h)
    for h in TAKEN
        hs.Push(h)
    G.placed.Clear()
    for h in hs {
        try {
            r := FrameRect(h)
            if MonAt((r.l + r.r) // 2, (r.t + r.b) // 2)
                continue
            w := Min(r.r - r.l, m.r - m.l - 200), hh := Min(r.b - r.t, m.b - m.t - 200)
            PlaceWindow(h, m.l + 60 + 40 * k, m.t + 60 + 40 * k, w, hh)
            k := Mod(k + 1, 10)
        }
    }
}

TogglePause(*) {
    if G.paused {
        Reload()
        return
    }
    SaveLayout()
    OverviewClose()
    IndicatorClear()
    G.paused := true
    Suspend(true)
    HideHighlight()
    RescueAll()
    Osd("PaperWM pausiert")
}

Cleanup(*) {
    for hk in G.hooks
        DllCall("UnhookWinEvent", "ptr", hk)
    if !G.paused
        SaveLayout()
    OverviewClose()
    IndicatorClear()
    HideHighlight()
    RescueAll()
}

;================================= Debug =====================================
; Millisekunden mit Nachkommastellen (für Zeitmessungen)
QPC() {
    static f := 0
    if !f
        DllCall("QueryPerformanceFrequency", "int64*", &f)
    DllCall("QueryPerformanceCounter", "int64*", &c := 0)
    return c * 1000 / f
}

LogError(e, mode) {
    Log(Format("FEHLER: {} | {} | Zeile {} | {}", e.Message, e.What, e.Line, e.Extra))
    return 1
}

Log(msg) {
    try FileAppend(FormatTime(, "HH:mm:ss") "." A_MSec " " msg "`n", A_ScriptDir "\PaperWM.log", "UTF-8")
}

DumpState() {
    s := "active=" (G.active ? G.active.idx : 0) " openPos=" G.openPos " fg=" WinTitleSafe(DllCall("GetForegroundWindow", "ptr"))
        . " highlight=" (HL.key = "" ? "-" : HL.key) "`n"
    for i, m in MONS
        s .= Format("MON{} work={},{}-{},{} space={}`n", i, m.l, m.t, m.r, m.b, m.space ? m.space.idx : 0)
    for sp in SPACES {
        s .= Format("WS{} mon={} scrollX={} focusCol={}`n", sp.idx, sp.mon, sp.scrollX, sp.focusCol)
        for ci, col in sp.cols {
            s .= Format("  col{} w={} full={} focusRow={} ord={} :", ci, col.width, col.full, col.focusRow, col.ord)
            for h in col.wins {
                r := FrameRect(h)
                s .= Format(" [{} @{},{} {}x{}]", WinTitleSafe(h), r.l, r.t, r.r - r.l, r.b - r.t)
            }
            s .= "`n"
        }
    }
    s .= "scratch:"
    for h in G.scratch
        s .= " [" WinTitleSafe(h) "]"
    s .= "`nminimized:"
    for h, z in G.minimized
        s .= Format(" [{} WS{} ord={}]", WinTitleSafe(h), z.sp.idx, z.ord)
    try FileDelete(A_ScriptDir "\PaperWM.state.txt")
    FileAppend(s "`n", A_ScriptDir "\PaperWM.state.txt", "UTF-8")
}

WinTitleSafe(h) {
    try return SubStr(WinGetTitle(h), 1, 30)
    return "?" h
}

;================================ Helfer =====================================
Clamp(v, lo, hi) => Max(lo, Min(hi, v))

MapDel(m, k) => m.Has(k) ? m.Delete(k) : 0

IndexOf(arr, v) {
    for i, x in arr
        if x = v
            return i
    return 0
}

RemoveVal(arr, v) {
    if i := IndexOf(arr, v)
        arr.RemoveAt(i)
}

MoveToFront(arr, v) {
    RemoveVal(arr, v)
    arr.InsertAt(1, v)
}

InList(s, arr) {
    for x in arr
        if x = s
            return true
    return false
}

SortByX(list) {
    i := 2
    while i <= list.Length {
        j := i
        while j > 1 && list[j - 1].x > list[j].x {
            tmp := list[j - 1], list[j - 1] := list[j], list[j] := tmp
            j--
        }
        i++
    }
}
