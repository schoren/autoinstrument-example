#!/bin/bash

# Archivo docker-compose.yaml
COMPOSE_FILE="docker-compose.yaml"

# Declarar un array para almacenar los puertos
declare -a ports

# Leer y modificar el contenido en memoria
updated_yaml=$(yq eval '.services |= with_entries(.value += {"pid": "service:autoinstrument"})' "$COMPOSE_FILE")

# Extraer los puertos y almacenarlos en un array
ports=($(echo "$updated_yaml" | yq eval '.services.*.ports[] | select(.)' | awk -F":" '{print $2}'))

# Agregar un servicio hardcodeado con heredoc
new_service=$(cat <<EOF
image: grafana/beyla:latest
privileged: true
environment:
  OTEL_EXPORTER_OTLP_ENDPOINT: "http://host.docker.internal:4317"
  BEYLA_OPEN_PORT: "$(IFS=,; echo "${ports[*]}")"
  BEYLA_TRACE_PRINTER: "text"
extra_hosts:
  - "host.docker.internal:host-gateway"
EOF
)
new_service_json=$(echo "$new_service" | yq eval -o=json -I0)
echo "$new_service_json"

# Añadir el servicio hardcodeado al YAML actualizado usando yq para mergear
updated_yaml=$(echo "$updated_yaml" | yq eval '.services.autoinstrument = '"$new_service_json")

echo "$updated_yaml" | docker compose -f - up
