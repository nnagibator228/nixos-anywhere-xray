#!/bin/bash
set -e

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is not installed. Exiting... "
        exit 1
    fi
}

check_command docker
check_command jq

generate_vless_link() {
    local ip="$1"
    local n="$2"
    local json="$3"

    local id=$(echo "$json" | jq -r ".vless.clients[$n].id")
    local domain=$(echo "$json" | jq -r ".vless.domain")
    local publicKey=$(echo "$json" | jq -r ".vless.publicKey")
    local shortId=$(echo "$json" | jq -r ".vless.shortId")

    echo "vless://${id}@${ip}:443?security=reality&sni=${domain}&alpn=h2&fp=chrome&pbk=${publicKey}&sid=${shortId}&type=tcp&flow=xtls-rprx-vision&encryption=none#vless-new$((n+1))"
}

print_usage_and_exit() {
    echo "Usage: $0 [-c|--clients <number> / default: 2] [-d|--domain <domain> / default: www.microsoft.com] [-e|--enable-nodeexporter <true/false> / default: false] [-s|--server-ip <ip> required] [-a|--auth-keys <path> required] [-r|--root-auth-keys <path> / default: same as --auth-keys] [-i|--priv-key <path> / default: homedir/.ssh/id_rsa]"
    echo ""
    echo "Required parameters:"
    echo "[-s|--server-ip <ip> required]"
    echo "[-a|--auth-keys <path> required]"
    echo ""
    echo "Optional parameters:"
    echo "[-c|--clients <number> / default: 2]"
    echo "[-d|--domain <domain> / default: www.microsoft.com]"
    echo "[-e|--enable-nodeexporter <true/false> / default: false]"
    echo "[-r|--root-auth-keys <path> / default: same as --auth-keys]"
    echo "[-i|--priv-key <path> / default: homedir/.ssh/id_rsa]"
    exit 1
}

num_clients=2
domain="www.microsoft.com"
enable_nodeexporter=false
priv_key_path="$HOME/.ssh/id_rsa"

if [[ $# -eq 0 ]]; then
    print_usage_and_exit
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--clients)
            num_clients="$2"
            shift 2
            ;;
        -d|--domain)
            domain="$2"
            shift 2
            ;;
        -e|--enable-nodeexporter)
            enable_nodeexporter=$2
            shift 2
            ;;
        -s|--server-ip)
            server_ip="$2"
            shift 2
            ;;
        -a|--auth-keys)
            auth_keys_path="$2"
            shift 2
            ;;
        -r|--root-auth-keys)
            root_auth_keys_path="$2"
            shift 2
            ;;
        -i|--priv-key)
            priv_key_path="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

required_params=("server_ip" "auth_keys_path")
for param in "${required_params[@]}"; do
    if [[ -z ${!param} ]]; then
        echo "Missing required parameter: - $param"
        print_usage_and_exit
    fi
done

if [[ -z "$root_auth_keys_path" ]]; then
    root_auth_keys_path=$auth_keys_path
fi

key_pair=$(docker run ghcr.io/xtls/xray-core:latest x25519)

image="nixos-xray:local"
docker buildx build -t $image .
echo "Built local docker image: $image"

json=$(jq -n '{"loglevel": "info", "shadowsocks": {"password": $shadowsocks_password}, "vless": {"domain": $domain, "publicKey": $pubKey, "privateKey": $privKey, "shortId": $sid}, "enable_nodeexporter": ($enable_nodeexporter | test("true")) }' \
--arg shadowsocks_password $(openssl rand -hex 32) \
--arg domain $domain \
--arg enable_nodeexporter $enable_nodeexporter \
--arg pubKey $(echo $key_pair | cut -d' ' -f6) \
--arg privKey $(echo $key_pair | cut -d' ' -f3) \
--arg sid $(openssl rand -hex 8))

for ((i=0; i<num_clients; i++)); do
    id=$(docker run ghcr.io/xtls/xray-core:sha-c30f5d4-ls uuid)
    email="user$((i+1))@xrayvless"

    client=$(jq -n '{"id": $uid, "email": $email, "flow":"xtls-rprx-vision"}' \
    --arg uid $id \
    --arg email $email \
    )
    if [ $i -eq 0 ]; then
        json=$(echo "$json" | jq '.vless.clients = [$new_client]' --argjson new_client "$client")
    else
        json=$(echo "$json" | jq '.vless.clients += [$client]' --argjson client "$client")
    fi
done

echo "$json" | jq '.' > config.json
echo "Configuration file generated: config.json"

echo "Running deployment... "

docker run  --network host -e TARGET=$server_ip -v ./config.json:/etc/nixos-xray/xray-config.json -v $root_auth_keys_path:/etc/nixos-xray/root_authorized_keys.txt -v $auth_keys_path:/etc/nixos-xray/authorized_keys.txt -v $priv_key_path:/root/.ssh/id_rsa:ro $image

for ((i=0; i<num_clients; i++)); do
    link=$(generate_vless_link "$server_ip" "$i" "$json")
    echo "VLESS Connection Link $((i+1)): $link"
done
