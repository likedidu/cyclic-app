#!/tmp/env bash

set -e
exec 2>&1

UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
WSPATH=${WSPATH:-'argo'}
wget -qO /tmp/warp-reg https://github.com/badafans/warp-reg/releases/download/v1.0/main-linux-amd64
chmod +x /tmp/warp-reg
/tmp/warp-reg > /tmp/warp.conf
rm /tmp/warp-reg
WG_PRIVATE_KEY=$(grep private_key /tmp/warp.conf | sed "s|.*: ||")
WG_PEER_PUBLIC_KEY=$(grep public_key /tmp/warp.conf | sed "s|.*: ||")
WG_IP6_ADDR=$(grep v6 /tmp/warp.conf | sed "s|.*: ||")
WG_RESERVED=$(grep reserved /tmp/warp.conf | sed "s|.*: ||")
if [[ ! "${WG_RESERVED}" =~ , ]]; then
    WG_RESERVED=\"${WG_RESERVED}\"
fi

generate_config() {
  cat > /tmp/config.json << EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "route": {
    "geoip": {
      "path": "/tmp/geoip.db",
      "download_url": "https://fastly.jsdelivr.net/gh/soffchen/sing-geoip@release/geoip.db",
      "download_detour": "direct"
    },
    "geosite": {
      "path": "/tmp/geosite.db",
      "download_url": "https://fastly.jsdelivr.net/gh/soffchen/sing-geosite@release/geosite.db",
      "download_detour": "direct"
    },
    "rules": [
      {
        "geosite": ["openai"],
        "outbound": "warp-IPv4-out"
      }
    ]
  },
  "inbounds": [
    {
      "sniff": true,
      "sniff_override_destination": true,
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "::",
      "listen_port": 63003,
      "users": [
        {
          "uuid": "${UUID}",
          "alterId": 0
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/${WSPATH}/vm",
        "max_early_data": 2048,
        "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "direct",
      "tag": "warp-IPv4-out",
      "detour": "wireguard-out",
      "domain_strategy": "ipv4_only"
    },
    {
      "type": "direct",
      "tag": "warp-IPv6-out",
      "detour": "wireguard-out",
      "domain_strategy": "ipv6_only"
    },
    {
      "type": "wireguard",
      "tag": "wireguard-out",
      "server": "engage.cloudflareclient.com",
      "server_port": 2408,
      "local_address": [
        "172.16.0.2/32",
        "${WG_IP6_ADDR}"
      ],
      "private_key": "${WG_PRIVATE_KEY}",
      "peer_public_key": "${WG_PEER_PUBLIC_KEY}",
      "reserved": ${WG_RESERVED},
      "mtu": 1408
    }
  ]
}
EOF
}
download_bin() {
DIR_TMP="$(mktemp -d)"
EXEC=$(echo $RANDOM | md5sum | head -c 4)
wget -O - 'https://github.com/SagerNet/sing-box/releases/download/v1.3.0/sing-box-1.3.0-linux-amd64.tar.gz' | busybox tar xz -C ${DIR_TMP}
install -m 755 ${DIR_TMP}/sing-box*/sing-box /tmp/app${EXEC}
}
generate_pm2_file() {
  cat > /tmp/ecosystem.config.js << EOF
module.exports = {
  apps: [
    {
      name: "web",
      script: "./tmp/app* run -c /tmp/config.json"
    }
  ]
}
EOF
}
generate_config
download_bin
generate_pm2_file
[ -e /tmp/ecosystem.config.js ] && pm2 start /tmp/ecosystem.config.js