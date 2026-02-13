#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# KDIALOG WRAPPER FÜR WINAPPS
# Ersetzt die textbasierten 'dialog'-Funktionen durch grafische KDE-Dialoge.
# -----------------------------------------------------------------------------

# Prüfung, ob kdialog installiert ist
if ! command -v kdialog &> /dev/null; then
    echo "Fehler: 'kdialog' ist nicht installiert."
    echo "Bitte installiere es (z.B. 'sudo apt install kdialog' oder 'sudo pacman -S kdialog')."
    exit 1
fi

# Setze einen globalen Titel für alle Fenster
APP_TITLE="WinApps Installer"

# -----------------------------------------------------------------------------
# Funktion: menu
# Beschreibung: Zeigt ein Auswahlmenü (Single Selection)
# Original Aufruf: menu "Text" H W MH "Tag1" "Item1" "Tag2" "Item2" ...
# -----------------------------------------------------------------------------
function menu() {
    local text="$1"
    
    # Entferne die Dimensionen (Height, Width, MenuHeight), die 'dialog' braucht,
    # aber 'kdialog' verwirren würden. Wir shiften 4x (Text + 3 Zahlen).
    shift 4
    
    # kdialog --menu Syntax: --menu "Text" "Tag1" "Item1" ...
    # Das Ergebnis wird direkt auf stdout ausgegeben, was setup.sh erwartet.
    kdialog --title "$APP_TITLE" --menu "$text" "$@"
    
    # Den Exit-Code von kdialog (0=OK, 1=Cancel) durchreichen
    return $?
}

# -----------------------------------------------------------------------------
# Funktion: checklist
# Beschreibung: Zeigt eine Checkliste (Multi Selection)
# Original Aufruf: checklist "Text" H W LH "Tag1" "Item1" "Status1" ...
# -----------------------------------------------------------------------------
function checklist() {
    local text="$1"
    
    # Entferne wieder Text + 3 Dimensions-Argumente
    shift 4
    
    # kdialog gibt Listen in Anführungszeichen zurück (z.B. "Item1" "Item2").
    # setup.sh erwartet die Items oft als einfache Liste.
    # Wir nutzen --separate-output, um sicherzugehen, dass wir saubere Zeilen bekommen,
    # oder verlassen uns auf das Standardverhalten, je nachdem wie setup.sh es parst.
    # Standard 'dialog' gibt: "tag1" "tag2" (quoted) auf stderr.
    # 'kdialog' gibt: "tag1" "tag2" (quoted) auf stdout. Das passt also!
    
    kdialog --title "$APP_TITLE" --checklist "$text" "$@"
    
    return $?
}

# -----------------------------------------------------------------------------
# Funktion: input
# Beschreibung: Eingabefeld für Text
# Original Aufruf: input "Text" H W "DefaultValue"
# -----------------------------------------------------------------------------
function input() {
    local text="$1"
    local default_value="$4" # Das 4. Argument ist der Standardwert bei dialog
    
    # Wir brauchen H und W ($2, $3) nicht.
    
    kdialog --title "$APP_TITLE" --inputbox "$text" "$default_value"
    
    return $?
}

# -----------------------------------------------------------------------------
# Funktion: msgbox
# Beschreibung: Zeigt eine einfache Nachricht mit OK-Button
# Original Aufruf: msgbox "Text" H W
# -----------------------------------------------------------------------------
function msgbox() {
    local text="$1"
    
    # Entferne Dimensionen
    # Achtung: Manchmal rufen Skripte msgbox nur mit Text auf. 
    # Wir prüfen kurz, ob $2 eine Zahl ist, um sicher zu gehen, oder ignorieren es einfach.
    # Da kdialog --msgbox keine weiteren Args außer Text nimmt, ist es sicher,
    # nur $1 zu verwenden.
    
    kdialog --title "$APP_TITLE" --msgbox "$text"
    
    return $?
}

# -----------------------------------------------------------------------------
# Funktion: yesno
# Beschreibung: Ja/Nein Frage
# Original Aufruf: yesno "Text" H W
# -----------------------------------------------------------------------------
function yesno() {
    local text="$1"
    
    # Dimensionen ignorieren
    
    kdialog --title "$APP_TITLE" --yesno "$text"
    
    return $?
}

# -----------------------------------------------------------------------------
# Funktion: infobox
# Beschreibung: Zeigt Info ohne Button (bei kdialog nutzen wir msgbox oder passivepopup)
# Original Aufruf: infobox "Text" H W
# -----------------------------------------------------------------------------
function infobox() {
    local text="$1"
    
    # kdialog hat keine direkte "infobox", die das Skript weiterlaufen lässt 
    # wie dialog (das nur kurz anzeigt).
    # --passivepopup ist eine gute Alternative für kurze Infos.
    
    kdialog --title "$APP_TITLE" --passivepopup "$text" 3
}