#!/bin/bash

echo "Testing the original failing API call:"
echo "kubectl get pv -l \"openebs.io/cas-type=local-device\""

kubectl get pv -l "openebs.io/cas-type=local-device"
exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo "✅ SUCCESS: API call works!"
else
    echo "❌ FAILED: API call still failing with exit code $exit_code"
fi

echo "Checking for any remaining OpenEBS PVs:"
kubectl get pv -o yaml | grep -c "openebs.io" || echo "0"

echo "Done." 