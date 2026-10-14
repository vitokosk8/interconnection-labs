# BIRD 2 image for the lab (route servers and the BIRD DUT).
# Debian trixie ships BIRD 2.17 (TCP-AO and ASPA capable).
FROM debian:trixie-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends bird2 iproute2 iputils-ping tcpdump \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /run/bird
CMD ["/usr/sbin/bird", "-f", "-c", "/etc/bird/bird.conf", "-s", "/run/bird/bird.ctl"]
