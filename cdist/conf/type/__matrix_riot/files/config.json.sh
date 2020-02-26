#!/bin/sh
#
# Upstream configuration guide/documentation:
#   https://github.com/vector-im/riot-web/blob/develop/docs/config.md

generate_embedded_pages () {
  if [ $EMBED_HOMEPAGE ]; then
    cat << EOF
    "embeddedPages": {
        "homeUrl": "home.html"
      },
EOF
  fi
}

cat << EOF
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "$DEFAULT_SERVER_URL",
            "server_name": "$DEFAULT_SERVER_NAME"
        },
        "m.identity_server": {
            "base_url": "https://vector.im"
        }
    },
    "brand": "$BRAND",
    "defaultCountryCode": "$DEFAULT_COUNTRY_CODE",
    "integrations_ui_url": "https://scalar.vector.im/",
    "integrations_rest_url": "https://scalar.vector.im/api",
    "integrations_widgets_urls": [
        "https://scalar.vector.im/_matrix/integrations/v1",
        "https://scalar.vector.im/api",
        "https://scalar-staging.vector.im/_matrix/integrations/v1",
        "https://scalar-staging.vector.im/api",
        "https://scalar-staging.riot.im/scalar/api"
    ],
    "bug_report_endpoint_url": "https://riot.im/bugreports/submit",
    "roomDirectory": {
        "servers": [
            $ROOM_DIRECTORY_SERVERS
        ]
    },
    $(generate_embedded_pages)
    "terms_and_conditions_links": [
        {
            "url": "$PRIVACY_POLICY_URL",
            "text": "Privacy Policy"
        },
        {
            "url": "$COOKIE_POLICY_URL",
            "text": "Cookie Policy"
        }
    ]
}
EOF
