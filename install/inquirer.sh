#!/usr/bin/env bash

### GLOBAL CONSTANTS ###
declare -r ANSI_LIGHT_BLUE="\033[1;94m"
declare -r ANSI_LIGHT_GREEN="\033[92m"
declare -r ANSI_CLEAR_TEXT="\033[0m"

### FUNCTIONS ###
function inqMenu() {
    local DIALOG_TEXT="$1"
    local -n INPUT_OPTIONS="$2"
    local -n RETURN_STRING="$3"

    # Create options for kdialog
    local OPTIONS=()
    local i=1
    for OPTION in "${INPUT_OPTIONS[@]}"; do
        OPTIONS+=("$i" "$OPTION")
        ((i++))
    done

    # Show menu and get selection
    local SELECTED_OPTION=$(kdialog --menu "$DIALOG_TEXT" "${OPTIONS[@]}" --title "Menu" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Abgebrochen"
        exit 0
    fi

    # Set return value (subtract 1 because array is 0-based)
    RETURN_STRING="${INPUT_OPTIONS[$((SELECTED_OPTION - 1))]}"

    # Print selection
    echo -e "${ANSI_LIGHT_GREEN}Q) ${ANSI_CLEAR_TEXT}${ANSI_LIGHT_BLUE}${DIALOG_TEXT}${ANSI_CLEAR_TEXT} --> ${ANSI_LIGHT_GREEN}${RETURN_STRING}${ANSI_CLEAR_TEXT}"
}

function inqChkBx() {
    local DIALOG_TEXT="$1"
    local -n INPUT_OPTIONS="$2"
    local -n RETURN_ARRAY="$3"

    # Create options for kdialog
    local OPTIONS=()
    for OPTION in "${INPUT_OPTIONS[@]}"; do
        OPTIONS+=("$OPTION" "$OPTION" "off")
    done

    # Show checklist and get selections
    local SELECTED_OPTIONS=$(kdialog --checklist "$DIALOG_TEXT" "${OPTIONS[@]}" --title "Checkbox" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Abgebrochen"
        exit 0
    fi

    # Convert selected options to array
    local IFS=$'\n'
    RETURN_ARRAY=($(echo "$SELECTED_OPTIONS" | sed 's/^"//;s/"$//'))
}