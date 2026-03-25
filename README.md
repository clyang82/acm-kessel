# ACM Kessel Deployment

This repository contains deployment configurations for the ACM Kessel stack with different deployment options.

## Quick Start with KinD

### Option 1: Mini-RBAC Stack (Recommended for Testing)

1. **Create a KinD cluster**
```bash
kind create cluster --name kessel-mini-rbac
```

2. **Deploy the stack**
```bash
cd kessel-mini-rbac
oc apply -k . --server-side
```

3. **Run end-to-end tests**
```bash
cd kessel-mini-rbac
./acm-e2e.sh
```

See [kessel-mini-rbac/README.md](kessel-mini-rbac/README.md) for detailed documentation.

### Option 2: Full Kessel Stack

See [kessel/README.md](kessel/README.md) for the complete Kessel deployment with all components.

## Deployment Options

### kessel-mini-rbac/
Simplified deployment using mini-rbac-go instead of the full RBAC infrastructure.

**Components:**
- PostgreSQL (with WAL logical replication)
- Kafka + Zookeeper
- Debezium (CDC via Kafka Connect)
- SpiceDB + Operator
- Relations API
- Inventory API (with consumer enabled)
- Mini RBAC

**Use cases:**
- Development and testing
- Quick RBAC feature validation
- Learning the Kessel architecture

### kessel/
Full Kessel stack deployment with all production components.

**Components:**
- PostgreSQL
- SpiceDB + Operator
- Relations API
- Inventory API
- Full RBAC API
- Redis
- Message Bus Outbox Processor (MBOP)

**Use cases:**
- Production deployments
- Full feature set testing
- Integration testing

## Prerequisites

- Kubernetes cluster (KinD, minikube, or any K8s cluster)
- kubectl or oc CLI configured
- For E2E tests: `grpcurl` and `jq`

## Project Structure

```
.
├── kessel-mini-rbac/          # Simplified RBAC deployment
│   ├── postgres-dev/          # PostgreSQL with CDC
│   ├── kafka-dev/             # Kafka + Zookeeper
│   ├── debezium/              # Debezium CDC
│   ├── spicedb/               # SpiceDB cluster
│   ├── relations-api/         # Relations API
│   ├── inventory-api/         # Inventory API
│   ├── mini-rbac/             # Mini RBAC
│   ├── operator/              # SpiceDB operator
│   ├── acm-e2e.sh            # E2E test script
│   └── README.md              # Detailed documentation
│
└── kessel/                    # Full Kessel stack
    ├── postgres-dev/          # PostgreSQL
    ├── spicedb/               # SpiceDB cluster
    ├── relations-api/         # Relations API
    ├── inventory-api/         # Inventory API
    ├── rbac/                  # Full RBAC API
    ├── mbop/                  # Message Bus Outbox Processor
    └── README.md              # Full stack documentation
```

## References

- [mini-rbac-go](https://github.com/josejulio/mini-rbac-go)
- [RBAC Config ACM](https://github.com/josejulio/rbac-config-acm)
- [Kessel Relations API](https://github.com/project-kessel/relations-api)
- [Kessel Inventory API](https://github.com/project-kessel/inventory-api)
- [SpiceDB](https://authzed.com/docs)
- [KinD](https://kind.sigs.k8s.io/)
