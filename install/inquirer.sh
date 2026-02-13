#!/usr/bin/env bash
# Copyright (c) 2024 kahkhang
# All rights reserved.
#
# SPDX-License-Identifier: MIT
# For original source, see https://github.com/kahkhang/Inquirer.sh

### GLOBAL CONSTANTS ###
declare -r ANSI_LIGHT_BLUE="\033[1;94m" # Light blue text.
declare -r ANSI_LIGHT_GREEN="\033[92m"  # Light green text.
declare -r ANSI_CLEAR_TEXT="\033[0m"    # Default text.

### FUNCTIONS ###
function inqMenu() {
    # DECLARE VARIABLES.
    # Variables created from function arguments:
    declare DIALOG_TEXT="$1"                      # Dialog heading.
    declare INPUT_OPTIONS_VAR="$2"                # Input variable name.
    declare RETURN_STRING_VAR="$3"                # Output variable name.
    declare -n INPUT_OPTIONS="$INPUT_OPTIONS_VAR" # Input array nameref.
    declare -n RETURN_STRING="$RETURN_STRING_VAR" # Output string nameref.

    # Prepare options for kdialog
    local OPTIONS=()
    local i=1
    for OPTION in "${INPUT_OPTIONS[@]}"; do
        OPTIONS+=("$i" "$OPTION")
        ((i++))
    done

    # Show menu using kdialog
    local SELECTED_OPTION=$(kdialog --menu "$DIALOG_TEXT" "${OPTIONS[@]}" --title "Menu" 2>/dev/null)
    if [ $? -ne 0 ]; then
        exit 0
    fi

    # Map selected number to option text
    RETURN_STRING="${INPUT_OPTIONS[$((SELECTED_OPTION - 1))]}"

    # Display question and response.
    echo -e "${ANSI_LIGHT_GREEN}Q) ${ANSI_CLEAR_TEXT}${ANSI_LIGHT_BLUE}${DIALOG_TEXT}${ANSI_CLEAR_TEXT} --> ${ANSI_LIGHT_GREEN}${RETURN_STRING}${ANSI_CLEAR_TEXT}"
}

function inqChkBx() {
    # DECLARE VARIABLES.
    # Variables created from function arguments:
    declare DIALOG_TEXT="$1"                      # Dialog heading.
    declare INPUT_OPTIONS_VAR="$2"                # Input variable name.
    declare RETURN_ARRAY_VAR="$3"                 # Output variable name.
    declare -n INPUT_OPTIONS="$INPUT_OPTIONS_VAR" # Input array nameref.
    declare -n RETURN_ARRAY="$RETURN_ARRAY_VAR"   # Output array nameref.

    # Prepare options for kdialog
    local OPTIONS=()
    for OPTION in "${INPUT_OPTIONS[@]}"; do
        OPTIONS+=("$OPTION" "$OPTION" "off")
    done

    # Show checklist using kdialog
    local SELECTED_OPTIONS=$(kdialog --checklist "$DIALOG_TEXT" "${OPTIONS[@]}" --title "Checkbox" 2>/dev/null)
    if [ $? -ne 0 ]; then
        exit 0
    fi

    # Convert selected options to array
    local IFS=$'\n'
    RETURN_ARRAY=($(echo "$SELECTED_OPTIONS" | sed 's/^"//;s/"$//'))
}