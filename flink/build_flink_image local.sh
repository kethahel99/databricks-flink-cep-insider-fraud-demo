#!/usr/bin/env bash

# Script to build the Flink Docker image locally

set -euo pipefail

IMAGE_NAME="fraud-insider-flink"
TAG="${1:-latest}"

echo "Building Docker image: $IMAGE_NAME:$TAG"
docker build -t "$IMAGE_NAME:$TAG" .

echo "Image built successfully: $IMAGE_NAME:$TAG"