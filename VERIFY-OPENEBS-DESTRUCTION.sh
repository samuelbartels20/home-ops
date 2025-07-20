#!/bin/bash

echo "🔍 VERIFYING OPENEBS DESTRUCTION"
echo "================================"

echo "1. Checking for OpenEBS HelmReleases..."
kubectl get helmrelease -A | grep -i openebs || echo "✅ No OpenEBS HelmReleases found"

echo -e "\n2. Checking for OpenEBS pods..."
kubectl get pods -A | grep -i openebs || echo "✅ No OpenEBS pods found"

echo -e "\n3. Checking for OpenEBS deployments..."
kubectl get deployments -A | grep -i openebs || echo "✅ No OpenEBS deployments found"

echo -e "\n4. Checking for OpenEBS statefulsets..."
kubectl get statefulsets -A | grep -i openebs || echo "✅ No OpenEBS statefulsets found"

echo -e "\n5. Checking for OpenEBS daemonsets..."
kubectl get daemonsets -A | grep -i openebs || echo "✅ No OpenEBS daemonsets found"

echo -e "\n6. Checking for OpenEBS services..."
kubectl get services -A | grep -i openebs || echo "✅ No OpenEBS services found"

echo -e "\n7. Checking for OpenEBS configmaps..."
kubectl get configmaps -A | grep -i openebs || echo "✅ No OpenEBS configmaps found"

echo -e "\n8. Checking for OpenEBS secrets..."
kubectl get secrets -A | grep -i openebs || echo "✅ No OpenEBS secrets found"

echo -e "\n9. Checking for OpenEBS storage classes..."
kubectl get storageclass | grep -i openebs || echo "✅ No OpenEBS storage classes found"

echo -e "\n10. Checking for OpenEBS PVCs..."
kubectl get pvc -A | grep -i openebs || echo "✅ No OpenEBS PVCs found"

echo -e "\n11. Checking for OpenEBS PVs..."
kubectl get pv | grep -i openebs || echo "✅ No OpenEBS PVs found"

echo -e "\n12. Checking for OpenEBS CRDs..."
kubectl get crd | grep -i openebs || echo "✅ No OpenEBS CRDs found"

echo -e "\n13. Checking for OpenEBS webhooks..."
kubectl get validatingwebhookconfigurations | grep -i openebs || echo "✅ No OpenEBS validating webhooks found"
kubectl get mutatingwebhookconfigurations | grep -i openebs || echo "✅ No OpenEBS mutating webhooks found"

echo -e "\n14. Checking for OpenEBS API services..."
kubectl get apiservices | grep -i openebs || echo "✅ No OpenEBS API services found"

echo -e "\n15. Checking for OpenEBS RBAC..."
kubectl get clusterroles | grep -i openebs || echo "✅ No OpenEBS clusterroles found"
kubectl get clusterrolebindings | grep -i openebs || echo "✅ No OpenEBS clusterrolebindings found"

echo -e "\n16. Testing the original failing API call..."
kubectl get pv -l "openebs.io/cas-type=local-device" && echo "✅ API call works (no resources found)" || echo "❌ API call failed"

echo -e "\n17. Checking current storage namespace..."
kubectl get all -n storage

echo -e "\n💀 DESTRUCTION VERIFICATION COMPLETE!"
echo "OpenEBS should be completely removed from the cluster." 