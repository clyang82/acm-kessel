# ACM Kessel Mini-RBAC Deployment

This is a simplified deployment of the ACM Kessel stack using [mini-rbac-go](https://github.com/josejulio/mini-rbac-go) instead of the full RBAC infrastructure.

### Key Differences from Full Stack

**What's Included:**
- ✅ PostgreSQL (simplified, no outbox table)
- ✅ Kafka + Zookeeper (minimal, for inventory consumer only)
- ✅ SpiceDB + Operator
- ✅ Relations API (with ACM schema from rbac-config-acm)
- ✅ Inventory API (with consumer enabled)
- ✅ Mini RBAC (via mini-rbac-go)
- 
## Prerequisites

- Kubernetes cluster (minikube, kind, or any K8s cluster)
- kubectl configured
- `kustomize` (optional, kubectl has built-in kustomize support)

## Quick Start

### Deploy Everything at Once

Using kustomize:

```bash
kubectl apply -k .
```

Or use the deployment script for step-by-step deployment with verification:

```bash
./deploy-mini-rbac.sh
```

### Verify Deployment

```bash
kubectl get pods -n acm-kessel-mini-rbac
kubectl get svc -n acm-kessel-mini-rbac
```

## Components

### 1. PostgreSQL (Development)
- Simple PostgreSQL deployment without CDC/outbox setup
- Used by Inventory API for resource storage
- No RBAC-specific database or user

### 2. Kafka + Zookeeper
- Minimal Kafka setup for inventory event streaming
- Single topic: `inventory-events`
- Enables inventory consumer to replicate resources to SpiceDB
- No RBAC CDC topics

### 3. SpiceDB
- Authorization engine
- Uses schema from [rbac-config-acm](https://github.com/josejulio/rbac-config-acm)
- Automatically loaded by Relations API

### 4. Relations API
- Kessel Relations API
- Connects to SpiceDB
- Provides authorization services
- Receives resource tuples from Inventory API consumer

### 5. Inventory API
- Kessel Inventory API
- Stores resources in PostgreSQL
- Uses Relations API for authorization
- **Consumer enabled**: Replicates resources to SpiceDB via Kafka
- Publishes events to `inventory-events` topic

### 6. Mini RBAC
- Lightweight RBAC implementation using mini-rbac-go
- Directly interfaces with SpiceDB
- Replaces the full RBAC API + Kafka Consumer + Redis stack

## Accessing Services

Port-forward the services to access them locally:

```bash
# Relations API
kubectl port-forward svc/acm-kessel-relations-api 9000:9000 -n acm-kessel-mini-rbac

# Inventory API
kubectl port-forward svc/acm-kessel-inventory-api 9001:9000 -n acm-kessel-mini-rbac

# Mini RBAC
kubectl port-forward svc/acm-kessel-mini-rbac 8080:8080 -n acm-kessel-mini-rbac
```

### Test Endpoints

```bash
# Mini RBAC health check
curl http://localhost:8080/health

# Relations API health
curl http://localhost:9000/api/authz/livez
```

## Cleanup

Delete all resources:

```bash
./cleanup-mini-rbac.sh
```

Or manually:

```bash
kubectl delete namespace acm-kessel-mini-rbac
```

## Configuration

### Schema

The SpiceDB schema is loaded from the configmap at:
- `relations-api/01-relations-api-configmap-schema.yaml`

This schema is sourced from: https://github.com/josejulio/rbac-config-acm/blob/main/schemas/schema.zed

## References

- [mini-rbac-go](https://github.com/josejulio/mini-rbac-go)
- [RBAC Config ACM](https://github.com/josejulio/rbac-config-acm)
- [Kessel Relations API](https://github.com/project-kessel/relations-api)
- [Kessel Inventory API](https://github.com/project-kessel/inventory-api)
- [SpiceDB](https://authzed.com/docs)
