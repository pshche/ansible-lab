FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      openssh-server python3 sudo ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/bash ubuntu \
    && echo 'ubuntu:ubuntu' | chpasswd \
    && adduser ubuntu sudo \
    && echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu \
    && chmod 440 /etc/sudoers.d/ubuntu
RUN mkdir -p /var/run/sshd
EXPOSE 22 3000
CMD ["/usr/sbin/sshd", "-D"]
