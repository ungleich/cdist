#!/bin/sh

cat <<EOF
[Unit]
Description=IM bridging daemon
Wants=network-online.target
After=network-online.target

[Service]
User=$USER
Group=$GROUP
Type=simple
Restart=on-failure
ExecStart=$BINARY_PATH -conf=/etc/matterbridge/matterbridge.toml

[Install]
WantedBy=multi-user.target
EOF
