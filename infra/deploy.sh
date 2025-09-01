#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

# Load env
if [[ -f "$ROOT/.env" ]]; then source "$ROOT/.env"; else echo "Missing .env (copy .env.sample)"; exit 1; fi

: "${SUBSCRIPTION_ID:?}"; : "${RESOURCE_GROUP:?}"; : "${LOCATION:?}"; : "${PREFIX:?}"
AKS_NODE_COUNT="${AKS_NODE_COUNT:-2}"
AKS_NODE_SIZE="${AKS_NODE_SIZE:-Standard_D4s_v5}"
ACR_SKU="${ACR_SKU:-Standard}"
EH_CAPACITY="${EH_CAPACITY:-2}"
EH_PARTITIONS="${EH_PARTITIONS:-12}"
DBX_SKU="${DBX_SKU:-premium}"

az account set -s "$SUBSCRIPTION_ID"
az group create -n "$RESOURCE_GROUP" -l "$LOCATION" 1>/dev/null

echo "Deploying infra (AKS, ACR, ADLS, Event Hubs, Databricks)…"
az deployment group create \
  -g "$RESOURCE_GROUP" \
  -f "$HERE/main.bicep" \
  -p namePrefix="$PREFIX" location="$LOCATION" \
     aksNodeCount="$AKS_NODE_COUNT" aksNodeSize="$AKS_NODE_SIZE" acrSku="$ACR_SKU" \
     dbxSku="$DBX_SKU" ehCapacity="$EH_CAPACITY" ehPartitions="$EH_PARTITIONS" \
  -o json > "$HERE/out.json"

AKS_NAME=$(jq -r '.properties.outputs.aksNameOut.value' "$HERE/out.json")
ACR_NAME=$(jq -r '.properties.outputs.acrNameOut.value' "$HERE/out.json")
ACR_LOGIN_SERVER=$(jq -r '.properties.outputs.acrLoginServer.value' "$HERE/out.json")
DBX_NAME=$(jq -r '.properties.outputs.databricksWorkspace.value' "$HERE/out.json")
SA_NAME=$(jq -r '.properties.outputs.saNameOut.value' "$HERE/out.json")
EH_BROKER=$(jq -r '.properties.outputs.eventHubsKafkaBroker.value' "$HERE/out.json")
EH_NS=$(jq -r '.properties.outputs.eventHubsNamespace.value' "$HERE/out.json")
EH_SEND=$(jq -r '.properties.outputs.sendConn.value' "$HERE/out.json")
EH_LISTEN=$(jq -r '.properties.outputs.listenConn.value' "$HERE/out.json")

cat > "$ROOT/.out.env" <<EOF
AKS_NAME=$AKS_NAME
ACR_NAME=$ACR_NAME
ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER
DBX_NAME=$DBX_NAME
SA_NAME=$SA_NAME
EH_BROKER=$EH_BROKER
EH_NS=$EH_NS
EH_SEND='$EH_SEND'
EH_LISTEN='$EH_LISTEN'
RESOURCE_GROUP=$RESOURCE_GROUP
LOCATION=$LOCATION
PREFIX=$PREFIX
EOF

echo "Outputs → $ROOT/.out.env"
echo "Getting AKS credentials…"
az aks get-credentials -g "$RESOURCE_GROUP" -n "$AKS_NAME" --overwrite-existing

# Flink Operator (Helm)
helm repo add flink-operator https://downloads.apache.org/flink/flink-kubernetes-operator-1.10.0/ >/dev/null
helm repo update >/dev/null
helm upgrade --install flink-operator flink-operator/flink-kubernetes-operator \
  --namespace flink --create-namespace

echo "Done. AKS=$AKS_NAME, ACR=$ACR_NAME ($ACR_LOGIN_SERVER), EH NS=$EH_NS"
