#!/usr/bin/env bash

# Funktion: inqMenu
# Erwartet: "Text" 0 0 0 "Tag1" "Item1" "Tag2" "Item2"...
# Gibt zurück: Den gewählten Tag (z.B. "Tag1")
function inqMenu() {
    local TEXT="$1"
    # Entferne die ersten 4 Argumente (Text + 0 0 0)
    shift 4
    # kdialog gibt den gewählten Tag direkt nach stdout aus
    kdialog --title "WinApps Setup" --menu "$TEXT" "$@"
}

# Funktion: inqChkBx
# Erwartet: "Text" 0 0 0 "Tag1" "Item1" "Status" "Tag2" "Item2" "Status"...
# Gibt zurück: Die gewählten Tags, durch Leerzeichen getrennt (z.B. "Tag1 Tag3")
function inqChkBx() {
    local TEXT="$1"
    # Entferne die ersten 4 Argumente (Text + 0 0 0)
    shift 4
    # kdialog gibt die gewählten Tags nach stdout aus
    kdialog --title "WinApps Setup" --checklist "$TEXT" "$@"
}