{
  inputs = {
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    nixpkgs.url = "github:NixOS/nixpkgs/22.11";
  };
  outputs = { self, flake-compat, nixpkgs }: {
    legacyPackages.x86_64-linux.mkContainer = { config, date }:
      nixpkgs.legacyPackages.x86_64-linux.callPackage ./. {
        inherit config date;
      };

    nixosConfigurations.default = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          boot.isContainer = true;

          environment.systemPackages = [
            pkgs.bat
            pkgs.crate2nix
            pkgs.fd
            pkgs.file
            pkgs.gdb
            pkgs.htop
            pkgs.jq
            pkgs.llvmPackages_12.clangUseLLVM
            pkgs.llvmPackages_12.llvm
            pkgs.man-pages
            pkgs.nixfmt
            (pkgs.python39.withPackages
              (pypkgs: [ pypkgs.black pypkgs.ipython pypkgs.mypy ]))
            pkgs.ripgrep
            pkgs.shellcheck
            pkgs.strace
            pkgs.watchexec
            pkgs.yj
          ];

          nix = {
            extraOptions = ''
              # Enable Flakes and nix(1)
              experimental-features = flakes nix-command

              # Prevent direnv/nix-shell/nix develop environments from getting GC'd.
              keep-derivations = true
              keep-outputs = true
            '';

            nixPath = [ "nixpkgs=${nixpkgs}" ];

            registry.nixpkgs.flake = nixpkgs;

            settings = {
              auto-optimise-store = true;

              # TODO: Currently broken... fix me on Docker *and* Podman!
              sandbox = false;
            };
          };

          programs.git = {
            enable = true;
            package = pkgs.gitFull;
          };

          system.stateVersion = "22.11";
        })
      ];
    };
  };
}
