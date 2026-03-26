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
RUN wget -q https://github.com/autobleem/PSC-CrossCompile-Toolchain/archive/refs/heads/master.zip -O /tmp/psc-toolchain.zip && \
    unzip -q /tmp/psc-toolchain.zip -d /opt/ && \
    mv /opt/PSC-CrossCompile-Toolchain-master /opt/PSC-CrossCompile-Toolchain && \
    rm /tmp/psc-toolchain.zip

# CORREZIONE 1: Aggiunto l'effettivo percorso root della toolchain (armv8-sony-linux-gnueabihf)
ENV PSC_TOOLCHAIN=/opt/PSC-CrossCompile-Toolchain/armv8-sony-linux-gnueabihf
ENV SYSROOT=${PSC_TOOLCHAIN}/armv8-sony-linux-gnueabihf/sysroot
ENV PATH="${PSC_TOOLCHAIN}/bin:${PATH}"

# ARM flags for PSC (Cortex-A35, ARMv8-a 32-bit mode)
ENV PSC_CFLAGS="--sysroot=${SYSROOT} -march=armv8-a -mfloat-abi=hard -mfpu=neon-fp-armv8 -O2"
ENV PSC_LDFLAGS="--sysroot=${SYSROOT} -L${SYSROOT}/usr/lib"

# Build SDL2 for PSC from source
RUN wget -q https://www.libsdl.org/release/SDL2-2.0.14.tar.gz -O /tmp/SDL2.tar.gz && \
    mkdir -p /tmp/sdl2-build && \
    tar xzf /tmp/SDL2.tar.gz -C /tmp/sdl2-build --strip-components=1 && \
    cd /tmp/sdl2-build && \
    # CORREZIONE 2: Sostituito "arm-buildroot..." con "armv8-sony..."
    CC=armv8-sony-linux-gnueabihf-gcc \
    CXX=armv8-sony-linux-gnueabihf-g++ \
    AR=armv8-sony-linux-gnueabihf-ar \
    RANLIB=armv8-sony-linux-gnueabihf-ranlib \
    CFLAGS="${PSC_CFLAGS}" \
    LDFLAGS="${PSC_LDFLAGS}" \
    ./configure \
        --host=armv8-sony-linux-gnueabihf \
        --prefix=${SYSROOT}/usr \
        --enable-video-dummy \
        --disable-video-opengl \
        --disable-video-opengles \
        --disable-video-opengles1 \
        --disable-video-opengles2 \
        --disable-video-vulkan \
        --disable-video-x11 \
        --disable-video-wayland \
        --disable-video-kmsdrm \
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
