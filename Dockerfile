FROM nixpkgs/nix:latest
ENV DIRPATH=/etc/nixos-xray
WORKDIR $DIRPATH
COPY . .
RUN mkdir -p /root/.config/nix && \
    mv ./config.json.tmpl ./xray-config.json && \
    echo "experimental-features = nix-command flakes" > /root/.config/nix/nix.conf && \
    echo "filter-syscalls = false" >> /root/.config/nix/nix.conf && \
    chmod +x ./entrypoint.sh

ENTRYPOINT ["/bin/bash", "/etc/nixos-xray/entrypoint.sh"]