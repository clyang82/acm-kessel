#!/usr/bin/env sh

# This assumes the following services are running an accepting unauthenticated requests
# - mini-rbac: running on localhost:8085 and configured to talk with relations-api
# - inventory-api: running on localhost:9081 (grpc) and configured to connect with relations-api
# - relations-api: running on localhost:9082 (grpc) for direct tuple creation
# - relations api using this schema: https://github.com/josejulio/rbac-config-acm/commit/0e37ec8114764e4062ea0a76ceff3342954419f7
# Make the needed changes to accommodate to your running services.


# Create a cluster admin role.
CLUSTER_ADMIN_ROLE_ID="$(curl -XPOST http://localhost:8085/api/rbac/v2/roles/ \
  -H "Content-Type: application/json" \
  -d '{
      "name": "ACM Cluster Admin role",
      "description": "All privileges role",
      "permissions": [
        {
          "application": "acm",
          "resource_type": "k8s_cluster",
          "permission": "read"
        },
        {
          "application": "acm",
          "resource_type": "k8s_cluster",
          "permission": "write"
        },
        {
          "application": "acm",
          "resource_type": "k8s_cluster",
          "permission": "create"
        },
        {
          "application": "acm",
          "resource_type": "k8s_cluster",
          "permission": "create_vm"
        },
        {
          "application": "acm",
          "resource_type": "k8s_cluster",
          "permission": "create_application"
        }
      ]
    }' | jq '.id' -r)"

# Create a virt admin clusterrole.
VIRT_ADMIN_CLUSTERROLE_ID="$(curl -XPOST http://localhost:8085/api/rbac/v2/roles/ \
  -H "Content-Type: application/json" \
  -d '{
      "name": "ACM Virt Admin clusterrole",
      "description": "virt privileges clusterrole",
      "permissions": [
        {
          "application": "acm",
          "resource_type": "k8s_cluster",
          "permission": "create_vm"
        }
      ]
    }' | jq '.id' -r)"

# Create a virt admin role.
VIRT_ADMIN_ROLE_ID="$(curl -XPOST http://localhost:8085/api/rbac/v2/roles/ \
  -H "Content-Type: application/json" \
  -d '{
      "name": "ACM Virt Admin role",
      "description": "virt privileges role",
      "permissions": [
        {
          "application": "acm",
          "resource_type": "k8s_namespace",
          "permission": "create_vm"
        }
      ]
    }' | jq '.id' -r)"

# Create an app admin role.
APP_ADMIN_CLUSTERROLE_ID="$(curl -XPOST http://localhost:8085/api/rbac/v2/roles/ \
  -H "Content-Type: application/json" \
  -d '{
      "name": "ACM App Admin clusterrole",
      "description": "app privileges clusterrole",
      "permissions": [
        {
          "application": "acm",
          "resource_type": "k8s_cluster",
          "permission": "create_application"
        }
      ]
    }' | jq '.id' -r)"


ROOT_WORKSPACE_ID="$(curl "http://localhost:8085/api/rbac/v2/workspaces?type=root" | jq ".data[0].id" -r)"
# Report a k8s_cluster (acm) and link it to the root workspace
grpcurl -plaintext -d "{
            \"type\": \"k8s_cluster\",
            \"reporterType\": \"acm\",
            \"reporterInstanceId\": \"1234\",
            \"representations\": {
              \"metadata\": {
                \"localResourceId\": \"cluster-1\",
                \"apiHref\": \"http://somewhere\",
                \"reporterVersion\": \"1.0.0\"
              },
              \"common\": {
                \"workspace_id\": \"${ROOT_WORKSPACE_ID}\"
              },
              \"reporter\": {
                \"external_cluster_id\": \"cluster-1\",
                \"cluster_status\": \"READY\",
                \"cluster_reason\": \"running\",
                \"kube_version\": \"1.0.0\",
                \"kube_vendor\": \"OPENSHIFT\",
                \"vendor_version\": \"3.0.0\",
                \"cloud_platform\": \"BAREMETAL_UPI\",
                \"nodes\": []
              }
            }
          }" localhost:9081 kessel.inventory.v1beta2.KesselInventoryService.ReportResource

