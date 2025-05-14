#!/bin/sh

lyrebird() {
    build=$(buildah from "$GOLANG")
    final=$(buildah from scratch)

    buildah run "$build" -- \
        git clone --depth=1 --branch=main https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird.git
    buildah run --mount type=cache,target=/go/pkg --workingdir /lyrebird "$build" -- \
        go mod download
    buildah run --env SOURCE_DATE_EPOCH=0 --env GOARCH=amd64 --mount type=cache,target=/go/pkg --mount type=cache,target=/root/.cache/go-build --workingdir /lyrebird "$build" -- \
        go build -ldflags '-w -s -buildid=' -o /lyrebird.amd64 ./cmd/lyrebird
    buildah run --env SOURCE_DATE_EPOCH=0 --env GOARCH=arm64 --mount type=cache,target=/go/pkg --mount type=cache,target=/root/.cache/go-build --workingdir /lyrebird "$build" -- \
        go build -ldflags '-w -s -buildid=' -o /lyrebird.arm64 ./cmd/lyrebird

    mntfinal=$(buildah mount "$final")
    mntbuild=$(buildah mount "$build")

    artifacts=(/lyrebird.amd64 /lyrebird.arm64)

    cp "$mntbuild/lyrebird.amd64" "$mntfinal/lyrebird.amd64"
    cp "$mntbuild/lyrebird.arm64" "$mntfinal/lyrebird.arm64"

    for artifact in ${artifacts[@]}; do
        touch --date=@0 "${mntfinal}${artifact}"
    done

    buildah umount "$build"
    buildah umount "$final"

    buildah rm "$build"

    LYREBIRD="$final"
}