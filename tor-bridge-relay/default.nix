{ pkgs ? import <nixpkgs> { }, arch ? "amd64" }:

let
	cpkgs = if arch == "arm64" then (import <nixpkgs> { }).pkgsCross.aarch64-multiplatform else (import <nixpkgs> { });
	torrc = pkgs.writeTextDir "/etc/tor/torrc" ''
		User nobody
		DataDirectory /var/lib/tor
		AvoidDiskWrites 1
		ClientTransportPlugin meek_lite,obfs2,obfs3,obfs4,scramblesuit,webtunnel exec ${cpkgs.obfs4}/bin/lyrebird
	'';


in pkgs.dockerTools.buildLayeredImage {
	name = "tor-bridge-relay";
	tag = "${arch}";
	architecture = "${arch}";
	contents = [ cpkgs.fakeNss torrc ];
	enableFakechroot = true;
	fakeRootCommands = ''
		mkdir -p /var/lib/tor
		chown nobody /var/lib/tor
	'';
	config = {
		Entrypoint = [ "${cpkgs.tor}/bin/tor" "-f" "/etc/tor/torrc" "--servertransportplugin" "obfs4 exec ${cpkgs.obfs4}/bin/lyrebird" "--extorport" "auto" "--servertransportlistenaddr" "obfs4 0.0.0.0:443" ];
		Volumes = {
			"/var/lib/tor" = {};
		};
	};
}