grpcurl -plaintext -d "{
            \"type\": \"k8s_cluster\",
            \"reporterType\": \"acm\",
            \"reporterInstanceId\": \"2345\",
            \"representations\": {
              \"metadata\": {
                \"localResourceId\": \"cluster-2\",
                \"apiHref\": \"http://somewhere\",
                \"reporterVersion\": \"1.0.0\"
              },
              \"common\": {
                \"workspace_id\": \"${ROOT_WORKSPACE_ID}\"
              },
              \"reporter\": {
                \"external_cluster_id\": \"cluster-2\",
                \"cluster_status\": \"READY\",
                \"cluster_reason\": \"running\",
                \"kube_version\": \"1.0.0\",
                \"kube_vendor\": \"OPENSHIFT\",
                \"vendor_version\": \"3.0.0\",
                \"cloud_platform\": \"BAREMETAL_UPI\",
                \"nodes\": []
              }
            }
          }" localhost:9081 kessel.inventory.v1beta2.KesselInventoryService.ReportResource

# Report namespaces for cluster-1
grpcurl -plaintext -d "{
            \"type\": \"k8s_namespace\",
            \"reporterType\": \"acm\",
            \"reporterInstanceId\": \"1234\",
            \"representations\": {
              \"metadata\": {
                \"localResourceId\": \"cluster-1/ns-1\",
                \"apiHref\": \"http://somewhere\",
                \"reporterVersion\": \"1.0.0\"
              },
              \"common\": {
                \"workspace_id\": \"${ROOT_WORKSPACE_ID}\"
              },
              \"reporter\": {
                \"namespace_name\": \"ns-1\",
                \"cluster_id\": \"cluster-1\",
                \"cluster_reporter\": \"acm\",
                \"status\": \"ACTIVE\"
              }
            }
          }" localhost:9081 kessel.inventory.v1beta2.KesselInventoryService.ReportResource

# Create tuple linking namespace cluster-1/ns-1 to cluster cluster-1
# This is a workaround to link the namespace to the cluster until we have inventory-api support
# https://redhat.atlassian.net/browse/CRCPLAN-375
grpcurl -plaintext -d "{
            \"upsert\": true,
            \"tuples\": [
              {
                \"resource\": {
                  \"type\": {
                    \"namespace\": \"acm\",
                    \"name\": \"k8s_namespace\"
                  },
                  \"id\": \"cluster-1/ns-1\"
                },
                \"relation\": \"t_k8s_cluster\",
                \"subject\": {
                  \"subject\": {
                    \"type\": {
                      \"namespace\": \"acm\",
                      \"name\": \"k8s_cluster\"
                    },
                    \"id\": \"cluster-1\"
                  }
                }
              }
            ]
          }" localhost:9082 kessel.relations.v1beta1.KesselTupleService.CreateTuples

grpcurl -plaintext -d "{
            \"type\": \"k8s_namespace\",
            \"reporterType\": \"acm\",
            \"reporterInstanceId\": \"1234\",
            \"representations\": {
              \"metadata\": {
                \"localResourceId\": \"cluster-1/ns-2\",
                \"apiHref\": \"http://somewhere\",
                \"reporterVersion\": \"1.0.0\"
              },
              \"common\": {
                \"workspace_id\": \"${ROOT_WORKSPACE_ID}\"
              },
              \"reporter\": {
                \"namespace_name\": \"ns-2\",
                \"cluster_id\": \"cluster-1\",
                \"cluster_reporter\": \"acm\",
                \"status\": \"ACTIVE\"
              }
            }
          }" localhost:9081 kessel.inventory.v1beta2.KesselInventoryService.ReportResource

