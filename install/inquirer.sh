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

    local OPTIONS_STR=""
    for OPTION in "${INPUT_OPTIONS[@]}"; do
        OPTIONS_STR+="$OPTION \"$OPTION\" "
    done

    RETURN_STRING=$(kdialog --menu "$DIALOG_TEXT" $OPTIONS_STR --title "Menu" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Abgebrochen"
        exit 0
    fi

    echo -e "${ANSI_LIGHT_GREEN}Q) ${ANSI_CLEAR_TEXT}${ANSI_LIGHT_BLUE}${DIALOG_TEXT}${ANSI_CLEAR_TEXT} --> ${ANSI_LIGHT_GREEN}${RETURN_STRING}${ANSI_CLEAR_TEXT}"
}

function inqChkBx() {
    local DIALOG_TEXT="$1"
    local -n INPUT_OPTIONS="$2"
    local -n RETURN_ARRAY="$3"

    local OPTIONS_STR=""
    for OPTION in "${INPUT_OPTIONS[@]}"; do
        OPTIONS_STR+="$OPTION \"$OPTION\" off "
    done

    local SELECTED_OPTIONS_STRING=$(kdialog --checklist "$DIALOG_TEXT" $OPTIONS_STR --title "Checkbox" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Abgebrochen"
        exit 0
    fi

    local IFS=$'\n'
    RETURN_ARRAY=($(echo "$SELECTED_OPTIONS_STRING" | sed 's/^"//;s/"$//'))
}