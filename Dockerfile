FROM --platform=${BUILDPLATFORM} golang:1.25-bookworm AS build
ARG TARGETARCH
ARG BUILD_TIME=
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH} \
  go build -trimpath -ldflags="-s -w -X main.BuildTime=${BUILD_TIME}" -o /out/xlp ./cmd/xlp

FROM --platform=${TARGETARCH} ubuntu:focal
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install --no-install-recommends -y ca-certificates proot tzdata \
  && rm -rf /var/lib/apt/lists/* \
  && rm -f /etc/localtime /etc/timezone \
  && cp -Lr /usr/share/zoneinfo/Asia/Chongqing /etc/localtime \
  && echo "Asia/Chongqing" >/etc/timezone

COPY --from=build /out/xlp /guest/xlp
COPY docker/entrypoint.sh /entrypoint.sh

RUN chmod +x /guest/xlp /entrypoint.sh \
  && mkdir -p \
    /guest/bin \
    /guest/dev \
    /guest/etc \
    /guest/lib \
    /guest/proc \
    /guest/run \
    /guest/sys \
    /guest/tmp \
    /guest/usr \
    /guest/var/packages \
    /guest/xunlei \
    /guest/usr/syno/synoman/webman/modules \
    /xunlei/data \
    /xunlei/downloads \
    /xunlei/var/packages/pan-xunlei-com

LABEL org.opencontainers.image.authors=cnk3x \
  org.opencontainers.image.source=https://github.com/cnk3x/xunlei \
  org.opencontainers.image.description="迅雷远程下载服务(非官方)" \
  org.opencontainers.image.licenses=MIT

ENV \
  XL_DASHBOARD_PORT=2345 \
  XL_DASHBOARD_IP= \
  XL_DASHBOARD_USERNAME= \
  XL_DASHBOARD_PASSWORD= \
  XL_DIR_DOWNLOAD=/xunlei/downloads \
  XL_DIR_DATA=/xunlei/data \
  XL_ROOT=/ \
  XL_PREVENT_UPDATE= \
  XL_UID= \
  XL_GID= \
  XL_DEBUG= \
  XL_SPK_URL=

VOLUME [ "/xunlei/data", "/xunlei/var/packages/pan-xunlei-com" ]
EXPOSE 2345

ENTRYPOINT [ "/entrypoint.sh" ]
