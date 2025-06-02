{ pkgs ? import <nixpkgs> { }, arch ? "amd64" }:

let
	cpkgs = if arch == "arm64" then (import <nixpkgs> { }).pkgsCross.aarch64-multiplatform else pkgs;

in pkgs.dockerTools.buildLayeredImage {
	name = "doh-proxy";
	tag = "${arch}";
	architecture = "${arch}";
	contents = [ cpkgs.fakeNss cpkgs.cacert ];
	config = {
		User = "nobody";
		Entrypoint = [ "${cpkgs.doh-proxy-rust}/bin/doh-proxy" ];
	};
}
