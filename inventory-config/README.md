# ACM Inventory Config

A Go utility for managing and caching Kubernetes resource schemas used in inventory systems. This tool preprocesses resource schema definitions from multiple reporters (ACM, ACS, OCM) and generates a unified schema cache.

## Overview

This project processes resource schema definitions and their configurations, normalizing resource types and encoding configurations into a structured JSON cache file. It supports multiple Kubernetes resource types and different reporter implementations.

## Supported Resources

- **k8s_cluster** - Kubernetes cluster resources (Reporters: ACM, ACS, OCM)
- **k8s_namespace** - Kubernetes namespace resources (Reporters: ACM)
- **k8s_policy** - Kubernetes policy resources (Reporters: ACM)

## Usage

Generate the schema cache:

```bash
go run main.go
```

This will scan the `schema/resources` directory and generate `schema_cache.json` containing all processed schemas and configurations.

To generate the schema cache and update the ConfigMap in one command:

```bash
go run main.go && yq eval '.data."schema_cache.json" = load_str("schema_cache.json")' -i ../kessel-mini-rbac/inventory-api/01-inventory-api-configmap-schema-cache.yaml
```

## Schema Cache Structure

The generated cache uses the following key format:

- `common:<resource_type>` - Common representation schemas (JSON)
- `config:<resource_type>` - Resource-level configurations (Base64-encoded YAML)
- `config:<resource_type>:<reporter_type>` - Reporter-specific configurations (Base64-encoded YAML)
- `<resource_type>:<reporter_type>` - Reporter-specific schemas (JSON)

## Directory Structure

```
inventory-config/
├── main.go
├── schema/
│   └── resources/
│       ├── k8s_cluster/
│       │   ├── common_representation.json
│       │   ├── config.yaml
│       │   └── reporters/
│       │       ├── acm/
│       │       ├── acs/
│       │       └── ocm/
│       ├── k8s_namespace/
│       └── k8s_policy/
└── testData/
    └── v1beta2/
```