# Create tuple linking namespace cluster-1/ns-2 to cluster cluster-1
grpcurl -plaintext -d "{
            \"upsert\": true,
            \"tuples\": [
              {
                \"resource\": {
                  \"type\": {
                    \"namespace\": \"acm\",
                    \"name\": \"k8s_namespace\"
                  },
                  \"id\": \"cluster-1/ns-2\"
                },
                \"relation\": \"t_k8s_cluster\",
                \"subject\": {
                  \"subject\": {
                    \"type\": {
                      \"namespace\": \"acm\",
                      \"name\": \"k8s_cluster\"
                    },
                    \"id\": \"cluster-1\"
                  }
                }
              }
            ]
          }" localhost:9082 kessel.relations.v1beta1.KesselTupleService.CreateTuples

# Report namespaces for cluster-2
grpcurl -plaintext -d "{
            \"type\": \"k8s_namespace\",
            \"reporterType\": \"acm\",
            \"reporterInstanceId\": \"2345\",
            \"representations\": {
              \"metadata\": {
                \"localResourceId\": \"cluster-2/ns-1\",
                \"apiHref\": \"http://somewhere\",
                \"reporterVersion\": \"1.0.0\"
              },
              \"common\": {
                \"workspace_id\": \"${ROOT_WORKSPACE_ID}\"
              },
              \"reporter\": {
                \"namespace_name\": \"ns-1\",
                \"cluster_id\": \"cluster-2\",
                \"cluster_reporter\": \"acm\",
                \"status\": \"ACTIVE\"
              }
            }
          }" localhost:9081 kessel.inventory.v1beta2.KesselInventoryService.ReportResource

# Create tuple linking namespace cluster-2/ns-1 to cluster cluster-2
grpcurl -plaintext -d "{
            \"upsert\": true,
            \"tuples\": [
              {
                \"resource\": {
                  \"type\": {
                    \"namespace\": \"acm\",
                    \"name\": \"k8s_namespace\"
                  },
                  \"id\": \"cluster-2/ns-1\"
                },
                \"relation\": \"t_k8s_cluster\",
                \"subject\": {
                  \"subject\": {
                    \"type\": {
                      \"namespace\": \"acm\",
                      \"name\": \"k8s_cluster\"
                    },
                    \"id\": \"cluster-2\"
                  }
                }
              }
            ]
          }" localhost:9082 kessel.relations.v1beta1.KesselTupleService.CreateTuples

grpcurl -plaintext -d "{
            \"type\": \"k8s_namespace\",
            \"reporterType\": \"acm\",
            \"reporterInstanceId\": \"2345\",
            \"representations\": {
              \"metadata\": {
                \"localResourceId\": \"cluster-2/ns-2\",
                \"apiHref\": \"http://somewhere\",
                \"reporterVersion\": \"1.0.0\"
              },
              \"common\": {
                \"workspace_id\": \"${ROOT_WORKSPACE_ID}\"
              },
              \"reporter\": {
                \"namespace_name\": \"ns-2\",
                \"cluster_id\": \"cluster-2\",
                \"cluster_reporter\": \"acm\",
                \"status\": \"ACTIVE\"
              }
            }
          }" localhost:9081 kessel.inventory.v1beta2.KesselInventoryService.ReportResource

# Create tuple linking namespace cluster-2/ns-2 to cluster cluster-2
grpcurl -plaintext -d "{
            \"upsert\": true,
            \"tuples\": [
              {
                \"resource\": {
                  \"type\": {
                    \"namespace\": \"acm\",
                    \"name\": \"k8s_namespace\"
                  },
                  \"id\": \"cluster-2/ns-2\"
                },
                \"relation\": \"t_k8s_cluster\",
                \"subject\": {
                  \"subject\": {
                    \"type\": {
                      \"namespace\": \"acm\",
                      \"name\": \"k8s_cluster\"
                    },
                    \"id\": \"cluster-2\"
                  }
                }
              }
            ]
          }" localhost:9082 kessel.relations.v1beta1.KesselTupleService.CreateTuples

