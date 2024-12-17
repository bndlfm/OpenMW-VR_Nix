{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    libsForQt5 = pkgs.libsForQt5;
    xorg = pkgs.xorg;
  in {
    packages.x86_64-linux.openmw-vr = libsForQt5.callPackage ./default.nix {
        inherit pkgs;
        inherit (nixpkgs.legacyPackages.x86_64-linux) stdenv lib;
        inherit (nixpkgs.legacyPackages.x86_64-linux) fetchFromGitLab fetchFromGitHub git cmake pkg-config;
        inherit (libsForQt5) wrapQtAppsHook;
        inherit (nixpkgs.legacyPackages.x86_64-linux) SDL2 boost bullet;
        ffmpeg_6 = nixpkgs.legacyPackages.x86_64-linux.ffmpeg_6;
        inherit xorg;
        inherit (xorg) libXt;
        inherit (nixpkgs.legacyPackages.x86_64-linux) luajit lz4 mygui openal openscenegraph recastnavigation unshield yaml-cpp;

        # macOS-specific dependencies
        CoreMedia = if nixpkgs.legacyPackages.x86_64-linux.stdenv.isDarwin
                    then nixpkgs.legacyPackages.x86_64-linux.CoreMedia
                    else null;
        VideoToolbox = if nixpkgs.legacyPackages.x86_64-linux.stdenv.isDarwin
                       then nixpkgs.legacyPackages.x86_64-linux.VideoToolbox
                       else null;
        VideoDecodeAcceleration = if nixpkgs.legacyPackages.x86_64-linux.stdenv.isDarwin
                                  then nixpkgs.legacyPackages.x86_64-linux.VideoDecodeAcceleration
                                  else null;
    };

    packages.x86_64-linux.default = self.packages.x86_64-linux.openmw-vr;

  };
}
