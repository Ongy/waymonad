_: pkgs: {
  haskellPackages = pkgs.haskellPackages.override (old: {
    overrides =
      pkgs.lib.composeExtensions (old.overrides or (_: _: {}))
      (self: super: {
        network = super.network_3_0_1_1;
        socks = super.socks_0_6_0;
        connection = super.connection_0_3_0;
        cpphs = (self.callCabal2nix "cpphs" (pkgs.fetchzip rec {
          url = "mirror://hackage/cpphs-1.20.8/cpphs-1.20.8.tar.gz";
          sha256 = "1awx019c0pzcaibvbs2fdrlgvpaqfg05magb0sgxpwqyhjgkw6hb";
        }) { }).overrideAttrs (_: {
          patches = [ ./cpphs_lexcpp.patch ];
        });
        hayland =
          pkgs.haskell.lib.dontCheck
          (self.callCabal2nix "hayland" ./hsroots/haskell-wayland { });
        HFuse = self.callCabal2nix "HFuse" ./hfuse { };
        hsroots =
          pkgs.haskell.lib.overrideCabal
          (self.callCabal2nix "hsroots" ./hsroots { input = pkgs.libinput; })
          (current: {
            doHaddock = false;
            librarySystemDepends =
              current.librarySystemDepends ++ [ pkgs.xorg.libX11 ];
          });
        libinput =
          self.callCabal2nix "libinput" ./hsroots/libinput
          { inherit (pkgs) libinput; };
        waymonad =
          pkgs.haskell.lib.overrideCabal
          (self.callCabal2nix "waymonad" ./. { inherit (pkgs) libinput libxkbcommon; })
          (current: {
            librarySystemDepends = current.librarySystemDepends ++
              [
                pkgs.wayland pkgs.pkgconfig pkgs.wlroots pkgs.pixman
                pkgs.fuse pkgs.gegl
              ];
          });
        waymonad-scanner =
            self.callCabal2nix "waymonad-scanner" ./waymonad-scanner { };
        xkbcommon = pkgs.haskell.lib.overrideCabal (
          self.callCabal2nix "xkbcommon" ./hsroots/haskell-xkbcommon
          { inherit (pkgs) libxkbcommon; }
        ) (current: {
          librarySystemDepends =
            current.librarySystemDepends ++ [ pkgs.linuxHeaders pkgs.glibc ];
        });
      });
  });
}
