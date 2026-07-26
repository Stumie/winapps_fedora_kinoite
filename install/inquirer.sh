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
    declare DIALOG_TEXT="$1"                     # Dialog heading.
    declare INPUT_OPTIONS_VAR="$2"               # Input variable name (array).
    declare RETURN_STRING_VAR="$3"              # Output variable name (string).
    declare -n _inq_INPUT_OPTIONS="$INPUT_OPTIONS_VAR" # Input array nameref (prefixed to avoid collision).
    declare -n _inq_RETURN_STRING="$RETURN_STRING_VAR" # Output string nameref (prefixed to avoid collision).

    # Dependency check
    if ! command -v kdialog >/dev/null 2>&1; then
        echo "Error: kdialog is not installed or not in PATH." >&2
        return 1
    fi

    # Input validation: Check if options array is empty.
    if [ ${#_inq_INPUT_OPTIONS[@]} -eq 0 ]; then
        echo "Error: No options provided for menu." >&2
        return 1
    fi

    # Build kdialog arguments: "tag" "text" pairs.
    declare -a KDIALOG_ARGS=()
    for OPTION in "${_inq_INPUT_OPTIONS[@]}"; do
        # Trim leading and trailing whitespace using pure Bash parameter expansion (no subshells).
        OPTION="${OPTION#"${OPTION%%[![:space:]]*}"}"
        OPTION="${OPTION%"${OPTION##*[![:space:]]}"}"
        KDIALOG_ARGS+=("$OPTION" "$OPTION")
    done

    # Show menu and capture selection.
    # NOTE: Do NOT use @Q here; it adds literal quotes to arguments.
    _inq_RETURN_STRING=$(kdialog --menu "$DIALOG_TEXT" "${KDIALOG_ARGS[@]}") || return 1

    # Trim whitespace from result using pure Bash parameter expansion.
    _inq_RETURN_STRING="${_inq_RETURN_STRING#"${_inq_RETURN_STRING%%[![:space:]]*}"}"
    _inq_RETURN_STRING="${_inq_RETURN_STRING%"${_inq_RETURN_STRING##*[![:space:]]}"}"

    # Display question and response using printf (avoids backslash interpretation).
    printf "%bQ) %b%b%s%b --> %b%s%b\n" \
        "$ANSI_LIGHT_GREEN" "$ANSI_CLEAR_TEXT" "$ANSI_LIGHT_BLUE" "$DIALOG_TEXT" \
        "$ANSI_CLEAR_TEXT" "$ANSI_LIGHT_GREEN" "$_inq_RETURN_STRING" "$ANSI_CLEAR_TEXT"
}

function inqChkBx() {
    # DECLARE VARIABLES.
    declare DIALOG_TEXT="$1"                     # Dialog heading.
    declare INPUT_OPTIONS_VAR="$2"               # Input variable name (array).
    declare RETURN_ARRAY_VAR="$3"                # Output variable name (array).
    declare -n _inq_INPUT_OPTIONS="$INPUT_OPTIONS_VAR" # Input array nameref (prefixed to avoid collision).
    declare -n _inq_RETURN_ARRAY="$RETURN_ARRAY_VAR"   # Output array nameref (prefixed to avoid collision).

    # Dependency check
    if ! command -v kdialog >/dev/null 2>&1; then
        echo "Error: kdialog is not installed or not in PATH." >&2
        return 1
    fi

    # Input validation: Check if options array is empty.
    if [ ${#_inq_INPUT_OPTIONS[@]} -eq 0 ]; then
        echo "Error: No options provided for checklist." >&2
        return 1
    fi

    # Build kdialog arguments: "tag" "text" "state" triplets.
    declare -a KDIALOG_ARGS=()
    for OPTION in "${_inq_INPUT_OPTIONS[@]}"; do
        # Trim leading and trailing whitespace using pure Bash parameter expansion.
        OPTION="${OPTION#"${OPTION%%[![:space:]]*}"}"
        OPTION="${OPTION%"${OPTION##*[![:space:]]}"}"
        KDIALOG_ARGS+=("$OPTION" "$OPTION" "off")
    done

    # Show checklist with --separate-output (each selected item printed on a new line).
    declare RAW_OUTPUT
    RAW_OUTPUT=$(kdialog --separate-output --checklist "$DIALOG_TEXT" "${KDIALOG_ARGS[@]}") || return 1

    # Read newline-separated items into array safely (no CSV parsing needed).
    _inq_RETURN_ARRAY=()
    if [ -n "$RAW_OUTPUT" ]; then
        mapfile -t _inq_RETURN_ARRAY <<< "$RAW_OUTPUT"
    fi
}