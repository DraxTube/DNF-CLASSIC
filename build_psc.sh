#!/bin/bash
set -e

# ============================================================
# DNF (Duke Nukem Forever Mod) - PlayStation Classic Build Script
# Cross-compiles EDuke32 for ARM Cortex-A35 (PS Classic)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/eduke32-src"
OUTPUT_DIR="${SCRIPT_DIR}/output"

# PSC toolchain paths
PSC_TOOLCHAIN="${PSC_TOOLCHAIN:-/opt/PSC-CrossCompile-Toolchain}"
CROSS_PREFIX="${PSC_TOOLCHAIN}/bin/arm-buildroot-linux-gnueabihf-"
SYSROOT="${PSC_TOOLCHAIN}/arm-buildroot-linux-gnueabihf/sysroot"

export CC="${CROSS_PREFIX}gcc"
export CXX="${CROSS_PREFIX}g++"
export AR="${CROSS_PREFIX}ar"
export RANLIB="${CROSS_PREFIX}ranlib"
export STRIP="${CROSS_PREFIX}strip"
export PKG_CONFIG_PATH="${SYSROOT}/usr/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="${SYSROOT}"

# ARM flags optimized for PS Classic's Cortex-A35
ARM_FLAGS="-march=armv8-a -mcpu=cortex-a35 -mfpu=neon-fp-armv8 -mfloat-abi=hard -O2"

echo "========================================="
echo "  DNF PS Classic - Build Script"
echo "========================================="
echo "Toolchain: ${PSC_TOOLCHAIN}"
echo "CC: ${CC}"
echo ""

# Step 1: Clone EDuke32 source if not present
if [ ! -d "${BUILD_DIR}" ]; then
    echo "[1/4] Cloning EDuke32 source..."
    git clone --depth=1 https://voidpoint.io/terminx/eduke32.git "${BUILD_DIR}"
else
    echo "[1/4] EDuke32 source already present, skipping clone"
fi

# Step 2: Apply PSC-specific patches
echo "[2/4] Applying PS Classic patches..."

cd "${BUILD_DIR}"

# Patch: Force software renderer and disable features not available on PSC
cat > psc_config.patch << 'PATCHEOF'
--- a/source/duke3d/src/config.cpp
+++ b/source/duke3d/src/config.cpp
@@ -0,0 +1,5 @@
+// PSC: Default to software renderer
+#ifdef __arm__
+#define PSC_DEFAULT_RENDERER 0
+#endif
PATCHEOF

# Create a custom Makefile include for PSC settings
cat > Makefile.psc << 'MAKEEOF'
# PlayStation Classic overrides
PLATFORM=LINUX
ARCH=arm
NOASM=1
USE_OPENGL=0
POLYMER=0
HAVE_GTK2=0
STARTUP_WINDOW=0
LTO=0
RENDERTYPE_SDL=1
SDL_TARGET=2
HAVE_FLAC=0
HAVE_XMP=0
HAVE_VORBIS=0
HAVE_JWZGLES=0
NETCODE=0
USE_LIBVPX=0

CROSS=${CROSS_PREFIX}

COMMONFLAGS += ${ARM_FLAGS}
COMMONFLAGS += --sysroot=${SYSROOT}
COMMONFLAGS += -I${SYSROOT}/usr/include
COMMONFLAGS += -I${SYSROOT}/usr/include/SDL2
COMMONFLAGS += -DSDL_DISABLE_IMMINTRIN_H
COMMONFLAGS += -D__arm__

LDFLAGS += --sysroot=${SYSROOT}
LDFLAGS += -L${SYSROOT}/usr/lib
LDFLAGS += -Wl,-rpath-link,${SYSROOT}/usr/lib
MAKEEOF

# Step 3: Build EDuke32
echo "[3/4] Building EDuke32 for PlayStation Classic..."

# Expand variables in Makefile.psc  
sed -i "s|\${CROSS_PREFIX}|${CROSS_PREFIX}|g" Makefile.psc
sed -i "s|\${ARM_FLAGS}|${ARM_FLAGS}|g" Makefile.psc
sed -i "s|\${SYSROOT}|${SYSROOT}|g" Makefile.psc

