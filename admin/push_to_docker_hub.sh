#!/bin/bash
# Script para subir imágenes a Docker Hub
# Uso: bash push_to_docker_hub.sh

echo "🐳 Docker Push Helper"
echo ""
echo "Paso 1: Login a Docker Hub"
echo "  - Usuario: cajaahorrofuturomejor2018"
echo "  - Token: obtén uno en https://app.docker.com/settings/personal-access-tokens"
echo ""
echo "Ejecuta:"
echo "  docker login -u cajaahorrofuturomejor2018"
echo ""
echo "Luego, para subir las imágenes:"
echo "  docker push cajaahorrofuturomejor2018/caja-admin-api:latest"
echo "  docker push cajaahorrofuturomejor2018/caja-admin-web:latest"
echo ""
echo "O ejecuta este script con:"
echo "  bash admin/push_to_docker_hub.sh"
