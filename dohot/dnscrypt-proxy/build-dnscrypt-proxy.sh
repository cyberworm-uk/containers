#!/bin/sh

dnscrypt_proxy() {
    # DNSCrypt-Proxy version (branch) to build.
    VERSION="2.1.7"
    # Go build container, Base container(s) for final image.
    build=$(buildah from "$GOLANG")    
    final=$(buildah from --platform linux/amd64 "$BASE")
    final_arm=$(buildah from --platform linux/arm64 "$BASE_ARM")
    # Fetch DNSCrypt-Proxy
    buildah run "$build" -- \
        git clone --depth=1 --branch="$VERSION" https://github.com/DNSCrypt/dnscrypt-proxy.git
    # Download go modules
    buildah run --mount type=cache,target=/go/pkg --workingdir /dnscrypt-proxy "$build" -- \
        go mod download
    # Build AMD64
    buildah run --env SOURCE_DATE_EPOCH=0 --env GOARCH=amd64 --mount type=cache,target=/go/pkg --mount type=cache,target=/root/.cache/go-build --workingdir /dnscrypt-proxy "$build" -- \
        go build -ldflags '-w -s -buildid=' -o /dnscrypt-proxy.amd64 ./dnscrypt-proxy
    # Build ARM64
    buildah run --env SOURCE_DATE_EPOCH=0 --env GOARCH=arm64 --mount type=cache,target=/go/pkg --mount type=cache,target=/root/.cache/go-build --workingdir /dnscrypt-proxy "$build" -- \
        go build -ldflags '-w -s -buildid=' -o /dnscrypt-proxy.arm64 ./dnscrypt-proxy

    # Create required directories for DNSCrypt-Proxy at runtime
    buildah run "$final" -- \
        mkdir -p /etc/dnscrypt-proxy/ /var/log/dnscrypt-proxy/
    buildah run "$final" -- \
        chown nonroot:nonroot /var/log/dnscrypt-proxy/
    buildah run "$final_arm" -- \
        mkdir -p /etc/dnscrypt-proxy/ /var/log/dnscrypt-proxy/
    buildah run "$final_arm" -- \
        chown nonroot:nonroot /var/log/dnscrypt-proxy/

    # List of artifacts we're adding to the image, we want to remove their filesystem timestamps.
    artifacts=(/etc/dnscrypt-proxy/ /etc/dnscrypt-proxy/dnscrypt-proxy.toml /var/log/dnscrypt-proxy/ /usr/bin/dnscrypt-proxy)

    # Mount filesystems
    mntbuild=$(buildah mount "$build")
    mntfinal=$(buildah mount "$final")
    mntfinal_arm=$(buildah mount "$final_arm")

    # Move files from build and local storage to final images.
    cp "$mntbuild/dnscrypt-proxy.amd64" "$mntfinal/usr/bin/dnscrypt-proxy"
    cp "$mntbuild/dnscrypt-proxy.arm64" "$mntfinal_arm/usr/bin/dnscrypt-proxy"
    cp ./dohot/dnscrypt-proxy/dnscrypt-proxy.toml "$mntfinal/etc/dnscrypt-proxy/"
    cp ./dohot/dnscrypt-proxy/dnscrypt-proxy.toml "$mntfinal_arm/etc/dnscrypt-proxy/"

    # Reset all our artifacts timestamps.
    for artifact in ${artifacts[@]}; do
        touch --date=@0 "${mntfinal}${artifact}"
        touch --date=@0 "${mntfinal_arm}${artifact}"
    done

    # Unmount filesystems.
    buildah umount "$build"
    buildah umount "$final"
    buildah umount "$final_arm"

    # Remove the build container
    buildah rm "$build"

    # Configure the final images.
    buildah config \
        --user nonroot \
        --volume /var/log/dnscrypt-proxy \
        --port 5054 \
        --entrypoint '["/usr/bin/dnscrypt-proxy","-config", "/etc/dnscrypt-proxy/dnscrypt-proxy.toml"]' \
        --cmd '' \
        "$final"

    buildah config \
        --user nonroot \
        --volume /var/log/dnscrypt-proxy \
        --port 5054 \
        --entrypoint '["/usr/bin/dnscrypt-proxy","-config", "/etc/dnscrypt-proxy/dnscrypt-proxy.toml"]' \
        --cmd '' \
        "$final_arm"

    # Remove existing duplicate
    buildah manifest exists ghcr.io/cyberworm-uk/dnscrypt-proxy:"$TIMESTAMP" && buildah manifest rm ghcr.io/cyberworm-uk/dnscrypt-proxy:"$TIMESTAMP"
    # Create manifest for arch builds
    buildah manifest create ghcr.io/cyberworm-uk/dnscrypt-proxy:"$TIMESTAMP"

    # Commit, omitting timestamps
    buildah commit --omit-timestamp --manifest ghcr.io/cyberworm-uk/dnscrypt-proxy:"$TIMESTAMP" "$final"
    buildah commit --omit-timestamp --manifest ghcr.io/cyberworm-uk/dnscrypt-proxy:"$TIMESTAMP" "$final_arm"

    # Remove final container
    buildah rm "$final"
    buildah rm "$final_arm"

    buildah manifest push --all ghcr.io/cyberworm-uk/dnscrypt-proxy:"$TIMESTAMP" docker://ghcr.io/cyberworm-uk/dnscrypt-proxy:"$TIMESTAMP"
    buildah manifest push --all ghcr.io/cyberworm-uk/dnscrypt-proxy:"$TIMESTAMP" docker://ghcr.io/cyberworm-uk/dnscrypt-proxy:latest
}