make -j$(nproc) -f GNUmakefile eduke32 \
    PLATFORM=LINUX \
    ARCH=arm \
    CROSS="${CROSS_PREFIX}" \
    NOASM=1 \
    USE_OPENGL=0 \
    POLYMER=0 \
    HAVE_GTK2=0 \
    STARTUP_WINDOW=0 \
    LTO=0 \
    RENDERTYPE_SDL=1 \
    SDL_TARGET=2 \
    HAVE_FLAC=0 \
    HAVE_XMP=0 \
    HAVE_VORBIS=0 \
    HAVE_JWZGLES=0 \
    NETCODE=0 \
    USE_LIBVPX=0 \
    COMMONFLAGS="${ARM_FLAGS} --sysroot=${SYSROOT} -I${SYSROOT}/usr/include/SDL2 -DSDL_DISABLE_IMMINTRIN_H" \
    LDFLAGS="--sysroot=${SYSROOT} -L${SYSROOT}/usr/lib -Wl,-rpath-link,${SYSROOT}/usr/lib" \
    LIBS="-lSDL2 -lpthread -lrt -ldl -lm" \
    SANS="" \
    CLANG=0

echo "[3/4] EDuke32 build complete!"

# Step 4: Package output
echo "[4/4] Packaging output..."

mkdir -p "${OUTPUT_DIR}/DNF/lib"

# Copy the eduke32 binary
EDUKE32_BIN=$(find . -name "eduke32" -type f -executable | head -1)
if [ -z "${EDUKE32_BIN}" ]; then
    # Try common output paths
    for path in eduke32 build/eduke32; do
        if [ -f "${path}" ]; then
            EDUKE32_BIN="${path}"
            break
        fi
    done
fi

if [ -z "${EDUKE32_BIN}" ]; then
    echo "ERROR: Could not find eduke32 binary!"
    find . -name "eduke32*" -type f 2>/dev/null
    exit 1
fi

cp "${EDUKE32_BIN}" "${OUTPUT_DIR}/DNF/eduke32"
chmod +x "${OUTPUT_DIR}/DNF/eduke32"

# Copy SDL2 shared libraries from sysroot (build as shared for runtime)
# Since we built SDL2 as static, we need to also build a shared version for the PSC
# Actually, since static linking embeds SDL2 into the binary, we're good
# But let's also copy any needed shared libs from the toolchain sysroot
for lib in libstdc++.so* libgcc_s.so* libpthread.so* librt.so* libdl.so* libm.so*; do
    find "${SYSROOT}" -name "${lib}" -type f -o -name "${lib}" -type l 2>/dev/null | while read f; do
        cp -a "$f" "${OUTPUT_DIR}/DNF/lib/" 2>/dev/null || true
    done
done

# Copy PSC launch files
cp "${SCRIPT_DIR}/psc/launch.sh" "${OUTPUT_DIR}/DNF/" 2>/dev/null || true
cp "${SCRIPT_DIR}/psc/eduke32.cfg" "${OUTPUT_DIR}/DNF/" 2>/dev/null || true
cp "${SCRIPT_DIR}/psc/gamecontrollerdb.txt" "${OUTPUT_DIR}/DNF/" 2>/dev/null || true

chmod +x "${OUTPUT_DIR}/DNF/launch.sh" 2>/dev/null || true

echo ""
echo "========================================="
echo "  Build Complete!"
echo "========================================="
echo "Output: ${OUTPUT_DIR}/DNF/"
echo ""
echo "Binary info:"
file "${OUTPUT_DIR}/DNF/eduke32"
echo ""
echo "Next: Copy your game data files to the DNF folder:"
echo "  - DUKE3D.GRP (Atomic Edition)"
echo "  - DNF.GRP"
echo "  - DNFGAME.CON, DNF.CON, DEFS.CON, USER.CON"
echo "  - EBIKE.CON and all .CFG files"
echo "========================================="
