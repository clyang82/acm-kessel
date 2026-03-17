#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="acm-kessel-mini-rbac"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}  ACM Kessel Mini-RBAC Deployment${NC}"
echo -e "${BLUE}  (Simplified Stack with mini-rbac-go)${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""
echo -e "${GREEN}Configuration:${NC}"
echo -e "  Namespace: ${YELLOW}${NAMESPACE}${NC}"
echo -e "  Deployment: ${YELLOW}Simplified Stack (no Kafka/CDC)${NC}"
echo ""

# Function to print step
print_step() {
    echo -e "\n${GREEN}>>> $1${NC}"
}

# Function to wait for deployment
wait_for_deployment() {
    local deployment=$1
    local timeout=${2:-120}
    print_step "Waiting for deployment/${deployment} to be ready (timeout: ${timeout}s)"
    kubectl wait --for=condition=available deployment/${deployment} -n ${NAMESPACE} --timeout=${timeout}s || {
        echo -e "${RED}Deployment ${deployment} failed to become ready${NC}"
        kubectl get pods -n ${NAMESPACE} -l app=${deployment}
        kubectl logs -n ${NAMESPACE} deployment/${deployment} --tail=50 || true
        return 1
    }
}

# Function to wait for pod
wait_for_pod() {
    local label=$1
    local timeout=${2:-120}
    print_step "Waiting for pod with label ${label} to be ready (timeout: ${timeout}s)"
    kubectl wait --for=condition=ready pod -l ${label} -n ${NAMESPACE} --timeout=${timeout}s || {
        echo -e "${RED}Pod with label ${label} failed to become ready${NC}"
        kubectl get pods -n ${NAMESPACE} -l ${label}
        return 1
    }
}

# Function to wait for job
wait_for_job() {
    local job=$1
    local timeout=${2:-60}
    print_step "Waiting for job/${job} to complete (timeout: ${timeout}s)"
    kubectl wait --for=condition=complete --timeout=${timeout}s job/${job} -n ${NAMESPACE} || {
        echo -e "${YELLOW}Warning: Job ${job} did not complete in time${NC}"
        kubectl logs -n ${NAMESPACE} job/${job} --tail=20 || true
    }
}

# Step 0: Use kustomize for complete deployment
print_step "Step 0: Checking deployment method"
echo -e "${BLUE}This script now uses kustomize for simplified deployment.${NC}"
echo -e "${BLUE}To deploy everything at once, run: kubectl apply -k ${SCRIPT_DIR}/${NC}"
echo ""
echo -e "${YELLOW}Continuing with step-by-step deployment for verification...${NC}"
echo ""

# Step 1: Create namespace
print_step "Step 1: Creating namespace ${NAMESPACE}"
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Step 2: Deploy SpiceDB Operator (needs to be first for CRDs)
print_step "Step 2: Deploying SpiceDB Operator"
cd "${SCRIPT_DIR}/operator"
kubectl apply -f 01-spicedb-operator.yaml

wait_for_deployment "spicedb-operator" 120
echo -e "${GREEN}SpiceDB Operator deployed successfully${NC}"

# Step 3: Deploy PostgreSQL (with WAL enabled for Debezium)
print_step "Step 3: Deploying PostgreSQL (with WAL logical replication)"
cd "${SCRIPT_DIR}/postgres-dev"
kubectl apply -f 01-postgres-dev-secret.yaml
kubectl apply -f 02-postgres-dev-pvc.yaml
kubectl apply -f 05-postgres-dev-config.yaml
kubectl apply -f 03-postgres-dev-deployment.yaml
kubectl apply -f 04-postgres-dev-service.yaml

wait_for_pod "app=acm-kessel-postgres" 120
echo -e "${GREEN}PostgreSQL deployed successfully${NC}"

# Step 4: Deploy Kafka Infrastructure
print_step "Step 4: Deploying Kafka Infrastructure (for inventory consumer)"
cd "${SCRIPT_DIR}/kafka-dev"
kubectl apply -f 01-zookeeper.yaml
wait_for_pod "app=zookeeper" 120

kubectl apply -f 02-kafka.yaml
wait_for_pod "app=kafka" 120

# Create Kafka topics
kubectl delete job kafka-create-topics -n ${NAMESPACE} 2>/dev/null || true
kubectl apply -f 03-create-topics.yaml
wait_for_job "kafka-create-topics" 60

echo -e "${GREEN}Kafka infrastructure deployed successfully${NC}"

# Step 5: Deploy Debezium (Kafka Connect with CDC)
print_step "Step 5: Deploying Debezium (Kafka Connect)"
cd "${SCRIPT_DIR}/debezium"
kubectl apply -f 01-debezium-deployment.yaml
kubectl apply -f 02-debezium-service.yaml
kubectl apply -f 03-debezium-connector-config.yaml

wait_for_deployment "acm-kessel-debezium" 120

# Setup Debezium connector
kubectl delete job acm-kessel-debezium-setup -n ${NAMESPACE} 2>/dev/null || true
kubectl apply -f 04-debezium-connector-setup-job.yaml
wait_for_job "acm-kessel-debezium-setup" 60

