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
    declare DIALOG_TEXT="$1"         # Dialog heading.
    declare -n INPUT_OPTIONS="$2"    # Input variable name.
    declare -n RETURN_STRING="$3"    # Output variable name.

    # MAIN LOGIC.
    # Create a menu using kdialog
    local OPTIONS_STR=""
    for OPTION in "${INPUT_OPTIONS[@]}"; do
        OPTIONS_STR+="$OPTION \"$OPTION\" "
    done

    RETURN_STRING=$(kdialog --menu "$DIALOG_TEXT" $OPTIONS_STR --title "Menu" 2>/dev/null) || exit 0

    # Display question and response.
    echo -e "${ANSI_LIGHT_GREEN}Q) ${ANSI_CLEAR_TEXT}${ANSI_LIGHT_BLUE}${DIALOG_TEXT}${ANSI_CLEAR_TEXT} --> ${ANSI_LIGHT_GREEN}${RETURN_STRING}${ANSI_CLEAR_TEXT}"
}

function inqChkBx() {
    # DECLARE VARIABLES.
    declare DIALOG_TEXT="$1"          # Dialog heading.
    declare -n INPUT_OPTIONS="$2"     # Input variable name.
    declare -n RETURN_ARRAY="$3"      # Output variable name.

    # MAIN LOGIC.
    # Create a checklist using kdialog
    local OPTIONS_STR=""
    for OPTION in "${INPUT_OPTIONS[@]}"; do
        OPTIONS_STR+="$OPTION \"$OPTION\" off "
    done

    local SELECTED_OPTIONS_STRING=$(kdialog --checklist "$DIALOG_TEXT" $OPTIONS_STR --title "Checkbox" 2>/dev/null) || exit 0

    # Convert the output string into an array.
    local IFS=$'\n'
    RETURN_ARRAY=($(echo "$SELECTED_OPTIONS_STRING" | sed 's/^"//;s/"$//'))
}