# Bind alice to cluster-1 as cluster_admin
curl -XPUT "http://localhost:8085/api/rbac/v2/role-bindings/by-subject?resource_type=acm/k8s_cluster&resource_id=cluster-1&subject_type=user&subject_id=alice" \
  -H "Content-Type: application/json" \
  -d "{
        \"roles\": [ { \"id\": \"${CLUSTER_ADMIN_ROLE_ID}\" } ]
      }"

# Bind bob to cluster-2 as app_admin
curl -XPUT "http://localhost:8085/api/rbac/v2/role-bindings/by-subject?resource_type=acm/k8s_cluster&resource_id=cluster-2&subject_type=user&subject_id=bob" \
  -H "Content-Type: application/json" \
  -d "{
        \"roles\": [ { \"id\": \"${APP_ADMIN_CLUSTERROLE_ID}\" } ]
      }"

# Bind joe to cluster-2:ns-2 as vm_admin
curl -XPUT "http://localhost:8085/api/rbac/v2/role-bindings/by-subject?resource_type=acm/k8s_namespace&resource_id=cluster-2/ns-2&subject_type=user&subject_id=joe" \
  -H "Content-Type: application/json" \
  -d "{
        \"roles\": [ { \"id\": \"${VIRT_ADMIN_ROLE_ID}\" } ]
      }"

# Bind charlie to cluster-2 as vm_admin
curl -XPUT "http://localhost:8085/api/rbac/v2/role-bindings/by-subject?resource_type=acm/k8s_cluster&resource_id=cluster-2&subject_type=user&subject_id=charlie" \
  -H "Content-Type: application/json" \
  -d "{
        \"roles\": [ { \"id\": \"${VIRT_ADMIN_CLUSTERROLE_ID}\" } ]
      }"

echo "=== Checking alice permissions on cluster-1 ==="
# alice should have all permissions on cluster-1
grpcurl -plaintext \
  -d '{
       "object": {
         "resource_type": "k8s_cluster", "resource_id": "cluster-1", "reporter": {"type": "acm"}
       },
       "relation": "view",
       "subject": {
         "resource": {"resource_type": "principal", "resource_id": "alice", "reporter": {"type": "rbac"}}
       }
     }' \
  localhost:9081 kessel.inventory.v1beta2.KesselInventoryService.Check

grpcurl -plaintext \
  -d '{
       "object": {
         "resource_type": "k8s_cluster", "resource_id": "cluster-1", "reporter": {"type": "acm"}
       },
       "relation": "edit",
       "subject": {
         "resource": {"resource_type": "principal", "resource_id": "alice", "reporter": {"type": "rbac"}}
       }
     }' \
  localhost:9081 kessel.inventory.v1beta2.KesselInventoryService.Check

grpcurl -plaintext \
  -d '{
       "object": {
         "resource_type": "k8s_cluster", "resource_id": "cluster-1", "reporter": {"type": "acm"}
       },
       "relation": "vm_new",
       "subject": {
         "resource": {"resource_type": "principal", "resource_id": "alice", "reporter": {"type": "rbac"}}
       }
     }' \
  localhost:9081 kessel.inventory.v1beta2.KesselInventoryService.Check

grpcurl -plaintext \
  -d '{
       "object": {
         "resource_type": "k8s_cluster", "resource_id": "cluster-1", "reporter": {"type": "acm"}
       },
       "relation": "application_new",
       "subject": {
         "resource": {"resource_type": "principal", "resource_id": "alice", "reporter": {"type": "rbac"}}

       }
     }' \
  localhost:9081 kessel.inventory.v1beta2.KesselInventoryService.Check

echo "=== Checking alice CANNOT access cluster-2 ==="
# alice should NOT have permissions on cluster-2
grpcurl -plaintext \
  -d '{
       "object": {
         "resource_type": "k8s_cluster", "resource_id": "cluster-2", "reporter": {"type": "acm"}
       },
       "relation": "view",
       "subject": {
         "resource": {"resource_type": "principal", "resource_id": "alice", "reporter": {"type": "rbac"}}
       }
     }' \
  localhost:9081 kessel.inventory.v1beta2.KesselInventoryService.Check

