resource "null_resource" "kubeconfig" {
  triggers = {
    cluster_name = aws_eks_cluster.main.name
    region       = data.aws_region.current.name
  }

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${aws_eks_cluster.main.name} --region ${data.aws_region.current.name}"
  }

  depends_on = [aws_eks_node_group.main]
}

# ── Cluster Autoscaler ────────────────────────────────────────────────────────

resource "helm_release" "cluster_autoscaler" {
  name             = "cluster-autoscaler"
  repository       = "https://kubernetes.github.io/autoscaler"
  chart            = "cluster-autoscaler"
  namespace        = "kube-system"
  create_namespace = false
  version          = "9.37.0"

  set {
    name  = "autoDiscovery.clusterName"
    value = aws_eks_cluster.main.name
  }

  set {
    name  = "awsRegion"
    value = data.aws_region.current.name
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }

  depends_on = [
    null_resource.kubeconfig,
    aws_eks_pod_identity_association.autoscaler,
  ]
}

# ── Traefik Ingress Controller ────────────────────────────────────────────────

resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  namespace        = "traefik"
  create_namespace = true
  version          = "30.1.0"

  values = [
    yamlencode({
      service = {
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"   = "nlb"
          "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
        }
      }
      ingressRoute = {
        dashboard = { enabled = true }
      }
      additionalArguments = [
        "--certificatesresolvers.letsencrypt.acme.email=admin@${var.dns_domain}",
        "--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json",
        "--certificatesresolvers.letsencrypt.acme.tlschallenge=true",
      ]
    })
  ]

  depends_on = [null_resource.kubeconfig, helm_release.cluster_autoscaler]
}

# ── ArgoCD ────────────────────────────────────────────────────────────────────

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "7.6.12"

  values = [
    yamlencode({
      server = {
        extraArgs = ["--insecure"]
        ingress = {
          enabled           = true
          ingressClassName  = "traefik"
          hosts             = ["argocd-${var.env}.${var.dns_domain}"]
          annotations = {
            "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
            "traefik.ingress.kubernetes.io/router.tls"         = "true"
          }
        }
      }
    })
  ]

  depends_on = [null_resource.kubeconfig, helm_release.traefik]
}

# ── Prometheus Stack ──────────────────────────────────────────────────────────

resource "helm_release" "prometheus_stack" {
  name             = "prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "65.5.1"

  values = [
    yamlencode({
      prometheus = {
        ingress = {
          enabled          = true
          ingressClassName = "traefik"
          hosts            = ["prometheus-${var.env}.${var.dns_domain}"]
        }
      }
      grafana = {
        ingress = {
          enabled          = true
          ingressClassName = "traefik"
          hosts            = ["grafana-${var.env}.${var.dns_domain}"]
        }
        adminPassword = "admin"
      }
      alertmanager = {
        ingress = {
          enabled          = true
          ingressClassName = "traefik"
          hosts            = ["alertmanager-${var.env}.${var.dns_domain}"]
        }
      }
    })
  ]

  depends_on = [null_resource.kubeconfig, helm_release.traefik]
}

# ── External DNS ──────────────────────────────────────────────────────────────

resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns"
  chart            = "external-dns"
  namespace        = "external-dns"
  create_namespace = true
  version          = "1.15.0"

  values = [
    yamlencode({
      provider = {
        name = "aws"
      }
      env = [
        {
          name  = "AWS_DEFAULT_REGION"
          value = data.aws_region.current.name
        },
      ]
      serviceAccount = {
        name   = "external-dns"
        create = true
      }
      domainFilters = [var.dns_domain]
      policy        = "sync"
      txtOwnerId    = var.env
      txtPrefix     = "${var.env}-"
    })
  ]

  depends_on = [
    null_resource.kubeconfig,
    aws_eks_pod_identity_association.external_dns,
    helm_release.traefik,
  ]
}
