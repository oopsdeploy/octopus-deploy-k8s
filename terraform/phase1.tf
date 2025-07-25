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
        # Install kubectl in the container for Kubernetes Agent functionality
        extraEnv = [
          {
            name  = "INSTALL_KUBECTL"
            value = "true"
          }
        ]
        # Add init container to install kubectl
        initContainers = [
          {
            name  = "install-kubectl"
            image = "alpine/k8s:1.28.0"
            command = ["/bin/sh"]
            args = [
              "-c",
              "cp /usr/bin/kubectl /shared/kubectl && chmod +x /shared/kubectl"
            ]
            volumeMounts = [
              {
                name      = "kubectl-binary"
                mountPath = "/shared"
              }
            ]
          }
        ]
        # Mount kubectl from init container
        extraVolumes = [
          {
            name = "kubectl-binary"
            emptyDir = {}
          }
        ]
        extraVolumeMounts = [
          {
            name      = "kubectl-binary"
            mountPath = "/usr/local/bin"
            subPath   = "kubectl"
          }
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
