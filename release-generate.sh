#!/bin/sh
set -ex

DIR=$( dirname -- "$BASH_SOURCE" )
ENV_FILE="$DIR"/build.env

export REGISTRY_AUTH_FILE="$HOME"/.ghcr.io.json

export SOURCE_DATE_EPOCH=0

CUR_TIMESTAMP=$(date -I)
. "$ENV_FILE"
if [ "$TIMESTAMP" != "$CUR_TIMESTAMP" ]; then
    TIMESTAMP="$CUR_TIMESTAMP"
    BASE=$(skopeo inspect -f '{{.Name}}@{{.Digest}}' docker://cgr.dev/chainguard/wolfi-base:latest)
    BASE_ARM=$(skopeo --override-arch=arm64 inspect -f '{{.Name}}@{{.Digest}}' docker://cgr.dev/chainguard/wolfi-base:latest)
    RUST=$(skopeo inspect -f '{{.Name}}@{{.Digest}}' docker://docker.io/library/rust:latest)
    RUST_ARM=$(skopeo --override-arch=arm64 inspect -f '{{.Name}}@{{.Digest}}' docker://docker.io/library/rust:latest)
    GOLANG=$(skopeo inspect -f '{{.Name}}@{{.Digest}}' docker://cgr.dev/chainguard/go:latest)
    GCC=$(skopeo inspect -f '{{.Name}}@{{.Digest}}' docker://cgr.dev/chainguard/gcc-glibc:latest-dev)
    GCC_ARM=$(skopeo --override-arch=arm64 inspect -f '{{.Name}}@{{.Digest}}' docker://cgr.dev/chainguard/gcc-glibc:latest-dev)

    TOR_VERSION="0.4.8.16" # https://www.torproject.org/download/tor/ manually updated from here as required.

    echo TIMESTAMP="\"$TIMESTAMP\"" > "$ENV_FILE"
    echo BASE="\"$BASE\"" >> "$ENV_FILE"
    echo BASE_ARM="\"$BASE_ARM\"" >> "$ENV_FILE"
    echo RUST="\"$RUST\"" >> "$ENV_FILE"
    echo RUST_ARM="\"$RUST_ARM\"" >> "$ENV_FILE"
    echo GOLANG="\"$GOLANG\"" >> "$ENV_FILE"
    echo GCC="\"$GCC\"" >> "$ENV_FILE"
    echo GCC_ARM="\"$GCC_ARM\"" >> "$ENV_FILE"
    echo TOR_VERSION="\"$TOR_VERSION\"" >> "$ENV_FILE"
    (cd "$DIR"; git add "$ENV_FILE"; git commit -m "env update $TIMESTAMP"; git tag -a "v$TIMESTAMP" -m "Release for $TIMESTAMP")
fi

. "$DIR"/tor/lyrebird/build-lyrebird.sh

. "$DIR"/tor/tor-base/build-tor-base.sh

. "$DIR"/tor/arti/build-arti.sh

. "$DIR"/tor/snowflake-standalone/build-snowflake-standalone.sh

. "$DIR"/dohot/dnscrypt-proxy/build-dnscrypt-proxy.sh

#. "$DIR"/dohot/doh-proxy/build-doh-proxy.sh

lyrebird

arti

tor_base

# we leave this floating while we build arti and tor. no longer needed at this point.
buildah rm "$LYREBIRD"

snowflake_standalone

dnscrypt_proxy
