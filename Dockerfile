FROM debian:bookworm-slim

ARG TARGETARCH
ARG GODOT_VERSION=4.7.1

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates wget unzip \
    libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libxext6 \
    libgl1 libasound2 libpulse0 libdbus-1-3 \
    libfontconfig1 libfreetype6 \
 && ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "x86_64" || echo "arm64") \
 && wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.${ARCH}.zip" -O /tmp/godot.zip \
 && unzip /tmp/godot.zip -d /tmp \
 && mv "/tmp/Godot_v${GODOT_VERSION}-stable_linux.${ARCH}" /usr/local/bin/godot \
 && chmod +x /usr/local/bin/godot \
 && apt-get purge -y wget unzip \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/* /tmp/*

COPY game.pck /game.pck

EXPOSE 6466/udp

ENTRYPOINT ["godot", "--headless", "--main-pack", "/game.pck"]
