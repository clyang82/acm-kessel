# RBAC Config ACM

This is a sample configuration setup for creating schemas for ACM (Advanced Cluster Management). 
It includes Kessel core components (RBAC and inventory) and provides tooling to compile them into a format suitable for the relations-api.

## Overview

This repository demonstrates how to define and compile authorization schemas using the Kessel Schema Language (KSL). 
The schemas define resource types, relations, and permissions for ACM.

## Prerequisites

- Go installed on your system

## Getting Started

### 1. Install Dependencies

Install the `ksl` compiler tool:

```bash
make init
```

This will install the `ksl` tool from the project-kessel/ksl-schema-language repository.

### 2. Compile the Schema

Compile the KSL source files into a schema.zed file:

```bash
make schema
```

This generates `schemas/schema.zed`, which can be passed to the relations-api.

To compile the schema and update the relations-api ConfigMap in one command:

```bash
make schema && yq eval '.data."schema.zed" = load_str("schemas/schema.zed")' -i ../kessel-mini-rbac/relations-api/01-relations-api-configmap-schema.yaml
```

## Note

This is based on the approach used in [github.com/redhatinsights/rbac-config](https://github.com/redhatinsights/rbac-config). 
There is active work on unifying the schemas from inventory and relations into a single file, but this represents the current state of the setup.
