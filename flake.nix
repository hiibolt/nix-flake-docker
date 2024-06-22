{
  # Tremendous thanks to @oati for her help
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };
  outputs = { self, nixpkgs, rust-overlay, flake-utils }: 
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };
        rustVersion = pkgs.rust-bin.stable.latest.default;

        rustPlatform = pkgs.makeRustPlatform {
          cargo = rustVersion;
          rustc = rustVersion;
        };

        localRustBuild = rustPlatform.buildRustPackage rec {
          pname = "app";
          version = "0.0.1";
          src = ./.;
          cargoBuildFlags = "";

          cargoLock = {
            lockFile = ./Cargo.lock;
          };

          nativeBuildInputs = [ (rustVersion.override { extensions = ["rust-src"]; }) ] ++ (with pkgs; [ 
            pkg-config
            cargo
            gcc
            rustfmt
            clippy
            openssl.dev
          ]);
          /*
          libPath = with pkgs; lib.makeLibraryPath [
            udev
            alsa-lib
            vulkan-loader
            libGL
            libxkbcommon
            gtk3-x11
            gtk3
            wayland
            xorg.libX11
            xorg.libXcursor
            xorg.libXi
            xorg.libXrandr
            xorg.libxcb
          ];
          */

          # Certain Rust tools won't work without this
          # This can also be fixed by using oxalica/rust-overlay and specifying the rust-src extension
          # See https://discourse.nixos.org/t/rust-src-not-found-and-other-misadventures-of-developing-rust-on-nixos/11570/3?u=samuela. for more details.
          RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
          PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
          #LD_LIBRARY_PATH = libPath;
          OPENSSL_LIB_DIR = pkgs.openssl.out + "/lib";
        };
      in
      {
        packages.nix-flake-docker = localRustBuild;

        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [ cargo rustc ];
        };
    });
}