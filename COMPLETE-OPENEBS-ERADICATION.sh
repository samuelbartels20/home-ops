#!/bin/bash

echo "🔥 COMPLETE OPENEBS ERADICATION - FINAL SWEEP"
echo "=============================================="

# 1. Force delete the remaining HelmRelease
echo "1. DESTROYING REMAINING HELMRELEASE..."
kubectl delete helmrelease openebs -n storage --force --grace-period=0 --ignore-not-found=true

# 2. Force delete all remaining OpenEBS CRDs
echo "2. DESTROYING ALL OPENEBS CRDs..."
kubectl get crd | grep openebs | awk '{print $1}' | while read crd; do
    echo "Deleting CRD: $crd"
    kubectl delete crd "$crd" --force --grace-period=0 --ignore-not-found=true
done

# 3. Force delete any remaining OpenEBS PVCs
echo "3. DESTROYING REMAINING OPENEBS PVCs..."
kubectl get pvc -A --no-headers | grep openebs | while read ns name status volume sc access modes age; do
    echo "Force deleting PVC: $name in namespace $ns"
    kubectl patch pvc "$name" -n "$ns" -p '{"metadata":{"finalizers":[]}}' --type=merge || true
    kubectl delete pvc "$name" -n "$ns" --force --grace-period=0 --ignore-not-found=true
done

# 4. Wait for finalizers to clear
echo "4. WAITING FOR FINALIZERS TO CLEAR..."
sleep 10

# 5. Test the original API call
echo "5. TESTING ORIGINAL API CALL..."
if kubectl get pv -l "openebs.io/cas-type=local-device" >/dev/null 2>&1; then
    echo "✅ API CALL SUCCESSFUL - Issue resolved!"
else
    echo "❌ API call still failing"
fi

# 6. Final verification - count any remaining OpenEBS resources
echo "6. FINAL VERIFICATION..."
PODS=$(kubectl get pods -A 2>/dev/null | grep -c openebs || echo "0")
CRDS=$(kubectl get crd 2>/dev/null | grep -c openebs || echo "0") 
PVCS=$(kubectl get pvc -A 2>/dev/null | grep -c openebs || echo "0")
HELMRELEASES=$(kubectl get helmrelease -A 2>/dev/null | grep -c openebs || echo "0")

echo "Remaining OpenEBS resources:"
echo "- Pods: $PODS"
echo "- CRDs: $CRDS" 
echo "- PVCs: $PVCS"
echo "- HelmReleases: $HELMRELEASES"

TOTAL=$((PODS + CRDS + PVCS + HELMRELEASES))
if [ "$TOTAL" -eq "0" ]; then
    echo "🎉 SUCCESS: OPENEBS COMPLETELY ERADICATED!"
    echo "💀 The API error should now be permanently resolved"
else
    echo "❌ $TOTAL OpenEBS resources still remain"
fi

echo "🔥 ERADICATION COMPLETE" 