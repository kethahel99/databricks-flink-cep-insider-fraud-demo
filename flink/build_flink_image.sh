#!/usr/bin/env bash
# Usage: ./build_flink_image.sh [TAG]
# Required environment variables:
#   ACR_NAME         - Azure Container Registry name
#   ACR_LOGIN_SERVER - Azure Container Registry login server (e.g., myregistry.azurecr.io)
# Optional:
#   TAG              - Image tag (default: 1.0.0)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
TAG="${1:-1.0.0}"

# Load outputs from infra
if [[ -f "$ROOT/.out.env" ]]; then
	source "$ROOT/.out.env"
echo "Running Maven tests…"
pushd "$ROOT/flink" >/dev/null
mvn -q test
echo "Building shaded jar…"
mvn -q -DskipTests package
popd >/dev/null

echo "Building shaded jar…"
pushd "$ROOT/flink" >/dev/null
mvn -q -DskipTests package
echo "Building & pushing image to ACR: ${ACR_LOGIN_SERVER}/fraud-insider-flink:${TAG}"
az acr build -r "$ACR_NAME" -t "${ACR_LOGIN_SERVER}/fraud-insider-flink:${TAG}" -f "$ROOT/flink/Dockerfile" "$ROOT/flink"
# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
	echo "Azure CLI (az) could not be found. Please install it before proceeding."
	exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
	echo "You are not logged in to Azure CLI. Please run 'az login' and try again."
	exit 1
fi

echo "Building & pushing image to ACR: ${ACR_NAME}/fraud-insider-flink:${TAG}"
az acr build -r "$ACR_NAME" -t "fraud-insider-flink:${TAG}" -f "$ROOT/flink/Dockerfile" "$ROOT/flink"
echo "Done → ${ACR_LOGIN_SERVER}/fraud-insider-flink:${TAG}"
