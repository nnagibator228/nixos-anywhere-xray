# nixos-anywhere xray vless vpn

Easy toolset to deploy customizable xray vless vpn server to remote server using nixos-anywhere on any system

### Requirements
- docker
- jq

### Preparations
1. If you are using a VDS, scan your server's IP using [RealiTLScanner](https://github.com/XTLS/RealiTLScanner) to get a proper popular hostame for masking vless - it could be run both on host machine & on remote 
2. Make sure your remote is accessible using ssh key you would provide to the script later
3. Identify the device name of your main disk using `lsblk` command - change the value in `disk.disk1.device` string in `diskio.nix` file (current default is `/dev/sda`)

> ⚠️ Make sure all your data is backed up before the deployment cause after the nixos-anywhere deployment current installation would be wiped out

This nixos-anywhere setup utilizes *kexec* system call to install NixOS system on remote, so make sure its available (it mostly is)

### Usage
Run the script bootstrap.sh with no args to get help:
```bash
> ./bootstrap.sh 
Usage: ./bootstrap.sh [-c|--clients <number> / default: 2] [-d|--domain <domain> / default: www.microsoft.com] [-e|--enable-nodeexporter <true/false> / default: false] [-s|--server-ip <ip> required] [-a|--auth-keys <path> required] [-r|--root-auth-keys <path> / default: same as --auth-keys] [-i|--priv-key <path> / default: homedir/.ssh/id_rsa]

Required parameters:
[-s|--server-ip <ip> required]
[-a|--auth-keys <path> required]

Optional parameters:
[-c|--clients <number> / default: 2]
[-d|--domain <domain> / default: www.microsoft.com]
[-e|--enable-nodeexporter <true/false> / default: false]
[-r|--root-auth-keys <path> / default: same as --auth-keys]
[-i|--priv-key <path> / default: homedir/.ssh/id_rsa]
```

Provide the required params & run the script, it will perform several actions:

- Prepare the `config.json`
- Build a nix docker container
- Run nixos-anywhere deployment to remote host over the configurations inside docker container
- Output vless:// connection links

Typical run command:
```bash
> ./bootstrap.sh --server-ip 12.34.56.78 --auth-keys ./auth_keys -c 5 -d www.yahoo.com -e true --root-auth-keys ./auth_keys -i ./id_rsa
```
> ⚠️ You should specify the absolute path to the files in arguments. If the file is located in current directory, do not forget to add `./` otherwise it won't work
