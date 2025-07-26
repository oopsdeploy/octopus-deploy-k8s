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

# Deploy Octopus Server using Helm
resource "helm_release" "octopus_server" {
  name       = "octopus"
  repository = "https://octopus-helm-charts.s3.amazonaws.com"
  chart      = "octopusdeploy"
  namespace  = kubernetes_namespace.octopus.metadata[0].name

  values = [
    yamlencode({
      octopus = {
        image      = "octopusdeploy/octopusdeploy:${var.octopus_image_tag}"
        username   = var.octopus_admin_username
        password   = var.octopus_admin_password
        acceptEula = "Y"
        masterKey  = base64encode(random_password.octopus_master_key.result)
        # Environment variables for kubectl installation
        extraEnv = [
          {
            name  = "KUBECTL_VERSION"
            value = var.kubectl_version
          }
        ]
        # Add startup command to install kubectl before Octopus starts
        command = ["/bin/bash"]
        args = [
          "-c",
          <<-EOF
          echo "Installing kubectl ${var.kubectl_version}..."
          curl -LO "https://dl.k8s.io/release/${var.kubectl_version}/bin/linux/amd64/kubectl"
          chmod +x kubectl
          mv kubectl /usr/local/bin/kubectl
          echo "kubectl installed successfully"
          kubectl version --client
          echo "Starting Octopus Deploy..."
          exec /usr/local/bin/docker-entrypoint.sh
          EOF
        ]
      }
      "mssql-linux" = {
        acceptEula = {
          value = "Y"
        }
        image = {
          repository = "mcr.microsoft.com/mssql/server"
          tag        = var.sqlserver_image_tag
        }
      }
    })
  ]

  timeout = 600
  wait    = true

  depends_on = [kubernetes_namespace.octopus, kubernetes_service_account.octopus_deploy]
}
