# Minimal RTR server for the lab: StayRTR serving a static VRP file.
# In production you would run a full relying-party validator
# (Routinator, rpki-client, FORT) in front of it.
FROM debian:trixie-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends stayrtr iproute2 iputils-ping \
 && rm -rf /var/lib/apt/lists/*
CMD ["stayrtr", "-bind", ":3323", "-cache", "/etc/stayrtr/vrps.json", "-checktime=false", "-refresh", "30"]
