{ lib, config, pkgs, ...}:
let
  nix-thunk = import ./deps/nix-thunk {};
  sources = nix-thunk.mapSubdirectories nix-thunk.thunkSource ./deps;

  localterra = sources.LocalTerra;

  cfg = config.services.localterra;

  addrbook = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/terra-money/testnet/master/bombay-12/addrbook.json";
    sha256 = "0p2bzlfrhrj86lpchhiaffmkn2658rvxb44pb24b664ci1zx4rrv";
  };

  genesis = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/terra-money/testnet/master/bombay-12/genesis.json";
    sha256 = "1mmxzw62gsgc6w10j7irrhrfwmyr8rgj7vv63vpdxfipdzv2v302";
  };
in
{
  options.services.localterra = {
    enable = lib.mkEnableOption "localterra bombay-12 testnet service";

    user = lib.mkOption {
      type = lib.types.str;
      default = "localterra";
      description = "User account under which localterra runs.";
    };

    # Is this even an option
    group = lib.mkOption {
      type = lib.types.str;
      default = "docker";
      description = "Group under which localterra runs.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.localterra = {
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];

      # We just assume if config exists, the setup was found, and if not, we should setup
      preStart = ''
        mkdir -p $STATE_DIRECTORY
        if [ ! -d  "$STATE_DIRECTORY/config" ]; then

          cp -r ${localterra}/* $STATE_DIRECTORY
          chmod -R 777 $STATE_DIRECTORY
          # chown ${cfg.user} $STATE_DIRECTORY/*

          # rm "$STATE_DIRECTORY/config/genesis.json"
          # rm "$STATE_DIRECTORY/config/addrbook.json"

          # cat ${addrbook}

          cp ${addrbook} "$STATE_DIRECTORY/config/addrbook.json"
          cp ${genesis} "$STATE_DIRECTORY/config/genesis.json"
        fi
      '';

      serviceConfig = {
        ExecStart = "${pkgs.docker-compose}/bin/docker-compose up";
        ExecStop = "${pkgs.docker-compose}/bin/docker-compose down";
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = "/var/lib/localterra";
        StateDirectory = "localterra";
      };
    };

    users.users.${cfg.user} = {
      group = cfg.group;
      isSystemUser = true;
    };
  };
}
