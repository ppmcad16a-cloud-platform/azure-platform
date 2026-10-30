locals {
  template_vars = {
    cloud   = "azure"
    cluster = var.cluster_name
  }
}

# Random Grafana admin password (instead of the chart's well-known default).
resource "random_password" "grafana_admin" {
  length  = 24
  special = false
}

# Prometheus + Alertmanager + Grafana + node/kube-state metrics.
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "92.6.0"
  namespace        = "monitoring"
  create_namespace = false
  wait             = true
  timeout          = 900
  depends_on       = [helm_release.platform_config]

  values = [templatefile("${path.module}/values/kube-prometheus-stack.yaml.tftpl", local.template_vars)]

  # Kept out of the values file and hidden in Terraform's output.
  set_sensitive = [
    {
      name  = "grafana.adminPassword"
      value = random_password.grafana_admin.result
    },
  ]
}

resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = "7.3.0"
  namespace  = "monitoring"
  wait       = true
  timeout    = 600

  values     = [templatefile("${path.module}/values/loki.yaml.tftpl", local.template_vars)]
  depends_on = [helm_release.kube_prometheus_stack] # namespace + ServiceMonitor CRD
}

resource "helm_release" "alloy" {
  name       = "alloy"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  version    = "1.13.1"
  namespace  = "monitoring"
  wait       = true

  values     = [templatefile("${path.module}/values/alloy.yaml.tftpl", local.template_vars)]
  depends_on = [helm_release.loki]
}

resource "helm_release" "opencost" {
  name       = "opencost"
  repository = "https://opencost.github.io/opencost-helm-chart"
  chart      = "opencost"
  version    = "2.5.32"
  namespace  = "monitoring"
  wait       = true

  values     = [templatefile("${path.module}/values/opencost.yaml.tftpl", local.template_vars)]
  depends_on = [helm_release.kube_prometheus_stack]
}

# The shop's recording rules + alerts from the shared
# observability-platform repo - the SAME tagged version in every cloud.
module "mern_observability" {
  source     = "git::https://github.com/ppmcad16a-cloud-platform/observability-platform.git//modules/mern-observability?ref=v1.1.0"
  cloud      = "azure"
  depends_on = [helm_release.kube_prometheus_stack]
}
