# Phase 1: Infrastructure Only (no Octopus API required)

# Generate a random master key for Octopus Deploy
resource "random_password" "octopus_master_key" {
  length  = 32
  special = true
}

# Create the Octopus namespace
resource "kubernetes_namespace" "octopus" {
  metadata {
    name = var.namespace
  }
}

# Create service account for Octopus Deploy to access Kubernetes
resource "kubernetes_service_account" "octopus_deploy" {
  metadata {
    name      = "octopus-deploy"
    namespace = kubernetes_namespace.octopus.metadata[0].name
  }
}

# Create cluster role for Octopus Deploy with necessary permissions
resource "kubernetes_cluster_role" "octopus_deploy" {
  metadata {
    name = "octopus-deploy"
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces", "services", "pods", "configmaps", "secrets", "serviceaccounts"]
    verbs      = ["get", "list", "create", "update", "patch", "delete", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "daemonsets", "statefulsets"]
    verbs      = ["get", "list", "create", "update", "patch", "delete", "watch"]
  }

  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "create", "update", "patch", "delete", "watch"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs", "cronjobs"]
    verbs      = ["get", "list", "create", "update", "patch", "delete", "watch"]
  }
}

# Bind the cluster role to the service account
resource "kubernetes_cluster_role_binding" "octopus_deploy" {
  metadata {
    name = "octopus-deploy"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.octopus_deploy.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.octopus_deploy.metadata[0].name
    namespace = kubernetes_namespace.octopus.metadata[0].name
  }
}

# Create a secret for the service account token (Kubernetes 1.24+)
resource "kubernetes_secret" "octopus_deploy_token" {
  metadata {
    name      = "octopus-deploy-token"
    namespace = kubernetes_namespace.octopus.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.octopus_deploy.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

# Create a persistent volume for kubectl binary
resource "kubernetes_persistent_volume_claim" "kubectl_tools" {
  metadata {
    name      = "kubectl-tools"
    namespace = kubernetes_namespace.octopus.metadata[0].name
  }
  
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "100Mi"
      }
    }
  }
}

# Create persistent volumes for Octopus data
resource "kubernetes_persistent_volume_claim" "octopus_repository" {
  metadata {
    name      = "octopus-repository"
    namespace = kubernetes_namespace.octopus.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "octopus_artifacts" {
  metadata {
    name      = "octopus-artifacts"
    namespace = kubernetes_namespace.octopus.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "octopus_task_logs" {
  metadata {
    name      = "octopus-task-logs"
    namespace = kubernetes_namespace.octopus.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "octopus_server_logs" {
  metadata {
    name      = "octopus-server-logs"
    namespace = kubernetes_namespace.octopus.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "200Mi"
      }
    }
  }
}

# Create a secret for Octopus configuration
resource "kubernetes_secret" "octopus_config" {
  metadata {
    name      = "octopus-config"
    namespace = kubernetes_namespace.octopus.metadata[0].name
  }
  
  data = {
    AdminUsername    = var.octopus_admin_username
    AdminPassword    = var.octopus_admin_password
    MasterKey        = base64encode(random_password.octopus_master_key.result)
    ConnectionString = "Server=octopus-mssql,1433;Database=Octopus;User Id=SA;Password=Password01!"
  }
}

# Deploy SQL Server using native Kubernetes resources
resource "kubernetes_deployment" "mssql" {
  metadata {
    name      = "octopus-mssql"
    namespace = kubernetes_namespace.octopus.metadata[0].name
    labels = {
      app = "mssql"
    }
  }

  spec {
    replicas = 1
    
    selector {
      match_labels = {
        app = "mssql"
      }
    }

    template {
      metadata {
        labels = {
          app = "mssql"
        }
      }

      spec {
        container {
          name  = "mssql"
          image = "mcr.microsoft.com/mssql/server:${var.sqlserver_image_tag}"
          
          env {
            name = "ACCEPT_EULA"
            value = "Y"
          }
          
          env {
            name = "SA_PASSWORD"
            value = "Password01!"
          }
          
          port {
            container_port = 1433
            name          = "mssql"
          }
          
          resources {
            requests = {
              cpu    = "500m"
              memory = "2Gi"
            }
            limits = {
              cpu    = "1000m"
              memory = "4Gi"
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.octopus]
}

# SQL Server Service
resource "kubernetes_service" "mssql" {
  metadata {
    name      = "octopus-mssql"
    namespace = kubernetes_namespace.octopus.metadata[0].name
  }

  spec {
    selector = {
      app = "mssql"
    }

    port {
      name        = "mssql"
      port        = 1433
      target_port = 1433
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.mssql]
}

# Apply Octopus Deployment using existing YAML manifest
resource "kubernetes_manifest" "octopus_deployment" {
  manifest = yamldecode(templatefile("${path.module}/../octopus-deployment.yaml", {
    namespace = kubernetes_namespace.octopus.metadata[0].name
    kubectl_version = var.kubectl_version
    octopus_image_tag = var.octopus_image_tag
  }))

  depends_on = [
    kubernetes_persistent_volume_claim.kubectl_tools,
    kubernetes_deployment.mssql,
    kubernetes_service_account.octopus_deploy,
    kubernetes_secret.octopus_config
  ]
}

# Service for Octopus Web Interface
resource "kubernetes_service" "octopus_web" {
  metadata {
    name      = "octopus-web"
    namespace = kubernetes_namespace.octopus.metadata[0].name
  }

  spec {
    selector = {
      app = "octopus"
    }

    port {
      name        = "web"
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }

  depends_on = [kubernetes_manifest.octopus_deployment]
}

# Service for Octopus Tentacle Communication
resource "kubernetes_service" "octopus_tentacle" {
  metadata {
    name      = "octopus-tentacle"
    namespace = kubernetes_namespace.octopus.metadata[0].name
  }

  spec {
    selector = {
      app = "octopus"
    }

    port {
      name        = "tentacle"
      port        = 10943
      target_port = 10943
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }

  depends_on = [kubernetes_manifest.octopus_deployment]
}

# Install NFS CSI Driver (required for Kubernetes Agent)
resource "helm_release" "nfs_csi_driver" {
  name             = "csi-driver-nfs"
  repository       = "https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts"
  chart            = "csi-driver-nfs"
  namespace        = "kube-system"
  version          = "v4.*.*"
  
  atomic = true
  
  depends_on = [kubernetes_namespace.octopus]
}
