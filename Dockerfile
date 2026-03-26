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
    libdrm-dev \
    && rm -rf /var/lib/apt/lists/*

# Download and install the PSC Cross-Compile Toolchain
RUN wget -q https://github.com/autobleem/PSC-CrossCompile-Toolchain/archive/refs/heads/master.zip -O /tmp/psc-toolchain.zip && \
    unzip -q /tmp/psc-toolchain.zip -d /opt/ && \
    mv /opt/PSC-CrossCompile-Toolchain-master /opt/PSC-CrossCompile-Toolchain && \
    rm /tmp/psc-toolchain.zip

ENV PSC_TOOLCHAIN=/opt/PSC-CrossCompile-Toolchain
ENV CROSS_PREFIX=${PSC_TOOLCHAIN}/bin/arm-buildroot-linux-gnueabihf-
ENV CC=${CROSS_PREFIX}gcc
ENV CXX=${CROSS_PREFIX}g++
ENV AR=${CROSS_PREFIX}ar
ENV RANLIB=${CROSS_PREFIX}ranlib
ENV STRIP=${CROSS_PREFIX}strip
ENV PATH="${PSC_TOOLCHAIN}/bin:${PATH}"
ENV SYSROOT=${PSC_TOOLCHAIN}/arm-buildroot-linux-gnueabihf/sysroot

# Build SDL2 for PSC from source
RUN wget -q https://www.libsdl.org/release/SDL2-2.0.14.tar.gz -O /tmp/SDL2.tar.gz && \
    mkdir -p /tmp/sdl2-build && \
    tar xzf /tmp/SDL2.tar.gz -C /tmp/sdl2-build --strip-components=1 && \
    cd /tmp/sdl2-build && \
    ./configure \
        --host=arm-buildroot-linux-gnueabihf \
        --prefix=${SYSROOT}/usr \
        --with-sysroot=${SYSROOT} \
        --enable-video-kmsdrm \
        --enable-video-fbdev \
        --enable-video-dummy \
        --disable-video-opengl \
        --disable-video-opengles \
        --disable-video-opengles2 \
        --disable-video-vulkan \
        --disable-video-x11 \
        --disable-video-wayland \
        --enable-alsa \
        --disable-pulseaudio \
        --disable-jack \
        --disable-esd \
        --enable-joystick \
        --enable-haptic \
        --disable-oss \
        --disable-arts \
        --disable-nas \
        --enable-threads \
        --enable-timers \
        --enable-events \
        --disable-shared \
        --enable-static \
        CFLAGS="-march=armv8-a -mcpu=cortex-a35 -mfpu=neon-fp-armv8 -mfloat-abi=hard -O2" && \
    make -j$(nproc) && \
    make install && \
    rm -rf /tmp/sdl2-build /tmp/SDL2.tar.gz

# Build SDL2_mixer for audio support
RUN wget -q https://www.libsdl.org/projects/SDL_mixer/release/SDL2_mixer-2.0.4.tar.gz -O /tmp/SDL2_mixer.tar.gz && \
    mkdir -p /tmp/sdl2mixer-build && \
    tar xzf /tmp/SDL2_mixer.tar.gz -C /tmp/sdl2mixer-build --strip-components=1 && \
    cd /tmp/sdl2mixer-build && \
    ./configure \
        --host=arm-buildroot-linux-gnueabihf \
        --prefix=${SYSROOT}/usr \
        --with-sysroot=${SYSROOT} \
        --disable-shared \
        --enable-static \
        --disable-music-mp3 \
        --disable-music-ogg \
        --enable-music-midi \
        --enable-music-mod \
        CFLAGS="-march=armv8-a -mcpu=cortex-a35 -mfpu=neon-fp-armv8 -mfloat-abi=hard -O2" \
        SDL2_CONFIG="${SYSROOT}/usr/bin/sdl2-config" && \
    make -j$(nproc) && \
    make install && \
    rm -rf /tmp/sdl2mixer-build /tmp/SDL2_mixer.tar.gz

# Build libvpx (needed by eduke32 for Matroska video playback)
RUN git clone --depth=1 --branch v1.9.0 https://chromium.googlesource.com/webm/libvpx.git /tmp/libvpx && \
    cd /tmp/libvpx && \
    ./configure \
        --target=armv7-linux-gcc \
        --prefix=${SYSROOT}/usr \
        --disable-examples \
        --disable-unit-tests \
        --disable-vp9 \
        --enable-vp8 \
        --enable-static \
        --disable-shared \
        --enable-pic \
        --extra-cflags="-march=armv8-a -mcpu=cortex-a35 -mfpu=neon-fp-armv8 -mfloat-abi=hard" \
        --as=auto \
        CC="${CC}" \
        CXX="${CXX}" \
        AR="${AR}" && \
    make -j$(nproc) && \
    make install && \
    rm -rf /tmp/libvpx

WORKDIR /build
