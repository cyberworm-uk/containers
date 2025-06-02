{ pkgs ? import <nixpkgs> { } }:

let
	torrc = pkgs.writeTextDir "/etc/tor/torrc" ''
		User nobody
		DataDirectory /var/lib/tor
		AvoidDiskWrites 1
		ClientTransportPlugin meek_lite,obfs2,obfs3,obfs4,scramblesuit,webtunnel exec ${pkgs.obfs4}/bin/lyrebird
	'';


in pkgs.dockerTools.buildImage {
	name = "tor";
	tag = "latest";
	copyToRoot = pkgs.buildEnv {
		name = "image-root";
		paths = [ pkgs.fakeNss torrc ];
		pathsToLink = [ "/etc" ];
	};
	runAsRoot = ''
		mkdir -p /var/lib/tor
		chown nobody /var/lib/tor
	'';
	config = {
		Entrypoint = [ "${pkgs.tor}/bin/tor" "-f" "/etc/tor/torrc" ];
		Volumes = {
			"/var/lib/tor" = {};
		};
	};
}
