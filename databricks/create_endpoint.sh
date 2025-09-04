#!/usr/bin/env bash
set -euo pipefail
THIS_DIR="$(cd "$(dirname "$0")" && pwd)"
EP=$(jq -r .name "$THIS_DIR/endpoint.json")
if databricks serving-endpoints get "$EP" >/dev/null 2>&1; then
  databricks serving-endpoints update-config "$EP" --json @"$THIS_DIR/endpoint.json"
else
  databricks serving-endpoints create "$EP" --json @"$THIS_DIR/endpoint.json"
fi
