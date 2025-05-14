#!/bin/sh

snowflake_standalone() {
    build=$(buildah from "$GOLANG")
    final=$(buildah from  --platform linux/amd64 "$BASE")
    final_arm=$(buildah from  --platform linux/arm64 "$BASE_ARM")

    buildah run "$build" -- \
        git clone --depth=1 --branch=main https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake.git
    buildah run --mount type=cache,target=/go/pkg --workingdir /snowflake "$build" -- \
        go mod download
    buildah run --env SOURCE_DATE_EPOCH=0 --env GOARCH=amd64 --mount type=cache,target=/go/pkg --mount type=cache,target=/root/.cache/go-build --workingdir /snowflake "$build" -- \
        go build -ldflags '-w -s -buildid=' -o /proxy.amd64 ./proxy
    buildah run --env SOURCE_DATE_EPOCH=0 --env GOARCH=arm64 --mount type=cache,target=/go/pkg --mount type=cache,target=/root/.cache/go-build --workingdir /snowflake "$build" -- \
        go build -ldflags '-w -s -buildid=' -o /proxy.arm64 ./proxy

    mntfinal=$(buildah mount "$final")
    mntfinal_arm=$(buildah mount "$final_arm")
    mntbuild=$(buildah mount "$build")

    cp "$mntbuild"/proxy.amd64 "$mntfinal"/usr/bin/proxy
    cp "$mntbuild"/proxy.arm64 "$mntfinal_arm"/usr/bin/proxy

    artifacts=(/usr/bin/proxy)
    for artifact in ${artifacts[@]}; do
        touch --date=@0 "${mntfinal}${artifact}"
        touch --date=@0 "${mntfinal_arm}${artifact}"
    done

    buildah umount "$build"
    buildah umount "$final"
    buildah umount "$final_arm"

    buildah rm "$build"

    buildah config \
        --entrypoint '["/usr/bin/proxy"]' \
        --cmd '' \
        "$final"

    buildah config \
        --entrypoint '["/usr/bin/proxy"]' \
        --cmd '' \
        "$final_arm"

    # Remove existing duplicate
    buildah manifest exists ghcr.io/cyberworm-uk/snowflake-standalone:"$TIMESTAMP" && buildah manifest rm ghcr.io/cyberworm-uk/snowflake-standalone:"$TIMESTAMP"
    # Create manifest for arch builds
    buildah manifest create ghcr.io/cyberworm-uk/snowflake-standalone:"$TIMESTAMP"

    # Commit, omitting timestamps
    buildah commit --omit-timestamp --manifest ghcr.io/cyberworm-uk/snowflake-standalone:"$TIMESTAMP" "$final"
    buildah commit --omit-timestamp --manifest ghcr.io/cyberworm-uk/snowflake-standalone:"$TIMESTAMP" "$final_arm"

    buildah rm "$final"
    buildah rm "$final_arm"

    buildah manifest push --all ghcr.io/cyberworm-uk/snowflake-standalone:"$TIMESTAMP" docker://ghcr.io/cyberworm-uk/snowflake-standalone:"$TIMESTAMP"
    buildah manifest push --all ghcr.io/cyberworm-uk/snowflake-standalone:"$TIMESTAMP" docker://ghcr.io/cyberworm-uk/snowflake-standalone:latest
}