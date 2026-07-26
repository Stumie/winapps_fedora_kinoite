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
    declare DIALOG_TEXT="$1"                # Dialog heading.
    declare INPUT_OPTIONS_VAR="$2"          # Input variable name (array).
    declare RETURN_STRING_VAR="$3"          # Output variable name (string).
    declare -n INPUT_OPTIONS="$INPUT_OPTIONS_VAR" # Input array nameref.
    declare -n RETURN_STRING="$RETURN_STRING_VAR" # Output string nameref.

    # Input validation: Check if options array is empty.
    if [ ${#INPUT_OPTIONS[@]} -eq 0 ]; then
        echo "Error: No options provided for menu." >&2
        exit 1
    fi

    # Other variables:
    declare -a KDIALOG_ARGS=()              # Arguments for kdialog --menu.

    # MAIN LOGIC.
    # Build kdialog arguments: "tag" "text" pairs.
    for OPTION in "${INPUT_OPTIONS[@]}"; do
        # Trim whitespace.
        OPTION=$(echo "$OPTION" | sed 's/^[ \t]*//;s/[ \t]*$//')
        # Replace commas in option text to avoid breaking CSV parsing later.
        OPTION=${OPTION//,/ }  # Replace commas with spaces.
        KDIALOG_ARGS+=("$OPTION" "$OPTION")  # tag and text are the same.
    done

    # Show menu and capture selection.
    RETURN_STRING=$(kdialog --menu "$DIALOG_TEXT" "${KDIALOG_ARGS[@]@Q}") || exit 0

    # Trim whitespace from result.
    RETURN_STRING=$(echo "$RETURN_STRING" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    # Display question and response (for debugging/feedback).
    echo -e "${ANSI_LIGHT_GREEN}Q) ${ANSI_CLEAR_TEXT}${ANSI_LIGHT_BLUE}${DIALOG_TEXT}${ANSI_CLEAR_TEXT} --> ${ANSI_LIGHT_GREEN}${RETURN_STRING}${ANSI_CLEAR_TEXT}"
}

function inqChkBx() {
    # DECLARE VARIABLES.
    declare DIALOG_TEXT="$1"                # Dialog heading.
    declare INPUT_OPTIONS_VAR="$2"          # Input variable name (array).
    declare RETURN_ARRAY_VAR="$3"           # Output variable name (array).
    declare -n INPUT_OPTIONS="$INPUT_OPTIONS_VAR" # Input array nameref.
    declare -n RETURN_ARRAY="$RETURN_ARRAY_VAR"   # Output array nameref.

    # Input validation: Check if options array is empty.
    if [ ${#INPUT_OPTIONS[@]} -eq 0 ]; then
        echo "Error: No options provided for checklist." >&2
        exit 1
    fi

    # Other variables:
    declare -a KDIALOG_ARGS=()              # Arguments for kdialog --checklist.
    declare SELECTED_CSV=""                 # Comma-separated list from kdialog.

    # MAIN LOGIC.
    # Build kdialog arguments: "tag" "text" "state" triplets.
    for OPTION in "${INPUT_OPTIONS[@]}"; do
        # Trim whitespace.
        OPTION=$(echo "$OPTION" | sed 's/^[ \t]*//;s/[ \t]*$//')
        # Replace commas in option text to avoid breaking CSV parsing later.
        OPTION=${OPTION//,/ }  # Replace commas with spaces.
        KDIALOG_ARGS+=("$OPTION" "$OPTION" "off")  # tag, text, initial state (off).
    done

    # Show checklist and capture selections (comma-separated).
    SELECTED_CSV=$(kdialog --checklist "$DIALOG_TEXT" "${KDIALOG_ARGS[@]@Q}") || exit 0

    # Split comma-separated output into array.
    IFS=',' read -ra RETURN_ARRAY <<< "$SELECTED_CSV"

    # Trim whitespace from each selected option.
    for ((i = 0; i < ${#RETURN_ARRAY[@]}; i++)); do
        RETURN_ARRAY[i]=$(echo "${RETURN_ARRAY[i]}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    done
}