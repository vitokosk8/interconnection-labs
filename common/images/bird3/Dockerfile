# BIRD 3 image for the bird3 / aspa-bird3 labs, built from the official
# source (CZ.NIC, GitHub mirror) so the version is exact on amd64 and arm64.
ARG BIRD_VERSION=3.4.0

FROM debian:trixie-slim AS build
ARG BIRD_VERSION
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential autoconf bison flex m4 libreadline-dev libncurses-dev \
      ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN curl -fsSL "https://github.com/CZ-NIC/bird/archive/refs/tags/v${BIRD_VERSION}.tar.gz" \
    | tar -xz --strip-components=1 \
 && autoreconf -i \
 && ./configure --prefix=/usr --sysconfdir=/etc/bird --runstatedir=/run/bird \
 && make -j"$(nproc)" \
 && make install DESTDIR=/out

FROM debian:trixie-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends libreadline8t64 iproute2 iputils-ping tcpdump \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /run/bird /etc/bird
COPY --from=build /out/usr/sbin/bird /out/usr/sbin/birdc /out/usr/sbin/birdcl /usr/sbin/
CMD ["/usr/sbin/bird", "-f", "-c", "/etc/bird/bird.conf", "-s", "/run/bird/bird.ctl"]
