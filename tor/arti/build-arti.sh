#!/bin/sh

# rust target aarch64-unknown-linux-gnu

arti() {
    build=$(buildah from --platform linux/amd64 "$RUST")
    build_arm=$(buildah from --platform linux/arm64 "$RUST_ARM")
    final=$(buildah from --platform linux/amd64 "$BASE")
    final_arm=$(buildah from --platform linux/arm64 "$BASE_ARM")

    buildah run --env SOURCE_DATE_EPOCH=0 "$build" -- \
        cargo install --locked --features=full arti
    buildah run --env SOURCE_DATE_EPOCH=0 "$build_arm" -- \
        cargo install --locked --features=full arti

    mntbuild=$(buildah mount "$build")
    mntbuild_arm=$(buildah mount "$build_arm")
    mntfinal=$(buildah mount "$final")
    mntfinal_arm=$(buildah mount "$final_arm")
    mntbin=$(buildah mount "$LYREBIRD")

    artifacts=(/usr/bin/arti /arti /arti/config /arti/config/arti /arti/config/arti/arti.toml /usr/bin/lyrebird)

    cp "$mntbuild/usr/local/cargo/bin/arti" "$mntfinal/usr/bin/arti"
    cp "$mntbuild_arm/usr/local/cargo/bin/arti" "$mntfinal_arm/usr/bin/arti"
    cp "$mntbin/lyrebird.amd64" "$mntfinal/usr/bin/lyrebird"
    cp "$mntbin/lyrebird.arm64" "$mntfinal_arm/usr/bin/lyrebird"

    buildah umount "$build"
    buildah rm "$build"
    buildah umount "$build_arm"
    buildah rm "$build_arm"
    buildah umount "$LYREBIRD"

    buildah run "$final" -- \
        apk --no-cache --no-interactive add xz-dev sqlite-libs libgcc
    buildah run "$final_arm" -- \
        apk --no-cache --no-interactive add xz-dev sqlite-libs libgcc
    buildah run "$final" -- \
        addgroup -S arti
    buildah run "$final_arm" -- \
        addgroup -S arti
    buildah run "$final" -- \
        adduser -h /arti -S arti -G arti
    buildah run "$final_arm" -- \
        adduser -h /arti -S arti -G arti
    buildah run --user arti:arti "$final" -- \
        mkdir -p /arti/config/arti/
    buildah run --user arti:arti "$final_arm" -- \
        mkdir -p /arti/config/arti/

    cp ./tor/arti/arti.toml "$mntfinal/arti/config/arti/"
    cp ./tor/arti/arti.toml "$mntfinal_arm/arti/config/arti/"

    for artifact in ${artifacts[@]}; do
        touch --date=@0 "${mntfinal}${artifact}"
        touch --date=@0 "${mntfinal_arm}${artifact}"
    done

    buildah umount "$final"
    buildah umount "$final_arm"

    buildah config \
        --env "XDG_CONFIG_HOME=/arti/config" \
        --env "XDG_DATA_HOME=/arti/data" \
        --user arti \
        --volume /arti \
        --port 9050 \
        --entrypoint '["/usr/bin/arti","proxy"]' \
        --cmd '' \
        "$final"

    buildah config \
        --env "XDG_CONFIG_HOME=/arti/config" \
        --env "XDG_DATA_HOME=/arti/data" \
        --user arti \
        --volume /arti \
        --port 9050 \
        --entrypoint '["/usr/bin/arti","proxy"]' \
        --cmd '' \
        "$final_arm"

    # Remove existing duplicate
    buildah manifest exists ghcr.io/cyberworm-uk/arti:"$TIMESTAMP" && buildah manifest rm ghcr.io/cyberworm-uk/arti:"$TIMESTAMP"
    # Create manifest for arch builds
    buildah manifest create ghcr.io/cyberworm-uk/arti:"$TIMESTAMP"

    # Commit, omitting timestamps
    buildah commit --omit-timestamp --manifest ghcr.io/cyberworm-uk/arti:"$TIMESTAMP" "$final"
    buildah commit --omit-timestamp --manifest ghcr.io/cyberworm-uk/arti:"$TIMESTAMP" "$final_arm"

    # Remove final container
    buildah rm "$final"
    buildah rm "$final_arm"

    buildah manifest push --all ghcr.io/cyberworm-uk/arti:"$TIMESTAMP" docker://ghcr.io/cyberworm-uk/arti:"$TIMESTAMP"
    buildah manifest push --all ghcr.io/cyberworm-uk/arti:"$TIMESTAMP" docker://ghcr.io/cyberworm-uk/arti:latest
}