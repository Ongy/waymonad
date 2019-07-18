let
  pkgs = (import ./nixpkgs.nix) { overlays = [ (import ./overlay.nix) ]; };
in pkgs.haskellPackages.waymonad
