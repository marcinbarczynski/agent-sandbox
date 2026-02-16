FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       nodejs \
       npm \
       sudo \
       gosu \
       git \
       ca-certificates \
       curl \
       procps \
       iproute2 \
       iputils-ping \
       less \
       vim-tiny \
       xauth \
    && rm -rf /var/lib/apt/lists/*

# Install Codex CLI globally.
RUN npm install -g @openai/codex

# Allow passwordless sudo for members of sudo group.
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/99-sudo-nopasswd \
    && chmod 0440 /etc/sudoers.d/99-sudo-nopasswd

RUN mkdir -p /workspace /codex-home

COPY container/entrypoint.sh /usr/local/bin/container-entrypoint.sh
RUN chmod +x /usr/local/bin/container-entrypoint.sh

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/container-entrypoint.sh"]
CMD ["codex", "--dangerously-bypass-approvals-and-sandbox"]
