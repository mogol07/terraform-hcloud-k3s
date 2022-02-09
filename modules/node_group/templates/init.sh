#!/bin/bash

apt-get -yq update
apt-get install -yq \
    ca-certificates \
    curl \
    ntp \
    jq

# k3s
curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=${k3s_channel} INSTALL_K3S_VERSION=${k3s_version} K3S_URL=https://${control_plane_master_internal_ipv4}:6443 K3S_TOKEN=${k3s_token} sh -s - \
    agent \
    --node-ip="$(ip -4 -j a s dev ens10 | jq '.[0].addr_info[0].local' -r)" \
    --node-external-ip="$(ip -4 -j a s dev eth0 | jq '.[0].addr_info[0].local' -r),$(ip -6 -j a s dev eth0 | jq '.[0].addr_info[0].local' -r)" \
    --kubelet-arg 'cloud-provider=external'

# floating IPs
%{ for ip in floating_ips ~}
ip addr add ${ip} dev eth0
%{ endfor ~}

# additional user_data
${additional_user_data}
