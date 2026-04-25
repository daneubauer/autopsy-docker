#!/usr/bin/env bash
set -euo pipefail

DISPLAY="${DISPLAY:-:1}"
AUTOPSY_RESOLUTION="${AUTOPSY_RESOLUTION:-}"
DISPLAY_WIDTH="${DISPLAY_WIDTH:-1920}"
DISPLAY_HEIGHT="${DISPLAY_HEIGHT:-1080}"
DISPLAY_DEPTH="${DISPLAY_DEPTH:-24}"
VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
VNC_PASSWORD="${VNC_PASSWORD:-}"
AUTOPSY_HOME="${AUTOPSY_HOME:-/opt/autopsy}"
AUTOPSY_USERDIR="${AUTOPSY_USERDIR:-/config/userdir}"
AUTOPSY_CACHEDIR="${AUTOPSY_CACHEDIR:-/config/cachedir}"
AUTOPSY_WORKDIR="${AUTOPSY_WORKDIR:-/cases}"

if [[ -n "${AUTOPSY_RESOLUTION}" ]]; then
    case "${AUTOPSY_RESOLUTION}" in
        *x*)
            DISPLAY_WIDTH="${AUTOPSY_RESOLUTION%x*}"
            DISPLAY_HEIGHT="${AUTOPSY_RESOLUTION#*x}"
            ;;
        *)
            echo "Invalid AUTOPSY_RESOLUTION: ${AUTOPSY_RESOLUTION}. Expected WIDTHxHEIGHT." >&2
            exit 1
            ;;
    esac
fi

mkdir -p "${AUTOPSY_USERDIR}" "${AUTOPSY_CACHEDIR}" "${AUTOPSY_WORKDIR}" /tmp/runtime-autopsy
chown -R autopsy:autopsy "${AUTOPSY_USERDIR}" "${AUTOPSY_CACHEDIR}" "${AUTOPSY_WORKDIR}" /tmp/runtime-autopsy /home/autopsy

export DISPLAY
export HOME=/home/autopsy
export XDG_RUNTIME_DIR=/tmp/runtime-autopsy
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

cleanup() {
    local code=$?
    jobs -pr | xargs -r kill >/dev/null 2>&1 || true
    wait || true
    exit "${code}"
}

trap cleanup EXIT INT TERM

dbus-daemon --session --address="${DBUS_SESSION_BUS_ADDRESS}" --fork >/tmp/dbus.log 2>&1
Xvfb "${DISPLAY}" -screen 0 "${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH}" -ac +extension GLX +render -noreset >/tmp/xvfb.log 2>&1 &

for _ in $(seq 1 30); do
    if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

fluxbox >/tmp/fluxbox.log 2>&1 &

if [[ -n "${VNC_PASSWORD}" ]]; then
    x11vnc -storepasswd "${VNC_PASSWORD}" /tmp/x11vnc.pass >/tmp/x11vnc-passwd.log 2>&1
    x11vnc \
        -display "${DISPLAY}" \
        -rfbport "${VNC_PORT}" \
        -forever \
        -shared \
        -passwdfile /tmp/x11vnc.pass \
        -listen 0.0.0.0 \
        -xkb \
        >/tmp/x11vnc.log 2>&1 &
else
    x11vnc \
        -display "${DISPLAY}" \
        -rfbport "${VNC_PORT}" \
        -forever \
        -shared \
        -nopw \
        -listen 0.0.0.0 \
        -xkb \
        >/tmp/x11vnc.log 2>&1 &
fi

websockify --web=/usr/share/novnc/ "${NOVNC_PORT}" "0.0.0.0:${VNC_PORT}" >/tmp/novnc.log 2>&1 &

autopsy_cmd=(
    "${AUTOPSY_HOME}/bin/autopsy"
    "--nosplash"
    "--userdir" "${AUTOPSY_USERDIR}"
    "--cachedir" "${AUTOPSY_CACHEDIR}"
)

if [[ -n "${AUTOPSY_EXTRA_ARGS:-}" ]]; then
    # shellcheck disable=SC2206
    extra_args=( ${AUTOPSY_EXTRA_ARGS} )
    autopsy_cmd+=( "${extra_args[@]}" )
fi

cd "${AUTOPSY_WORKDIR}"
gosu autopsy:autopsy env \
    DISPLAY="${DISPLAY}" \
    HOME="${HOME}" \
    XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
    DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS}" \
    "${autopsy_cmd[@]}" &

wait $!