echo "=== Checking bob can application_new on cluster-2 ==="
# bob should have application_new permission on cluster-2
grpcurl -plaintext \
  -d '{
       "object": {
         "resource_type": "k8s_cluster", "resource_id": "cluster-2", "reporter": {"type": "acm"}
       },
       "relation": "application_new",
       "subject": {
         "resource": {"resource_type": "principal", "resource_id": "bob", "reporter": {"type": "rbac"}}
       }
     }' \
  localhost:9081 kessel.inventory.v1beta2.KesselInventoryService.Check

echo "=== Checking bob CANNOT vm_new on cluster-2 ==="
# bob should NOT have vm_new permission on cluster-2
grpcurl -plaintext \
  -d '{
       "object": {
         "resource_type": "k8s_cluster", "resource_id": "cluster-2", "reporter": {"type": "acm"}
       },
       "relation": "vm_new",
       "subject": {
         "resource": {"resource_type": "principal", "resource_id": "bob", "reporter": {"type": "rbac"}}
       }
     }' \
  localhost:9081 kessel.inventory.v1beta2.KesselInventoryService.Check

echo "=== Checking bob CANNOT access cluster-1 ==="
# bob should NOT have permissions on cluster-1
grpcurl -plaintext \
  -d '{
       "object": {
         "resource_type": "k8s_cluster", "resource_id": "cluster-1", "reporter": {"type": "acm"}
       },
       "relation": "application_new",
       "subject": {
         "resource": {"resource_type": "principal", "resource_id": "bob", "reporter": {"type": "rbac"}}
       }
     }' \
  localhost:9081 kessel.inventory.v1beta2.KesselInventoryService.Check

echo "=== Checking joe can vm_new on cluster-2/ns-2 ==="
# joe should have vm_new permission on ns-2
grpcurl -plaintext \
  -d '{
       "object": {
         "resource_type": "k8s_namespace", "resource_id": "cluster-2/ns-2", "reporter": {"type": "acm"}
       },
       "relation": "vm_new",
       "subject": {
         "resource": {"resource_type": "principal", "resource_id": "joe", "reporter": {"type": "rbac"}}
       }
     }' \
  localhost:9081 kessel.inventory.v1beta2.KesselInventoryService.Check

echo "=== Checking joe CANNOT vm_new on cluster-2:ns-1 ==="
# joe should NOT have vm_new permission on ns-1
grpcurl -plaintext \
  -d '{
       "object": {
         "resource_type": "k8s_namespace", "resource_id": "cluster-2/ns-1", "reporter": {"type": "acm"}
       },
       "relation": "vm_new",
       "subject": {
         "resource": {"resource_type": "principal", "resource_id": "joe", "reporter": {"type": "rbac"}}
       }
     }' \
  localhost:9081 kessel.inventory.v1beta2.KesselInventoryService.Check

echo "=== Checking joe CANNOT application_new on cluster-2:ns-2 ==="
# joe should NOT have application_new permission on ns-2
grpcurl -plaintext \
  -d '{
       "object": {
         "resource_type": "k8s_namespace", "resource_id": "cluster-2/ns-2", "reporter": {"type": "acm"}
       },
       "relation": "application_new",
       "subject": {
         "resource": {"resource_type": "principal", "resource_id": "joe", "reporter": {"type": "rbac"}}
       }
     }' \
  localhost:9081 kessel.inventory.v1beta2.KesselInventoryService.Check

echo "=== Checking charlie CAN vm_new on cluster-2:ns-2 ==="
# charlie should have vm_new permission on ns-2
grpcurl -plaintext \
  -d '{
       "object": {
         "resource_type": "k8s_namespace", "resource_id": "cluster-2/ns-2", "reporter": {"type": "acm"}
       },
       "relation": "vm_new",
       "subject": {
         "resource": {"resource_type": "principal", "resource_id": "charlie", "reporter": {"type": "rbac"}}
       }
     }' \
  localhost:9081 kessel.inventory.v1beta2.KesselInventoryService.Check
