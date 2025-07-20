#!/bin/bash

echo "🔍 ULTIMATE OPENEBS DEEP SCAN & ERADICATION"
echo "============================================="

# Function to check and delete resources
check_and_delete() {
    local resource_type=$1
    local namespace_flag=$2
    
    echo "Scanning for OpenEBS $resource_type..."
    
    if [ "$namespace_flag" = "-A" ]; then
        resources=$(kubectl get $resource_type -A --no-headers 2>/dev/null | grep -i openebs || true)
    else
        resources=$(kubectl get $resource_type --no-headers 2>/dev/null | grep -i openebs || true)
    fi
    
    if [ -n "$resources" ]; then
        echo "❌ Found OpenEBS $resource_type:"
        echo "$resources"
        
        # Delete each resource
        echo "$resources" | while read line; do
            if [ "$namespace_flag" = "-A" ]; then
                namespace=$(echo $line | awk '{print $1}')
                name=$(echo $line | awk '{print $2}')
                kubectl delete $resource_type $name -n $namespace --force --grace-period=0 --ignore-not-found=true
            else
                name=$(echo $line | awk '{print $1}')
                kubectl delete $resource_type $name --force --grace-period=0 --ignore-not-found=true
            fi
        done
    else
        echo "✅ No OpenEBS $resource_type found"
    fi
    echo ""
}

echo "1. SCANNING ALL NAMESPACES FOR ANY OPENEBS RESOURCES..."
echo "======================================================="

# Check all basic resource types across all namespaces
check_and_delete "pods" "-A"
check_and_delete "deployments" "-A"
check_and_delete "statefulsets" "-A"
check_and_delete "daemonsets" "-A"
check_and_delete "replicasets" "-A"
check_and_delete "services" "-A"
check_and_delete "configmaps" "-A"
check_and_delete "secrets" "-A"
check_and_delete "serviceaccounts" "-A"
check_and_delete "jobs" "-A"
check_and_delete "cronjobs" "-A"

echo "2. SCANNING STORAGE-RELATED RESOURCES..."
echo "========================================"

check_and_delete "persistentvolumeclaims" "-A"
check_and_delete "persistentvolumes" ""
check_and_delete "storageclasses" ""
check_and_delete "volumesnapshotclasses" ""
check_and_delete "volumesnapshots" "-A"

echo "3. SCANNING CLUSTER-WIDE RESOURCES..."
echo "====================================="

check_and_delete "customresourcedefinitions" ""
check_and_delete "clusterroles" ""
check_and_delete "clusterrolebindings" ""
check_and_delete "validatingwebhookconfigurations" ""
check_and_delete "mutatingwebhookconfigurations" ""
check_and_delete "apiservices" ""

echo "4. SCANNING FLUX/HELM RESOURCES..."
echo "=================================="

check_and_delete "helmreleases" "-A"
check_and_delete "helmrepositories" "-A"
check_and_delete "kustomizations" "-A"
check_and_delete "gitrepositories" "-A"

echo "5. SCANNING NETWORK RESOURCES..."
echo "==============================="

check_and_delete "networkpolicies" "-A"
check_and_delete "ingresses" "-A"
check_and_delete "endpoints" "-A"
check_and_delete "endpointslices" "-A"

echo "6. CHECKING FOR OPENEBS LABELS ON ALL RESOURCES..."
echo "=================================================="

echo "Scanning for resources with OpenEBS labels..."
kubectl get all -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.kind}{"\t"}{.metadata.name}{"\t"}{.metadata.labels}{"\n"}{end}' 2>/dev/null | grep -i openebs || echo "✅ No resources with OpenEBS labels found"

echo "7. CHECKING FOR OPENEBS ANNOTATIONS..."
echo "======================================"

kubectl get all -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.kind}{"\t"}{.metadata.name}{"\t"}{.metadata.annotations}{"\n"}{end}' 2>/dev/null | grep -i openebs || echo "✅ No resources with OpenEBS annotations found"

echo "8. SCANNING FOR OPENEBS IN RESOURCE DESCRIPTIONS..."
echo "=================================================="

for ns in $(kubectl get namespaces -o name | cut -d/ -f2); do
    echo "Checking namespace: $ns"
    kubectl describe all -n $ns 2>/dev/null | grep -i openebs || true
done

echo "9. CHECKING HELM RELEASES ACROSS ALL NAMESPACES..."
echo "================================================="

helm list -A | grep -i openebs || echo "✅ No OpenEBS Helm releases found"

echo "10. FORCE CLEANUP OF KNOWN OPENEBS CRDS..."
echo "=========================================="

# List of known OpenEBS CRDs
openebs_crds=(
    "blockdevices.openebs.io"
    "blockdeviceclaims.openebs.io"
    "cstorbackups.openebs.io"
    "cstorcompletedbackups.openebs.io"
    "cstorpools.openebs.io"
    "cstorpoolinstances.openebs.io"
    "cstorrestores.openebs.io"
    "cstorvolumes.openebs.io"
    "cstorvolumeclaims.openebs.io"
    "cstorvolumepolicies.openebs.io"
    "cstorvolumereplicas.openebs.io"
    "jivavolumes.openebs.io"
    "jivavolumepolicies.openebs.io"
    "lvmnodes.local.openebs.io"
    "lvmsnapshots.local.openebs.io"
    "lvmvolumes.local.openebs.io"
    "zfsbackups.zfs.openebs.io"
    "zfsnodes.zfs.openebs.io"
    "zfsrestores.zfs.openebs.io"
    "zfssnapshots.zfs.openebs.io"
    "zfsvolumes.zfs.openebs.io"
    "diskpools.openebs.io"
    "volumes.openebs.io"
)

for crd in "${openebs_crds[@]}"; do
    kubectl delete crd $crd --ignore-not-found=true --force --grace-period=0 2>/dev/null || true
done

echo "11. SCANNING FOR OPENEBS FINALIZERS..."
echo "======================================"

# Check for resources stuck with OpenEBS finalizers
kubectl get all -A -o json 2>/dev/null | jq -r '.items[] | select(.metadata.finalizers[]? | test("openebs"; "i")) | "\(.metadata.namespace // "cluster-wide")\t\(.kind)\t\(.metadata.name)"' 2>/dev/null || echo "✅ No resources with OpenEBS finalizers found"

echo "12. FINAL VERIFICATION - TESTING ORIGINAL API CALL..."
echo "===================================================="

kubectl get pv -l "openebs.io/cas-type=local-device" 2>&1
exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo "✅ SUCCESS: Original API call works!"
else
    echo "❌ FAILED: Original API call still failing"
fi

echo "13. COMPREHENSIVE CLUSTER SCAN COMPLETE..."
echo "=========================================="

# Final count of any remaining OpenEBS traces
total_openebs=$(kubectl get all -A --no-headers 2>/dev/null | grep -c -i openebs || echo "0")
echo "Total OpenEBS resources remaining: $total_openebs"

if [ "$total_openebs" = "0" ]; then
    echo "🎉 CLUSTER IS COMPLETELY CLEAN OF OPENEBS!"
else
    echo "❌ $total_openebs OpenEBS traces still remain"
fi

echo ""
echo "🔍 ULTIMATE DEEP SCAN COMPLETE"
echo "===============================" 