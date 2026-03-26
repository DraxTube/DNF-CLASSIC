#!/bin/bash
# ============================================================
# DNF (Duke Nukem Forever Mod) - PlayStation Classic Launcher
# For use with AutoBleem on PS Classic Mini
# ============================================================

GAME_DIR="$(cd "$(dirname "$0")" && pwd)"

# Export library paths for any bundled shared libraries
export LD_LIBRARY_PATH="${GAME_DIR}/lib:${LD_LIBRARY_PATH}"

# SDL2 environment for PS Classic
export SDL_VIDEODRIVER=kmsdrm
export SDL_AUDIODRIVER=alsa

# Game controller mapping
if [ -f "${GAME_DIR}/gamecontrollerdb.txt" ]; then
    export SDL_GAMECONTROLLERCONFIG_FILE="${GAME_DIR}/gamecontrollerdb.txt"
fi

# Ensure framebuffer is accessible
if [ -e /dev/fb0 ]; then
    chmod 666 /dev/fb0 2>/dev/null || true
fi

# Set HOME so EDuke32 can write config files
export HOME="${GAME_DIR}"

# Copy default config if first run
if [ ! -f "${GAME_DIR}/eduke32-psc.cfg" ] && [ -f "${GAME_DIR}/eduke32.cfg" ]; then
    cp "${GAME_DIR}/eduke32.cfg" "${GAME_DIR}/eduke32-psc.cfg"
fi

cd "${GAME_DIR}"

echo "Starting Duke Nukem Forever (DNF) on PlayStation Classic..."
echo "Game dir: ${GAME_DIR}"

# Launch EDuke32 with DNF mod
# -gDNF.GRP    : Load the DNF game data
# -xDNFGAME.con: Use the DNF CON script
# -cfg          : Use PSC-specific config
# -nologo       : Skip logos for faster boot
# -j            : Add game dir as search path
./eduke32 \
    -gDNF.GRP \
    -xDNFGAME.con \
    -cfg eduke32-psc.cfg \
    -nologo \
    -j "${GAME_DIR}" \
    "$@"

EXIT_CODE=$?

# Cleanup - restore framebuffer if needed
sync

echo "DNF exited with code: ${EXIT_CODE}"
exit ${EXIT_CODE}
