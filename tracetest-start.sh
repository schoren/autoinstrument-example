#!/bin/bash

set -e

if ! command -v yq &> /dev/null
then
  printf "\e[41myq could not be found, please install it first\e[0m\n"
  echo
  echo "  see https://github.com/mikefarah/yq?tab=readme-ov-file#install"
  exit 1
fi

if ! command -v tracetest &> /dev/null
then
  printf "\e[41mtracetest could not be found, please install it\e[0m\n"
  echo
  echo "    curl -L tracetest.io/install | sh"
  exit 1
fi

if [ ! -f ~/.tracetest/config.yml ]; then
  printf "\e[43mTracetest configuration file not found. Configuring tracetest CLI\e[0m\n"
  tracetest configure
fi

API_KEY=$(tracetest list environmenttoken -o yaml | yq 'select(.spec.role == "admins" and .spec.isRevoked == false and document_index == 0) | .spec.id')
ENDPOINT=$(cat ~/.tracetest/config.yml | yq '"\(.scheme)://\(.endpoint)/"')

COMPOSE_FILE="docker-compose.yaml"

declare -a ports

updated_yaml=$(yq eval '.services |= with_entries(.value += {"pid": "service:autoinstrument"})' "$COMPOSE_FILE")

ports=($(echo "$updated_yaml" | yq eval '.services.*.ports[] | select(.)' | awk -F":" '{print $2}'))

new_service=$(cat <<EOF
image: grafana/beyla:latest
privileged: true
environment:
  OTEL_EXPORTER_OTLP_ENDPOINT: "$ENDPOINT"
  OTEL_EXPORTER_OTLP_HEADERS: "X-Tracetest-Token=$API_KEY"
  BEYLA_OPEN_PORT: "$(IFS=,; echo "${ports[*]}")"
  BEYLA_TRACE_PRINTER: "text"
  BEYLA_BPF_TRACK_REQUEST_HEADERS: "true"
EOF
)
new_service_json=$(echo "$new_service" | yq eval -o=json -I0)

updated_yaml=$(echo "$updated_yaml" | yq eval '.services.autoinstrument = '"$new_service_json")

tracetest dashboard

echo "$updated_yaml" | docker compose -f - up
