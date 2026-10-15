; Notfall: macht alle von PaperWM unsichtbar geschalteten Fenster wieder sichtbar und holt
; alle Fenster, die außerhalb jedes Monitors liegen (z. B. nach einem Absturz von
; PaperWM.ahk), auf den Hauptmonitor zurück.
#Requires AutoHotkey v2.0
DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

; Shell-Schnittstelle zum Sichtbarschalten (wie in PaperWM.ahk, siehe CloakInit)
views := 0
try {
    shell := ComObject("{C2F03A33-21F5-47FA-B4BB-156362A2F239}", "{6D5140C1-7436-11CE-8034-00AA006009FA}")
    iid := Buffer(16)
    DllCall("ole32\CLSIDFromString", "str", "{1841C6D7-4F9D-42C0-AF41-8747538F10E5}", "ptr", iid)
    ComCall(3, shell, "ptr", iid, "ptr", iid, "ptr*", &views)
}

MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
k := 0, n := 0, c := 0, u := 0
for h in WinGetList() {
    try {
        if DllCall("GetPropW", "ptr", h, "str", "PaperWM.Cloaked", "ptr") {
            view := 0
            try {
                ComCall(6, views, "ptr", h, "ptr*", &view)             ; GetViewForHwnd
                ComCall(12, view, "int", 1, "int", 0)                   ; SetCloak: sichtbar
                u++
            }
            if view
                ObjRelease(view)
            DllCall("RemovePropW", "ptr", h, "str", "PaperWM.Cloaked", "ptr")
        }
        if !DllCall("IsWindowVisible", "ptr", h) || WinGetTitle(h) = ""
            continue
        ; Von älteren Versionen zugeschnittene Fenster (einfache Rechteck-Region) wieder ganz
        ; zeigen. Komplexe Regionen gehören der App selbst und bleiben unangetastet.
        rgn := DllCall("CreateRectRgn", "int", 0, "int", 0, "int", 0, "int", 0, "ptr")
        if DllCall("GetWindowRgn", "ptr", h, "ptr", rgn) = 2 {          ; SIMPLEREGION
            DllCall("SetWindowRgn", "ptr", h, "ptr", 0, "int", 1)
            c++
        }
        DllCall("DeleteObject", "ptr", rgn)
        ; Von älteren Versionen abgeschalteten Mica-Hintergrund wiederherstellen
        if p := DllCall("GetPropW", "ptr", h, "str", "PaperWM.Backdrop", "ptr") {
            v := p - 1
            DllCall("dwmapi\DwmSetWindowAttribute", "ptr", h, "uint", 38, "int*", v, "uint", 4)
            DllCall("RemovePropW", "ptr", h, "str", "PaperWM.Backdrop", "ptr")
            dflt := 0xFFFFFFFF                                          ; Fensterrand wieder Standard
            DllCall("dwmapi\DwmSetWindowAttribute", "ptr", h, "uint", 34, "uint*", dflt, "uint", 4)
        }
        if WinGetMinMax(h) = -1
            continue
        WinGetPos(&x, &y, &w, &hh, h)
        cx := x + w // 2, cy := y + hh // 2
        onScreen := false
        loop MonitorGetCount() {
            MonitorGet(A_Index, &ml, &mt, &mr, &mb)
            if cx >= ml && cx < mr && cy >= mt && cy < mb
                onScreen := true
        }
        if onScreen
            continue
        WinMove(l + 60 + 40 * k, t + 60 + 40 * k, Min(w, r - l - 200), Min(hh, b - t - 200), h)
        k := Mod(k + 1, 10), n++
    }
}
if views
    ObjRelease(views)
MsgBox(u " Fenster sichtbar gemacht, " n " zurückgeholt, " c " Zuschnitte entfernt.", "PaperWM Rescue", "T3")
