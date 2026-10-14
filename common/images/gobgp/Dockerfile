# GoBGP for the lab DUT: official release binaries (gobgpd + gobgp CLI)
# on a small Debian base. Works on amd64 and arm64 (Apple Silicon).
FROM debian:trixie-slim
ARG GOBGP_VERSION=4.10.0
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl iproute2 iputils-ping \
 && ARCH="$(dpkg --print-architecture)" \
 && curl -fsSL "https://github.com/osrg/gobgp/releases/download/v${GOBGP_VERSION}/gobgp_${GOBGP_VERSION}_linux_${ARCH}.tar.gz" \
    | tar -xz -C /usr/local/bin gobgp gobgpd \
 && apt-get purge -y curl && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*
CMD ["gobgpd", "-f", "/etc/gobgp/gobgpd.toml", "-p"]
