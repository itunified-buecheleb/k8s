#!/bin/bash

TEST_LB_IP=$(kubectl get svc/foo-bar-service -o=jsonpath='{.status.loadBalancer.ingress[0].ip}'| awk -F"%" '{print $1}')
echo "TEST_LB_IP:$TEST_LB_IP"

curl ${TEST_LB_IP}:5678
curl ${TEST_LB_IP}:5678
curl ${TEST_LB_IP}:5678
