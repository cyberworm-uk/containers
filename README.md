# Moved

As github continues on it's intractable road to AI enshittification and LLM waste,

I've moved active development and maintenance to [Codeberg](https://codeberg.org/cyberworm-uk/containers).

The `ghcr.io` images will no longer be updated, and can be replaced with `codeberg.org` equivalents.

I've updated this documentation to reflect the new home of the images.

## Container Image Documentation

- [tor-base](#tor-base) an image which serves as a common base that more complete images are build on.
- [tor-client](#tor-client) an image for a regular Tor proxy (client) image.
- [tor-bridge-client](#tor-bridge-client) an image for a Tor proxy (client) connecting over meek_lite, obfs2, obfs3, obfs4, scramblesuit, snowflake and webtunnel.
- [tor-bridge-relay](#tor-bridge-relay) an image for a Tor bridge (server) allowing clients to connect into the Tor network over obfs4.
- [snowflake-standalone](#snowflake-standalone) an image for a snowflake entrypoint, serves as a go between for snowflake clients and snowflake bridges.
- [arti](#arti) an image for an in-development, experimental Tor implementation in Rust.
- [onion service](#onion-service) example of a basic onion service running with containers.
- [dnscrypt-proxy](#dnscrypt-proxy) the dnscrypt-proxy image for [dohot](https://github.com/cyberworm-uk/dohot-service), pre-configured for that specific purpose.
- [doh-proxy](#doh-proxy) an *optional* [doh-proxy](https://github.com/DNSCrypt/doh-server) component for anyone wanting to stand up their own DOH as a front to [dohot](https://github.com/cyberworm-uk/dohot-service).

## tor-base
Base tor image, just alpine with tor.
```bash
# pick an ORPort for your relay.
ORPORT=$[ (${RANDOM} % (65536-1024)) + 1024 ]
# keep long term data in a persistent container volume (*very* important for relay identity keys, etc)
podman volume create tor-datadir
# launch the relay
podman run \
  -d \
  --rm \
  --name tor-relay \
  -v tor-datadir:/var/lib/tor \
  -p ${ORPORT}:${ORPORT} \
  codeberg.org/cyberworm-uk/tor-base:latest \
  --orport ${ORPORT} \
  --nickname myrelay \
  --contactinfo myemail@mydomain.com
```

## tor-client
Tor proxy (client). **N.B.** binds to 0.0.0.0 inside the container, to allow for use in inter-container networking or exposure by publishing, do *not* use with host networking.
```bash
# keep long term data in a persistent container volume (important for guard context, descriptor caches, etc)
podman volume create tor-datadir
# launch the proxy, should be accessible as a SOCKS5 proxy at 127.0.0.1:9050 on the host.
podman run \
  -d \
  --rm \
  --name torproxy \
  -v tor-datadir:/var/lib/tor \
  -p 127.0.0.1:9050:9050 \
  codeberg.org/cyberworm-uk/tor-client:latest
# test the tor connection
(curl -x socks5h://127.0.0.1:9050/ https://check.torproject.org | grep -F Congratulations.) && echo "Success" || echo "Failure"
```

## tor-bridge-client
Tor proxy (client) configured to use meek_lite, obfs2, obfs3, obfs4, scramblesuit, snowflake and webtunnel bridges. See notes for `torproxy` above.
```bash
# keep long term data in a persistent container volume (important for guard context, descriptor caches, etc)
podman volume create tor-datadir
# n.b. the argument following --bridge should be the obfs4 bridge line you obtained via https://bridges.torproject.org/ and it should be in quotes.
podman run \
  -d \
  --rm \
  --name obfs4-proxy \
  -p 127.0.0.1:9050:9050 \
  -v tor-datadir:/var/lib/tor \
  codeberg.org/cyberworm-uk/tor-bridge-client:latest --bridge "obfs4 10.20.30.40:12345 3D7D7A39CCA78C7B0448AFA147EF4CC391564D03 cert=YvJSxrXcnXYZ+C9hsIr18bwsm5u5dtZG9DrLTo8CqY8mZlBjhXcUssJJ185mX+JCc/LSnQ iat-mode=0"
# test the tor connection
(curl -x socks5h://127.0.0.1:9050/ https://check.torproject.org | grep -F Congratulations.) && echo "Success" || echo "Failure"
```

## tor-bridge-relay
Tor bridge (server) with obfs4 listening on port 443d. Changing the obfs4 port for 443 is possible but would require some knowledge of containers, see the `Containerfile` to crib the existing `ENTRYPOINT`. Can be overridden with your own `--entrypoint` argument to `podman run ...`, the `--servertransportlistenaddr` argument is where the changed should be made.
```bash
# pick a random ORPort value to make bridge detection more expensive for censors.
ORPORT=$[ (${RANDOM} % (65536-1024)) + 1024 ]
# keep long term data in a persistent container volume (*very* important for bridge identity keys, etc)
podman volume create tor-datadir
# start the bridge
podman run \
  -d \
  --rm \
  --name obfs4-bridge \
  -p 443:443 \
  -p ${ORPORT}:${ORPORT} \
  -v tor-datadir:/var/lib/tor \
  codeberg.org/cyberworm-uk/tor-bridge-relay:latest \
  --contactinfo myemail@mydomain.com \
  --orport ${ORPORT} \
  --nickname myrelay
# check the logs to ensure the bridge is published correctly, etc
podman logs -f 
```

## snowflake-standalone
A standalone snowflake proxy, this acts as an entrypoint for other users who intend to use a snowflake client to access Tor.
```bash
# host networking is prefered, to avoid another layer of NAT traversal: container <-(NAT)-> host, or worse: container <-(NAT)-> host <-(NAT)-> router
podman run \
  -d \
  --rm \
  --name snowflake \
  --network host \
  codeberg.org/cyberworm-uk/snowflake-standalone:latest
```

## arti
An in-development, experimental rust implementation of Tor.
```bash
# create arti state storage
podman volume create arti-data
# run arti
podman run \
  -d \
  --rm \
  --name arti \
  -v arti-data:/arti \
  -p 127.0.0.1:9050:9050 \
  codeberg.org/cyberworm-uk/arti:latest
```

Additional config snippets can be mounted under `/arti/config/arti/arti.d/`

Should be configured to use bridges and pluggable transports out-of-the-box, e.g.

```bash
podman run \
  -d \
  --rm \
  --name arti \
  -v arti-data:/arti \
  -p 127.0.0.1:9050:9050 \
  codeberg.org/cyberworm-uk/arti:latest \
  -o 'bridges.bridges=["obfs4 1.2.3.4:1234 AA...snip..BB cert=b...snip...g iat-mode=0","obfs4 5.6.7.8:5678 CC...snip...DD cert=T...snip...w iat-mode=0"]'
```

Note the slightly awkward format here where we're wrapping the entire argument in single quotes to ensure the double quotes are passed to the option parser in arti and if you're supplying multiple bridges addresses they should be individually double quoted and then comma separated.

## dnscrypt-proxy
This is built for a specific purpose, with a purpose built config file.
If you wish to repurpose it (you probably shouldn't) you'll want to mount your own config file into the container at `/etc/dnscrypt-proxy/dnscrypt-proxy.toml`.

## doh-proxy
Optional, can be configured with additional arguments. e.g.

```bash
podman run \
  -d \
  --rm \
  --name doh-proxy \
  -p 127.0.0.1:3000:3000 \
  codeberg.org/cyberworm-uk/doh-proxy:latest \
  -l 0.0.0.0:3000
```
