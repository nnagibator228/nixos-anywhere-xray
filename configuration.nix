{ modulesPath, config, lib, pkgs, ... }: 

let
  xrayConfig = builtins.fromJSON (builtins.readFile /etc/nixos-xray/xray-config.json);
  readAuthorizedKeys = file: [ (builtins.readFile file) ];
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./diskio.nix
  ];

  # allow unfree packages to be installed
  nixpkgs.config = {
    allowUnfree = true;
  };

  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking = {
    hostName = "nixos-xray";
    firewall = {
      enable = true;
      allowedTCPPorts = [ 23 443 9100 ];
      allowedUDPPorts = [ 23 ];
      extraCommands = ''
        iptables -A INPUT -i eth0 -p tcp --dport 23 -j ACCEPT
        iptables -A INPUT -i eth0 -p udp --dport 23 -j ACCEPT
        iptables -A INPUT -i eth0 -p tcp --dport 443 -j ACCEPT
        iptables -A INPUT -i eth0 -p tcp --dport 9100 -j ACCEPT
      '';
    };
  };

  # Set your time zone.
  time.timeZone = "Europe/Zurich";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # UNCOMMENT this to enable docker
  # virtualisation.docker.enable = true;

  programs.fish.enable = true;

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    xray
  ];

  services = {
    openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
    };
    xray = {
      enable = true;
      settings = {
        log = {
          loglevel = xrayConfig.loglevel;
        };

        routing = {
          rules = [];
          domainStrategy = "AsIs";
        };

        inbounds = [
          {
            port = 23;
            tag = "ss";
            protocol = "shadowsocks";
            settings = {
              method = "2022-blake3-aes-128-gcm";
              password = xrayConfig.shadowsocks.password;
              network = "tcp,udp";
            };
          }
          {
            port = 443;
            protocol = "vless";
            tag = "vless_tls";
            settings = {
              clients = xrayConfig.vless.clients;
              decryption = "none";
            };
            streamSettings = {
              network = "tcp";
              security = "reality";
              realitySettings = {
                show = false;
                dest = xrayConfig.vless.domain + ":443";
                xver = 0;
                serverNames = [xrayConfig.vless.domain];
                privateKey = xrayConfig.vless.privateKey;
                minClientVer = "";
                maxClientVer = "";
                maxTimeDiff = 0;
                shortIds = [xrayConfig.vless.shortId];
              };
            };
            sniffing = {
              enabled = true;
              destOverride = ["http" "tls"];
            };
          }
        ];

        outbounds = [
          {
            protocol = "freedom";
            tag = "direct";
          }
          {
            protocol = "blackhole";
            tag = "block";
          }
        ];
      };
    };
    prometheus.exporters.node.enable = xrayConfig.enable_nodeexporter;
  };
  users.users = {
    root = {
      openssh.authorizedKeys.keys = readAuthorizedKeys /etc/nixos-xray/root_authorized_keys.txt;
    };
    xray = {
      isNormalUser = true; 
      shell = pkgs.fish; 
      description = "nixos-xray user"; 
      extraGroups = [ 
        "networkmanager" 
        "wheel" 
        # "docker" - if needed elsewhere
      ]; 
      openssh.authorizedKeys.keys = readAuthorizedKeys /etc/nixos-xray/authorized_keys.txt;
    };
  };
  system.stateVersion = "24.6";
}
