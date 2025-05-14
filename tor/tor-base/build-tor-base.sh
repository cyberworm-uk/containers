#!/bin/sh

get_tor() {
    if [[ ! -f tor-"$TOR_VERSION".tar.gz ]]; then
        wget https://dist.torproject.org/tor-"$TOR_VERSION".tar.gz{,.sha256sum}
    fi
    sha256sum -c tor-"$TOR_VERSION".tar.gz.sha256sum
}

tor_base() {
    get_tor

    build=$(buildah from --platform linux/amd64 "$GCC")
    build_arm=$(buildah from --platform linux/arm64 "$GCC_ARM")

    mntbuild=$(buildah mount "$build")
    mntbuild_arm=$(buildah mount "$build_arm")

    tar -C "$mntbuild"/work -zxf tor-"$TOR_VERSION".tar.gz
    tar -C "$mntbuild_arm"/work -zxf tor-"$TOR_VERSION".tar.gz

    buildah run "$build" -- \
        apk add libevent-dev openssl-dev zlib-dev
    buildah run --env SOURCE_DATE_EPOCH=0 --workingdir /work/tor-"$TOR_VERSION" "$build" -- \
        ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --enable-gpl
    buildah run --env SOURCE_DATE_EPOCH=0 --workingdir /work/tor-"$TOR_VERSION" "$build" -- \
        make -j$(nproc)
    buildah run "$build_arm" -- \
        apk add libevent-dev openssl-dev zlib-dev
    buildah run --env SOURCE_DATE_EPOCH=0 --workingdir /work/tor-"$TOR_VERSION" "$build_arm" -- \
        ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --enable-gpl
    buildah run --env SOURCE_DATE_EPOCH=0 --workingdir /work/tor-"$TOR_VERSION" "$build_arm" -- \
        make -j$(nproc)

    final=$(buildah from --platform linux/amd64 "$BASE")
    final_arm=$(buildah from --platform linux/arm64 "$BASE_ARM")

    buildah run --mount type=cache,target=/var/cache/apk "$final" -- \
        mkdir -p /etc/tor /var/lib/tor
    buildah run --mount type=cache,target=/var/cache/apk "$final" -- \
        chown nonroot:nonroot /var/lib/tor
    buildah run --mount type=cache,target=/var/cache/apk "$final_arm" -- \
        mkdir -p /etc/tor /var/lib/tor
    buildah run --mount type=cache,target=/var/cache/apk "$final_arm" -- \
        chown nonroot:nonroot /var/lib/tor

    buildah run "$final" -- \
        apk add --no-cache --no-scripts --no-commit-hooks libevent
    buildah run "$final_arm" -- \
        apk add --no-cache --no-scripts --no-commit-hooks libevent

    mntfinal=$(buildah mount "$final")
    mntfinal_arm=$(buildah mount "$final_arm")
    mntlyrebird=$(buildah mount "$LYREBIRD")

    artifacts=(/etc/tor /etc/tor/torrc-defaults /etc/tor/geoip /etc/tor/geoip6 /usr/bin/lyrebird /usr/bin/tor /var/lib/tor)

    cp ./tor/tor-base/torrc "$mntfinal"/etc/tor/torrc-defaults
    cp ./tor/tor-base/torrc "$mntfinal_arm"/etc/tor/torrc-defaults

    cp "$mntlyrebird"/lyrebird.amd64 "$mntfinal"/usr/bin/lyrebird
    cp "$mntlyrebird/lyrebird.arm64" "$mntfinal_arm/usr/bin/lyrebird"

    cp "$mntbuild"/work/tor-"$TOR_VERSION"/src/app/tor "$mntfinal"/usr/bin/tor
    cp "$mntbuild_arm"/work/tor-"$TOR_VERSION"/src/app/tor "$mntfinal_arm"/usr/bin/tor
    cp "$mntbuild"/work/tor-"$TOR_VERSION"/src/config/geoip "$mntfinal"/etc/tor/geoip
    cp "$mntbuild"/work/tor-"$TOR_VERSION"/src/config/geoip6 "$mntfinal"/etc/tor/geoip6
    cp "$mntbuild"/work/tor-"$TOR_VERSION"/src/config/geoip "$mntfinal_arm"/etc/tor/geoip
    cp "$mntbuild"/work/tor-"$TOR_VERSION"/src/config/geoip6 "$mntfinal_arm"/etc/tor/geoip6

    for artifact in ${artifacts[@]}; do
        touch --date=@0 "${mntfinal}${artifact}"
        touch --date=@0 "${mntfinal_arm}${artifact}"
    done

    buildah umount "$LYREBIRD"
    buildah umount "$final"
    buildah umount "$final_arm"

    buildah config \
        --volume /var/lib/tor \
        --entrypoint '["/usr/bin/tor"]' \
        --cmd '' \
        "$final"

    buildah config \
        --volume /var/lib/tor \
        --entrypoint '["/usr/bin/tor"]' \
        --cmd '' \
        "$final_arm"

    # Remove existing duplicate
    buildah manifest exists ghcr.io/cyberworm-uk/tor-base:"$TIMESTAMP" && buildah manifest rm ghcr.io/cyberworm-uk/tor-base:"$TIMESTAMP"
    # Create manifest for arch builds
    buildah manifest create ghcr.io/cyberworm-uk/tor-base:"$TIMESTAMP"

    # Commit, omitting timestamps
    buildah commit --omit-timestamp --manifest ghcr.io/cyberworm-uk/tor-base:"$TIMESTAMP" "$final"
    buildah commit --omit-timestamp --manifest ghcr.io/cyberworm-uk/tor-base:"$TIMESTAMP" "$final_arm"

    buildah manifest push --all ghcr.io/cyberworm-uk/tor-base:"$TIMESTAMP" docker://ghcr.io/cyberworm-uk/tor-base:"$TIMESTAMP"
    buildah manifest push --all ghcr.io/cyberworm-uk/tor-base:"$TIMESTAMP" docker://ghcr.io/cyberworm-uk/tor-base:latest

    ### Configure and push "tor-client"

    buildah config \
        --volume /var/lib/tor \
        --port 9050 \
        --entrypoint '["/usr/bin/tor","--socksport","0.0.0.0:9050"]' \
        --cmd '' \
        "$final"

    buildah config \
        --volume /var/lib/tor \
        --port 9050 \
        --entrypoint '["/usr/bin/tor","--socksport","0.0.0.0:9050"]' \
        --cmd '' \
        "$final_arm"
    
    # Create manifest, replacing if required
    buildah manifest exists ghcr.io/cyberworm-uk/tor-client:"$TIMESTAMP" && buildah manifest rm ghcr.io/cyberworm-uk/tor-client:"$TIMESTAMP"
    buildah manifest create ghcr.io/cyberworm-uk/tor-client:"$TIMESTAMP"

    # Commit working containers to images in the manifest
    buildah commit --omit-timestamp --manifest ghcr.io/cyberworm-uk/tor-client:"$TIMESTAMP" "$final"
    buildah commit --omit-timestamp --manifest ghcr.io/cyberworm-uk/tor-client:"$TIMESTAMP" "$final_arm"

    buildah manifest push --all ghcr.io/cyberworm-uk/tor-client:"$TIMESTAMP" docker://ghcr.io/cyberworm-uk/tor-client:"$TIMESTAMP"
    buildah manifest push --all ghcr.io/cyberworm-uk/tor-client:"$TIMESTAMP" docker://ghcr.io/cyberworm-uk/tor-client:latest

    ### Configure and push tor-bridge-client

    buildah config \
        --volume /var/lib/tor \
        --port 9050 \
        --entrypoint '["/usr/bin/tor","--socksport","0.0.0.0:9050","--usebridges","1"]' \
        --cmd '' \
        "$final"

    buildah config \
        --volume /var/lib/tor \
        --port 9050 \
        --entrypoint '["/usr/bin/tor","--socksport","0.0.0.0:9050","--usebridges","1"]' \
        --cmd '' \
        "$final_arm"
    
    # Remove existing duplicate
    buildah manifest exists ghcr.io/cyberworm-uk/tor-bridge-client:"$TIMESTAMP" && buildah manifest rm ghcr.io/cyberworm-uk/tor-bridge-client:"$TIMESTAMP"
    # Create manifest for arch builds
    buildah manifest create ghcr.io/cyberworm-uk/tor-bridge-client:"$TIMESTAMP"

    # Commit, omitting timestamps
    buildah commit --omit-timestamp --manifest ghcr.io/cyberworm-uk/tor-bridge-client:"$TIMESTAMP" "$final"
    buildah commit --omit-timestamp --manifest ghcr.io/cyberworm-uk/tor-bridge-client:"$TIMESTAMP" "$final_arm"

    buildah manifest push --all ghcr.io/cyberworm-uk/tor-bridge-client:"$TIMESTAMP" docker://ghcr.io/cyberworm-uk/tor-bridge-client:"$TIMESTAMP"
    buildah manifest push --all ghcr.io/cyberworm-uk/tor-bridge-client:"$TIMESTAMP" docker://ghcr.io/cyberworm-uk/tor-bridge-client:latest

    ### Configure and push tor-bridge-relay

    buildah config \
        --volume /var/lib/tor \
        --port 443 \
        --entrypoint '["/usr/bin/tor","--servertransportplugin","obfs4 exec /usr/bin/lyrebird","--extorport","auto","--servertransportlistenaddr","obfs4 0.0.0.0:443"]' \
        --cmd '' \
        "$final"

    buildah config \
        --volume /var/lib/tor \
        --port 443 \
        --entrypoint '["/usr/bin/tor","--servertransportplugin","obfs4 exec /usr/bin/lyrebird","--extorport","auto","--servertransportlistenaddr","obfs4 0.0.0.0:443"]' \
        --cmd '' \
        "$final_arm"
    
    # Remove existing duplicate
    buildah manifest exists ghcr.io/cyberworm-uk/tor-bridge-relay:"$TIMESTAMP" && buildah manifest rm ghcr.io/cyberworm-uk/tor-bridge-relay:"$TIMESTAMP"
    # Create manifest for arch builds
    buildah manifest create ghcr.io/cyberworm-uk/tor-bridge-relay:"$TIMESTAMP"

    # Commit, omitting timestamps
    buildah commit --omit-timestamp --manifest ghcr.io/cyberworm-uk/tor-bridge-relay:"$TIMESTAMP" "$final"
    buildah commit --omit-timestamp --manifest ghcr.io/cyberworm-uk/tor-bridge-relay:"$TIMESTAMP" "$final_arm"

    buildah rm "$final"
    buildah rm "$final_arm"

    buildah manifest push --all ghcr.io/cyberworm-uk/tor-bridge-relay:"$TIMESTAMP" docker://ghcr.io/cyberworm-uk/tor-bridge-relay:"$TIMESTAMP"
    buildah manifest push --all ghcr.io/cyberworm-uk/tor-bridge-relay:"$TIMESTAMP" docker://ghcr.io/cyberworm-uk/tor-bridge-relay:latest
}