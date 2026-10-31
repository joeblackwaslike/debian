# syntax=docker/dockerfile:1
FROM debian:trixie-slim AS build
ARG TARGETARCH
ARG DUMB_INIT_VERSION=1.2.5
ARG DUMB_INIT_SHA256_AMD64=e874b55f3279ca41415d290c512a7ba9d08f98041b28ae7c2acb19a545f1c4df
ARG DUMB_INIT_SHA256_ARM64=b7d648f97154a99c539b63c55979cd29f005f88430fb383007fe3458340b795e
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends mmdebstrap ca-certificates curl binutils >/dev/null

RUN mmdebstrap --variant=minbase --include=bash,apt,dpkg,ca-certificates \
      --dpkgopt='path-exclude=/usr/share/doc/*' --dpkgopt='path-include=/usr/share/doc/*/copyright' \
      --dpkgopt='path-exclude=/usr/share/man/*' --dpkgopt='path-exclude=/usr/share/info/*' \
      --dpkgopt='path-exclude=/usr/share/locale/*' --dpkgopt='path-include=/usr/share/locale/locale.alias' \
      --dpkgopt='path-exclude=/usr/share/lintian/*' \
      trixie /rootfs http://deb.debian.org/debian

COPY strip.sh /strip.sh
RUN set -eux; \
    case "$TARGETARCH" in \
      amd64) arch=x86_64; sha=$DUMB_INIT_SHA256_AMD64 ;; \
      arm64) arch=aarch64; sha=$DUMB_INIT_SHA256_ARM64 ;; \
    esac; \
    curl -fsSL -o /rootfs/usr/bin/dumb-init \
      "https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_${arch}"; \
    echo "$sha  /rootfs/usr/bin/dumb-init" | sha256sum -c -; \
    chmod 0755 /rootfs/usr/bin/dumb-init
RUN printf 'APT::Install-Recommends "false";\nAPT::Install-Suggests "false";\nAcquire::Languages "none";\n' \
      > /rootfs/etc/apt/apt.conf.d/99tiny; \
    rm -f /rootfs/etc/apt/sources.list; \
    printf 'Types: deb\nURIs: http://deb.debian.org/debian\nSuites: trixie trixie-updates\nComponents: main\nSigned-By: /usr/share/keyrings/debian-archive-keyring.pgp\n\nTypes: deb\nURIs: http://deb.debian.org/debian-security\nSuites: trixie-security\nComponents: main\nSigned-By: /usr/share/keyrings/debian-archive-keyring.pgp\n' \
      > /rootfs/etc/apt/sources.list.d/debian.sources; \
    bash /strip.sh /rootfs

FROM scratch
COPY --from=build /rootfs /
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["bash"]
