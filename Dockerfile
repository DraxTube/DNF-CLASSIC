FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Rome

# Install base build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    unzip \
    python3 \
    nasm \
    pkg-config \
    autoconf \
    automake \
    libtool \
    cmake \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download and install the PSC Cross-Compile Toolchain
# FIX #1: after unzip, restore executable permissions on all toolchain binaries.
# unzip does NOT preserve Unix file permissions, so the cross-compiler binaries
# end up as non-executable files and the SDL2 configure step fails with:
#   "C compiler cannot create executables"
RUN wget -q https://github.com/autobleem/PSC-CrossCompile-Toolchain/archive/refs/heads/master.zip -O /tmp/psc-toolchain.zip && \
    unzip -q /tmp/psc-toolchain.zip -d /opt/ && \
    mv /opt/PSC-CrossCompile-Toolchain-master /opt/PSC-CrossCompile-Toolchain && \
    rm /tmp/psc-toolchain.zip && \
    chmod -R +x /opt/PSC-CrossCompile-Toolchain/bin/ && \
    chmod -R +x /opt/PSC-CrossCompile-Toolchain/libexec/ 2>/dev/null || true

ENV PSC_TOOLCHAIN=/opt/PSC-CrossCompile-Toolchain
ENV SYSROOT=/opt/PSC-CrossCompile-Toolchain/arm-buildroot-linux-gnueabihf/sysroot
ENV PATH="/opt/PSC-CrossCompile-Toolchain/bin:${PATH}"

# ARM flags for PSC (Cortex-A35, ARMv8-a 32-bit mode)
ENV PSC_CFLAGS="--sysroot=${SYSROOT} -march=armv8-a -mfloat-abi=hard -mfpu=neon-fp-armv8 -O2"
ENV PSC_LDFLAGS="--sysroot=${SYSROOT} -L${SYSROOT}/usr/lib"

# Build SDL2 for PSC from source
# FIX #2: use the GitHub release URL (libsdl.org redirects to GitHub but can
#         be unreliable in CI); also enable kmsdrm which is the video driver
#         used by launch.sh (SDL_VIDEODRIVER=kmsdrm).
RUN wget -q https://github.com/libsdl-org/SDL/releases/download/release-2.0.22/SDL2-2.0.22.tar.gz -O /tmp/SDL2.tar.gz && \
    mkdir -p /tmp/sdl2-build && \
    tar xzf /tmp/SDL2.tar.gz -C /tmp/sdl2-build --strip-components=1 && \
    cd /tmp/sdl2-build && \
    CC=arm-buildroot-linux-gnueabihf-gcc \
    CXX=arm-buildroot-linux-gnueabihf-g++ \
    AR=arm-buildroot-linux-gnueabihf-ar \
    RANLIB=arm-buildroot-linux-gnueabihf-ranlib \
    CFLAGS="${PSC_CFLAGS}" \
    LDFLAGS="${PSC_LDFLAGS}" \
    ./configure \
        --host=arm-buildroot-linux-gnueabihf \
        --prefix=${SYSROOT}/usr \
        --enable-video-dummy \
        --enable-video-kmsdrm \
        --disable-video-opengl \
        --disable-video-opengles \
        --disable-video-opengles1 \
        --disable-video-opengles2 \
        --disable-video-vulkan \
        --disable-video-x11 \
        --disable-video-wayland \
        --disable-pulseaudio \
        --disable-jack \
        --disable-esd \
        --disable-oss \
        --disable-arts \
        --disable-nas \
        --disable-sndio \
        --disable-dbus \
        --disable-ibus \
        --disable-fcitx \
        --enable-alsa \
        --enable-joystick \
        --enable-threads \
        --enable-timers \
        --enable-events \
        --disable-shared \
        --enable-static && \
    make -j$(nproc) && \
    make install && \
    rm -rf /tmp/sdl2-build /tmp/SDL2.tar.gz

WORKDIR /build
