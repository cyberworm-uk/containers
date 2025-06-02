{ pkgs ? import <nixpkgs> { }, arch ? "amd64" }:

let
	cpkgs = if arch == "arm64" then (import <nixpkgs> { }).pkgsCross.aarch64-multiplatform else (import <nixpkgs> { });
	artiToml = pkgs.writeTextDir "/etc/arti.toml" ''
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
		path = "${cpkgs.obfs4}/bin/lyrebird"
		arguments = []
		run_on_startup = false
	'';

in pkgs.dockerTools.buildLayeredImage {
	name = "arti";
	tag = "${arch}";
	architecture = "${arch}";
	contents = [ pkgs.fakeNss artiToml ];
	config = {
		User = "nobody";
		Volumes = {
			"/arti" = { };
		};
		Entrypoint = [ "${cpkgs.arti}/bin/arti" "-c" "/etc/arti.toml" "proxy" ];
	};
}
