let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  flake-compat = fetchTarball {
    url =
      "https://github.com/edolstra/flake-compat/archive/${lock.nodes.flake-compat.locked.rev}.tar.gz";
    sha256 = lock.nodes.flake-compat.locked.narHash;
  };
  flake = (import flake-compat { src = ./.; }).defaultNix;
in { date }:

flake.outputs.legacyPackages.x86_64-linux.mkContainer {
  inherit (flake.outputs.nixosConfigurations.default) config;
  inherit date;
}
