#!/bin/bash

set -e

# === Input Validation ===
if [ -z "$1" ]; then
  echo "❌ Usage: $0 <target-color>"
  echo "Example: $0 green"
  exit 1
fi

TARGET_COLOR=$1
NAMESPACE="nginx"
SERVICE_NAME="nginx-service"

# Determine old color
if [ "$TARGET_COLOR" == "blue" ]; then
  OLD_COLOR="green"
elif [ "$TARGET_COLOR" == "green" ]; then
  OLD_COLOR="blue"
else
  echo "❌ Invalid color: $TARGET_COLOR. Only 'blue' or 'green' allowed."
  exit 1
fi

echo "✅ Switching traffic to color=$TARGET_COLOR..."

# 1. Update service selector
echo "🔁 Updating service selector to route to color=$TARGET_COLOR..."
kubectl patch svc $SERVICE_NAME -n $NAMESPACE -p \
  "{\"spec\": {\"selector\": {\"color\": \"$TARGET_COLOR\"}}}"

# 2. Wait for new pods to be ready
echo "⏳ Waiting for pods with color=$TARGET_COLOR to be ready..."
kubectl wait --for=condition=Ready pods -l color=$TARGET_COLOR -n $NAMESPACE --timeout=120s

# 3. Delete the old StatefulSet or Deployment
echo "🗑️ Deleting old $OLD_COLOR application..."

# Delete StatefulSet if it exists
kubectl delete sts -n $NAMESPACE -l color=$OLD_COLOR || echo "⚠️ No StatefulSet found for $OLD_COLOR"

# Fallback: try deleting Deployment if it exists
kubectl delete deploy -n $NAMESPACE -l color=$OLD_COLOR || echo "⚠️ No Deployment found for $OLD_COLOR"

# 4. ArgoCD sync and cleanup
echo "🔄 ArgoCD syncing target app and deleting old app..."
argocd app sync nginx-$TARGET_COLOR || echo "⚠️ ArgoCD sync failed for nginx-$TARGET_COLOR"
argocd app delete nginx-$OLD_COLOR --yes --cascade || echo "⚠️ ArgoCD delete failed for nginx-$OLD_COLOR"

echo "✅ Successfully switched traffic to $TARGET_COLOR. Cleaned up $OLD_COLOR app."

