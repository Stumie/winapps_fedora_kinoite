#!/usr/bin/env bash

set -e

if [ "$(id -u)" = "0" ]; then
    echo "ERROR! This script must not be run as root!" >&2
    exit 1
fi

check-for-software-existence () {
    for i in $@
    do
    if ! command -v $i &> /dev/null; then
        echo "ERROR: The software package '$i' is necessary but could not be found." >&2
        exit 1
    fi
    done
}

install-yq-into-user-directory () {
    curl -s -L -z ~/.local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" -o ~/.local/bin/yq
    chmod +x ~/.local/bin/yq
}

check-for-software-existence curl podman
install-yq-into-user-directory

readonly SCRIPT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
readonly CONFIG_PATH="${HOME}/.config/winapps/winapps.conf"

if [ -f "${HOME}/.config/winapps/compose.yaml" ]; then
    readonly COMPOSE_PATH="${HOME}/.config/winapps/compose.yaml"
else
    readonly COMPOSE_PATH="${SCRIPT_DIR_PATH}/compose.yaml"
fi

readonly CONTAINER_NAME="$(cat $COMPOSE_PATH | yq -r '.services.windows.container_name')"
readonly WINREGION="${LANG%.*}"
readonly WINKEYBOARD="${LANG%.*}"
CONTAINER_STATE=""
CONTAINER_STATE=$(podman ps --all --filter name="$CONTAINER_NAME" --format '{{.Status}}')
CONTAINER_STATE=${CONTAINER_STATE,,}
CONTAINER_STATE=${CONTAINER_STATE%% *}

if [[ "$CONTAINER_STATE" != "up" ]]; then
    if [[ "$(podman ps --all --filter name="$CONTAINER_NAME" --format '{{.Names}}')" != "$CONTAINER_NAME" ]]; then
        podman volume create --ignore data
        podman run \
            -d \
            --name "$CONTAINER_NAME" \
            --device=/dev/kvm \
            --device=/dev/net/tun \
            --network pasta:-t,127.0.0.1/8006:8006,-t,127.0.0.1/3389:3389,-u,127.0.0.1/3389:3389 \
            -v "data:/storage:z" \
            -v "$SCRIPT_DIR_PATH/oem:/oem:z" \
            --stop-timeout 120 \
            --uidmap "+0:@$(id -u)" \
            --restart "$(cat $COMPOSE_PATH | yq -r '.services.windows.restart')" \
            -e VERSION="$(cat $COMPOSE_PATH | yq -r '.services.windows.environment.VERSION')" \
            -e DISK_SIZE="$(cat $COMPOSE_PATH | yq -r '.services.windows.environment.DISK_SIZE')" \
            -e RAM_SIZE="$(cat $COMPOSE_PATH | yq -r '.services.windows.environment.RAM_SIZE')" \
            -e CPU_CORES="$(cat $COMPOSE_PATH | yq -r '.services.windows.environment.CPU_CORES')" \
            -e USERNAME="$(cat $COMPOSE_PATH | yq -r '.services.windows.environment.USERNAME')" \
            -e PASSWORD="$(cat $COMPOSE_PATH | yq -r '.services.windows.environment.PASSWORD')" \
            -e HOME="$(cat $COMPOSE_PATH | yq -r '.services.windows.environment.HOME')" \
            -e REGION="${WINREGION//_/-}" \
            -e KEYBOARD="${WINKEYBOARD//_/-}" \
            -e NETWORK="user" \
            "$(cat $COMPOSE_PATH | yq -r '.services.windows.image')"
    else
        podman restart "$CONTAINER_NAME"
    fi
fi
podman ps --all --filter name="$CONTAINER_NAME"
xdg-open "http://127.0.0.1:8006/"