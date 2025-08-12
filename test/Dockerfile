FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CONFIG_DIR="/config"

RUN apt-get update && \
    apt-get install -y \
        bash \
        inotify-tools \
        mailutils \
        coreutils \
        util-linux \
        logrotate \
        sudo \
        tzdata \
        less \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY init.sh /init.sh
RUN chmod +x /init.sh

COPY data /data
RUN chmod -R +x /data

WORKDIR /inotibatch

VOLUME ["/inotibatch", "/config", "/var/log/inotibatch"]

CMD ["/init.sh", "&&", "/bin/bash"]