echo -e "${GREEN}Debezium deployed successfully${NC}"

# Step 6: Deploy SpiceDB instance
print_step "Step 6: Deploying SpiceDB instance"
cd "${SCRIPT_DIR}/spicedb"
kubectl apply -f 02-spicedb-secret.yaml
kubectl apply -f 03-spicedb-cluster.yaml

# Wait for SpiceDB deployment (created by operator)
sleep 10
wait_for_deployment "acm-kessel-spicedb-spicedb" 180

echo -e "${GREEN}SpiceDB deployed successfully${NC}"
echo -e "${BLUE}Note: Schema will be loaded automatically by Relations API on first request${NC}"

# Step 7: Deploy Relations API
print_step "Step 7: Deploying Relations API"
cd "${SCRIPT_DIR}/relations-api"
kubectl apply -f 01-relations-api-configmap-schema.yaml
kubectl apply -f 02-relations-api-secret-config.yaml
kubectl apply -f 03-relations-api-deployment.yaml
kubectl apply -f 04-relations-api-service.yaml

wait_for_deployment "acm-kessel-relations-api" 120

echo -e "${GREEN}Relations API deployed successfully${NC}"

# Step 8: Deploy Inventory API
print_step "Step 8: Deploying Inventory API (with consumer enabled)"
cd "${SCRIPT_DIR}/inventory-api"
kubectl apply -f 01-inventory-api-configmap-schema-cache.yaml
kubectl apply -f 02-inventory-api-secret-config.yaml
kubectl apply -f 03-inventory-api-deployment.yaml
kubectl apply -f 04-inventory-api-service.yaml

wait_for_deployment "acm-kessel-inventory-api" 120

echo -e "${GREEN}Inventory API deployed successfully${NC}"

# Step 9: Deploy Mini RBAC
print_step "Step 9: Deploying Mini RBAC"
cd "${SCRIPT_DIR}/mini-rbac"
kubectl apply -f 00-mini-rbac-configmap.yaml
kubectl apply -f 01-mini-rbac-deployment.yaml
kubectl apply -f 02-mini-rbac-service.yaml

wait_for_deployment "acm-kessel-mini-rbac" 120

echo -e "${GREEN}Mini RBAC deployed successfully${NC}"

# Step 10: Verify deployment
print_step "Step 10: Verifying deployment"
echo ""
echo -e "${BLUE}All Pods:${NC}"
kubectl get pods -n ${NAMESPACE}

echo ""
echo -e "${BLUE}All Services:${NC}"
kubectl get svc -n ${NAMESPACE}

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "${YELLOW}Deployed Components:${NC}"
echo ""
echo -e "  ${GREEN}✓${NC} PostgreSQL - Data storage (with WAL enabled)"
echo -e "  ${GREEN}✓${NC} Kafka + Zookeeper - Event streaming"
echo -e "  ${GREEN}✓${NC} Debezium - CDC via Kafka Connect (reads WAL)"
echo -e "  ${GREEN}✓${NC} SpiceDB - Authorization engine"
echo -e "  ${GREEN}✓${NC} Relations API - Authorization service (talks to SpiceDB)"
echo -e "  ${GREEN}✓${NC} Inventory API - Resource management (with consumer enabled)"
echo -e "  ${GREEN}✓${NC} Mini RBAC - RBAC API (talks to Relations API)"
echo ""
echo -e "${YELLOW}Key Differences from Full Stack:${NC}"
echo -e "  ${GREEN}✓${NC} Includes Debezium CDC for inventory resources"
echo -e "  ${GREEN}✓${NC} No Redis"
echo -e "  ${GREEN}✓${NC} No RBAC CDC pipeline (no RBAC outbox)"
echo -e "  ${GREEN}✓${NC} Uses mini-rbac-go instead of full RBAC API"
echo -e "  ${GREEN}✓${NC} Inventory consumer enabled for resource replication"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo -e "1. Port-forward services:"
echo -e "   ${BLUE}kubectl port-forward svc/acm-kessel-relations-api 9000:9000 -n ${NAMESPACE}${NC}"
echo -e "   ${BLUE}kubectl port-forward svc/acm-kessel-inventory-api 9001:9000 -n ${NAMESPACE}${NC}"
echo -e "   ${BLUE}kubectl port-forward svc/acm-kessel-mini-rbac 8080:8080 -n ${NAMESPACE}${NC}"
echo ""
echo -e "2. Check component logs:"
echo -e "   ${BLUE}kubectl logs -n ${NAMESPACE} deployment/acm-kessel-relations-api${NC}"
echo -e "   ${BLUE}kubectl logs -n ${NAMESPACE} deployment/acm-kessel-mini-rbac${NC}"
echo ""
echo -e "3. Test the APIs:"
echo -e "   ${BLUE}# Mini RBAC health check${NC}"
echo -e "   ${BLUE}curl http://localhost:8080/health${NC}"
echo ""
echo -e "${GREEN}Happy deploying! 🚀${NC}"
