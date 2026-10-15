# OpenBGPD-portable (Debian package) for the lab DUT. amd64 and arm64.
FROM debian:trixie-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends openbgpd iproute2 iputils-ping \
 && rm -rf /var/lib/apt/lists/* \
 && (id _openbgpd >/dev/null 2>&1 || useradd -r -d /run/openbgpd -s /usr/sbin/nologin _openbgpd)
CMD ["bash", "-c", "mkdir -p /run/openbgpd && exec bgpd -d -f /etc/bgpd.conf"]
