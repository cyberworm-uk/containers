{ pkgs ? import <nixpkgs> { }, arch ? "amd64" }:

let
	cpkgs = if arch == "arm64" then (import <nixpkgs> { }).pkgsCross.aarch64-multiplatform else pkgs;
	dnscryptProxyToml = pkgs.writeTextDir "/etc/dnscrypt-proxy/dnscrypt-proxy.toml" ''
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
	'';

in pkgs.dockerTools.buildLayeredImage {
	name = "dnscrypt-proxy";
	tag = "${arch}";
	architecture = "${arch}";
	contents = [ cpkgs.fakeNss cpkgs.cacert dnscryptProxyToml ];
	config = {
		User = "nobody";
		Entrypoint = [ "${cpkgs.dnscrypt-proxy}/bin/dnscrypt-proxy" "-config" "/etc/dnscrypt-proxy/dnscrypt-proxy.toml" ];
	};
}
