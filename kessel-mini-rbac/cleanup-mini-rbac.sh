#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE="acm-kessel-mini-rbac"

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}  ACM Kessel Mini-RBAC Cleanup${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""
echo -e "${YELLOW}This will delete the namespace: ${NAMESPACE}${NC}"
echo -e "${YELLOW}All resources will be removed.${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo -e "${RED}Cleanup cancelled${NC}"
    exit 1
fi

echo -e "${GREEN}Deleting namespace ${NAMESPACE}...${NC}"
kubectl delete namespace ${NAMESPACE} --ignore-not-found=true

echo -e "${GREEN}Waiting for namespace to be deleted...${NC}"
kubectl wait --for=delete namespace/${NAMESPACE} --timeout=120s 2>/dev/null || true

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Cleanup Complete!${NC}"
echo -e "${GREEN}=====================================${NC}"
