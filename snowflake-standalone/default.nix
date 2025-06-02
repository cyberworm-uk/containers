{ pkgs ? import <nixpkgs> { }, arch ? "amd64" }:

let
	cpkgs = if arch == "arm64" then (import <nixpkgs> { }).pkgsCross.aarch64-multiplatform else (import <nixpkgs> { });

in pkgs.dockerTools.buildLayeredImage {
	name = "snowflake-standalone";
	tag = "${arch}";
	architecture = "${arch}";
	contents = [ cpkgs.fakeNss ];
	config = {
		User = "nobody";
		Entrypoint = [ "${cpkgs.snowflake}/bin/proxy" ];
	};
}
