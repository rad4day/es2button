{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    naersk.url = "github:nix-community/naersk";
    naersk.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, flake-utils, naersk, nixpkgs }:
    let
      lib = nixpkgs.lib;
      supportedSystems = [
        "x86_64-linux"
        "i686-linux"
        "aarch64-linux"
        "riscv64-linux"
      ];
      forAllSystems = lib.genAttrs supportedSystems;
    in
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
      nixosModules.default = self.nixosModules.es2button;
      nixosModules.es2button = import ./module.nix self;

      packages = forAllSystems (system:
        let
          pkgs = (import nixpkgs) {
            inherit system;
          };
          naersk' = pkgs.callPackage naersk { };
        in
        rec
        {
          default = es2button;

          es2button = naersk'.buildPackage {
            name = "es2button";
            src = builtins.path { path = ./.; name = "es2button"; };
            cargoBuildOptions = o: o ++ [ "-p=es2button" ];
            nativeBuildInputs = with pkgs; [
              pkg-config
              libusb1
              llvmPackages.clang
            ];

            postInstall = ''
              mkdir $out/examples
              cp -r $src/example/*.SF2 $out/examples
              install -Dm755 $src/example/*.sh $out/examples/
              patchShebangs $out/examples

              mkdir -p $out/etc/udev/rules.d

              cat > $out/etc/udev/rules.d/62-es2button.rules <<EOF
              ENV{DEVTYPE}!="usb_device", GOTO="es2button_rules_end"
              ATTR{idVendor}!="04b8", GOTO="es2button_rules_end"
              ACTION!="add|bind", GOTO="es2button_add_rules_end"
              LABEL="es2button_add_rules_begin"
              ENV{epsonscan2_driver}=="esci*", ENV{libsane_matched}=="yes", PROGRAM="${pkgs.systemd}/bin/systemd-escape '%s{product}:%s{busnum}:%s{devnum}'", RUN+="${pkgs.systemd}/bin/systemctl start es2button@%c.service"
              LABEL="es2button_add_rules_end"
              ACTION!="remove", GOTO="es2button_rules_end"
              LABEL="es2button_del_rules_begin"
              LABEL="es2button_del_rules_end"
              LABEL="es2button_rules_end"
              EOF
            '';

            LIBCLANG_PATH = pkgs.lib.makeLibraryPath [ pkgs.llvmPackages_latest.libclang.lib ];
            CONFIG_EPSONSCAN2_PATH = pkgs.epsonscan2;
          };
        });
    };
}
