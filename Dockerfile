FROM docker.io/arm64v8/alpine:3.15

# Image metadata
# git commit
LABEL org.opencontainers.image.revision="-"
LABEL org.opencontainers.image.source="https://github.com/jkaldon/k8s-archiver/tree/master"

COPY resources/* /home/k8s-archiver/

RUN apk --update add --no-cache \
             jq \
             yq \
             curl \
             coreutils \
             gettext \
             openssh \
             openssl \
             ca-certificates \
             screen \
             gnupg \
             bash \
             git \
             vim && \
    addgroup -g 1000 -S k8s-archiver && \
    adduser -u 1000 -S k8s-archiver -G k8s-archiver && \
    curl 'https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3' | bash && \
    curl -Lo /usr/local/bin/kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl" && \
    chmod a+x /usr/local/bin/kubectl /home/k8s-archiver/k8s-archiver.sh && \
    mkdir /home/k8s-archiver/.kube /home/k8s-archiver/.ssh && \
    ln -sf /home/k8s-archiver/.secret/kube-config /home/k8s-archiver/.kube/config && \
    ln -sf /home/k8s-archiver/.secret/ssh-private-key /home/k8s-archiver/.ssh/id_rsa && \
    ln -sf /home/k8s-archiver/.secret/ssh-public-key /home/k8s-archiver/.ssh/id_rsa.pub && \
    ln -sf /home/k8s-archiver/.secret/known_hosts /home/k8s-archiver/.ssh/known_hosts && \
    chown -R k8s-archiver.k8s-archiver /home/k8s-archiver

USER k8s-archiver

WORKDIR /home/k8s-archiver
