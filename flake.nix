{
	description = "cyberworm-uk container builds";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.05";
		flake-utils.url = "github:numtide/flake-utils";
	};

	outputs = { self, nixpkgs, flake-utils }:
		(flake-utils.lib.eachDefaultSystem (system:
			let
				pkgs = import nixpkgs {
					hostPlatform = system;
					buildPlatform = builtins.currentSystem;
				};
				arch = if nixpkgs.lib.strings.hasPrefix "aarch64" system then "arm64" else "amd64";
			in {
				packages = {
					arti = pkgs.dockerTools.buildLayeredImage {
						name = "arti";
						tag = "${arch}";
						architecture = "${arch}";
						contents = [
							pkgs.fakeNss
							(pkgs.writeTextDir "/etc/arti.toml" ''
								[proxy]
								socks_listen = "0.0.0.0:9050"
								[logging]
								console = "info"
								[storage]
								cache_dir = "/arti/cache"
								state_dir = "/arti/state"
								[address_filter]
								allow_onion_addrs = true
								[[bridges.transports]]
								protocols = ["meek_lite","obfs2","obfs3","obfs4","scramblesuit","webtunnel"]
								path = "${pkgs.obfs4}/bin/lyrebird"
								arguments = []
								run_on_startup = false
							'')
						];
						config = {
							User = "nobody";
							Volumes = {
								"/arti" = { };
							};
							Entrypoint = [ "${pkgs.arti}/bin/arti" "-c" "/etc/arti.toml" "proxy" ];
						};
					};
					tor-base = pkgs.dockerTools.buildLayeredImage {
						name = "tor-base";
						tag = "${arch}";
						architecture = "${arch}";
						contents = [
							pkgs.fakeNss
							(pkgs.writeTextDir "/etc/tor/torrc" ''
								User nobody
								DataDirectory /var/lib/tor
								AvoidDiskWrites 1
								ClientTransportPlugin meek_lite,obfs2,obfs3,obfs4,scramblesuit,webtunnel exec ${pkgs.obfs4}/bin/lyrebird
							'')
						];
						enableFakechroot = true;
						fakeRootCommands = ''
							mkdir -p /var/lib/tor
							chown nobody /var/lib/tor
						'';
						config = {
							Entrypoint = [ "${pkgs.tor}/bin/tor" "-f" "/etc/tor/torrc" ];
							Volumes = {
								"/var/lib/tor" = {};
							};
						};
					};
					tor-client = pkgs.dockerTools.buildLayeredImage {
						name = "tor-client";
						tag = "${arch}";
						architecture = "${arch}";
						contents = [
							pkgs.fakeNss
							(pkgs.writeTextDir "/etc/tor/torrc" ''
								User nobody
								DataDirectory /var/lib/tor
								AvoidDiskWrites 1
								ClientTransportPlugin meek_lite,obfs2,obfs3,obfs4,scramblesuit,webtunnel exec ${pkgs.obfs4}/bin/lyrebird
							'')
						];
						enableFakechroot = true;
						fakeRootCommands = ''
							mkdir -p /var/lib/tor
							chown nobody /var/lib/tor
						'';
						config = {
							Entrypoint = [ "${pkgs.tor}/bin/tor" "-f" "/etc/tor/torrc" "--socksport" "0.0.0.0:9050" ];
							Volumes = {
								"/var/lib/tor" = {};
							};
						};
					};
					tor-bridge-client = pkgs.dockerTools.buildLayeredImage {
						name = "tor-bridge-client";
						tag = "${arch}";
						architecture = "${arch}";
						contents = [
							pkgs.fakeNss
							(pkgs.writeTextDir "/etc/tor/torrc" ''
								User nobody
								DataDirectory /var/lib/tor
								AvoidDiskWrites 1
								ClientTransportPlugin meek_lite,obfs2,obfs3,obfs4,scramblesuit,webtunnel exec ${pkgs.obfs4}/bin/lyrebird
							'')
						];
						enableFakechroot = true;
						fakeRootCommands = ''
							mkdir -p /var/lib/tor
							chown nobody /var/lib/tor
						'';
						config = {
							Entrypoint = [ "${pkgs.tor}/bin/tor" "-f" "/etc/tor/torrc" "--socksport" "0.0.0.0:9050" "--usebridges" "1" ];
							Volumes = {
								"/var/lib/tor" = {};
							};
						};
					};
					tor-bridge-relay = pkgs.dockerTools.buildLayeredImage {
						name = "tor-bridge-relay";
						tag = "${arch}";
						architecture = "${arch}";
						contents = [
							pkgs.fakeNss
							(pkgs.writeTextDir "/etc/tor/torrc" ''
								User nobody
								DataDirectory /var/lib/tor
								AvoidDiskWrites 1
								ClientTransportPlugin meek_lite,obfs2,obfs3,obfs4,scramblesuit,webtunnel exec ${pkgs.obfs4}/bin/lyrebird
							'')
						];
						enableFakechroot = true;
						fakeRootCommands = ''
							mkdir -p /var/lib/tor
							chown nobody /var/lib/tor
						'';
						config = {
							Entrypoint = [ "${pkgs.tor}/bin/tor" "-f" "/etc/tor/torrc" "--servertransportplugin" "obfs4 exec ${pkgs.obfs4}/bin/lyrebird" "--extorport" "auto" "--servertransportlistenaddr" "obfs4 0.0.0.0:443" ];
							Volumes = {
								"/var/lib/tor" = {};
							};
						};
					};
					snowflake-standalone = pkgs.dockerTools.buildLayeredImage {
						name = "snowflake-standalone";
						tag = "${arch}";
						architecture = "${arch}";
						contents = [ pkgs.fakeNss ];
						config = {
							User = "nobody";
							Entrypoint = [ "${pkgs.snowflake}/bin/proxy" ];
						};
					};
					dnscrypt-proxy = pkgs.dockerTools.buildLayeredImage {
						name = "dnscrypt-proxy";
						tag = "${arch}";
						architecture = "${arch}";
						contents = [
							pkgs.fakeNss
							pkgs.cacert
							(pkgs.writeTextDir "/etc/dnscrypt-proxy/dnscrypt-proxy.toml" ''
								listen_addresses = ["0.0.0.0:5054"]
								disabled_server_names = []
								cert_refresh_delay = 60
								doh_servers = true
								ipv4_servers = false
								ipv6_servers = false
								dnscrypt_servers = false
								block_ipv6 = false
								block_unqualified = true
								block_undelegated = true
								require_nolog = false
								require_dnssec = true
								require_nofilter = true
								force_tcp = true
								proxy = "socks5://127.0.0.1:9050"
								timeout = 10000
								lb_strategy = "p2"
								log_level = 2
								use_syslog = true
								log_files_max_size = 64
								log_files_max_age = 7
								log_files_max_backups = 4
								tls_disable_session_tickets = true
								tls_cipher_suite = [
									52392,
									49199,
								]
								fallback_resolvers = [
									"1.1.1.1:53",
									"8.8.8.8:53",
								]
								netprobe_address = "8.8.8.8:53"
								netprobe_timeout = 60
								ignore_system_dns = true
								cache = true
								cache_size = 4096
								cache_min_ttl = 2400
								cache_max_ttl = 86400
								cache_neg_min_ttl = 60
								cache_neg_max_ttl = 600
								[query_log]
								file = "/var/log/dnscrypt-proxy/query.log"
								[nx_log]
								file = "/var/log/dnscrypt-proxy/nx.log"
								[sources.public-resolvers]
								urls = [
										"https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md",
										"https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md",
								]
								minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"
								cache_file = "public-resolvers.md"
								[sources.onion-services]
								urls = [
										"https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/onion-services.md",
										"https://download.dnscrypt.info/resolvers-list/v3/onion-services.md",
								]
								minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"
								cache_file = "onion-services.md"
							'')
						];
						config = {
							User = "nobody";
							Entrypoint = [ "${pkgs.dnscrypt-proxy}/bin/dnscrypt-proxy" "-config" "/etc/dnscrypt-proxy/dnscrypt-proxy.toml" ];
						};
					};
					doh-proxy = pkgs.dockerTools.buildLayeredImage {
						name = "doh-proxy";
						tag = "${arch}";
						architecture = "${arch}";
						contents = [ pkgs.fakeNss pkgs.cacert ];
						config = {
							User = "nobody";
							Entrypoint = [ "${pkgs.doh-proxy-rust}/bin/doh-proxy" ];
						};
					};
				};
			}
		));
}
