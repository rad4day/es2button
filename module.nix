flake: { config, lib, pkgs, ... }:
let
  cfg = config.services.es2button;
  inherit (flake.packages.${pkgs.stdenv.hostPlatform.system}) es2button;
in
{
  options.services.es2button = {
    enable = lib.mkEnableOption "Enable es2button service";
    package = lib.mkOption {
      type = lib.types.package;
      default = es2button;
      description = "es2button package to use";
    };
    script = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.package}/examples/example-epsonscan2.sh";
      description = "script to call";
    };
    udev-enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Deploy udev rules";
    };
  };


  config = lib.mkIf cfg.enable (
    let
      scriptFile = pkgs.writeShellScript "es2button-scan.sh" (''
        export PATH=${lib.makeBinPath [ pkgs.epsonscan2 pkgs.coreutils ] }:$PATH
      '' + cfg.script);
    in
    {
      systemd.services."es2button@" = {
        description = "es2button for %I";
        path = [ pkgs.epsonscan2 ];
        serviceConfig = {
          Type = "simple";
          User = "root";
          ExecStart = "${cfg.package}/bin/es2button -d \"%I\" ${scriptFile}";
        };
      };

      services.udev.packages = lib.mkIf cfg.udev-enable [ cfg.package pkgs.epsonscan2 ];
    }
  );

}
