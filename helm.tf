################################# AWS-LOADBALANCER-CONTROLLER ################################# 
resource "helm_release" "alb-ingress-controller"{
  count			= var.create_cluster ? 1 : 0
  #depends_on = [module.eks-cluster, module.public_subnet, helm_release.cert-manager]
  depends_on = [module.eks-cluster, module.public_subnet, module.node_group]
  repository = "https://aws.github.io/eks-charts"
  name = "aws-load-balancer-controller" #release name
  chart = "aws-load-balancer-controller" #chart name
  version = "1.8.2"
  namespace = "kube-system"
  set {
	name  = "clusterName"
        value = module.eks-cluster[0].cluster-name
  }
  set {
	name  = "region"
        value = var.AWS_REGION
  }
  set {
	name  = "vpcId"
	value = module.vpc.vpc-id
  }
  set {
	name  = "rbac.create"
	value = "true" #if true, create and use RBAC resource
  }
  set {
	name  = "serviceAccount.create"
        value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
        name  = "createIngressClassResource"
	value = "true"
  }
  set {
    name  = "webhook.service.port"
    value = "443"
  }
  set {
    name  = "webhook.service.targetPort"
    value = "9443"
  }
#  set { #helm_release.cert-manager 주석 해제할 경우 주석 해제
#    name = "enableCertManager"
#   value = "true"
#  }
}

################################# CERT-MANAGER ################################# 
#resource "helm_release" "cert-manager"{
#  #count = 0 #주석 해제할 경우 alc에서 depends_on 변경, enableCertManager 주석처리
#  depends_on = [module.eks-cluster] 
#  repository = "https://charts.jetstack.io"
#  name = "jetpack" #release name
#  chart = "cert-manager" #chart name
#  namespace  = "cert-manager" 
#  create_namespace = true      # 네임스페이스가 없는 경우 생성
#  set {
#    name  = "installCRDs"
#    value = "true"  # Cert Manager 설치 시 CRDs도 함께 설치
#  }
#  set {
#    name = "crds.keep"
#    value = "false" #true면 helm이나 terraform으로 삭제 시 crd 삭제되지 않음
#  }
#}

################################# PROMETHEUS ################################# 
resource "helm_release" "prometheus"{
  count			= var.create_cluster ? 1 : 0
  depends_on = [module.eks-cluster, module.addon-aws-ebs-csi-driver, module.node_group, resource.kubernetes_storage_class.gp2]
  repository = "https://prometheus-community.github.io/helm-charts"
  name = "practice-prometheus" #release name
  chart = "prometheus" # chart name
  namespace = "monitoring"
  create_namespace = true

  #prometheus, grafana의 pvc는 프로비저너가 'ebs.csi.aws.com'인 storage class를 요구함
  #이 storageClass는 kubernetes.tf에 정의되어 있음
  set {
    name = "server.persistentVolume.storageClass"
    value = "terraform-example" 
  }
  set {
    name  = "alertmanager.persistence.storageClass"
    value = "terraform-example"
  }
}

################################# GRAFANA ################################# 
resource "helm_release" "grafana"{
  count			= var.create_cluster ? 1 : 0
  depends_on = [module.eks-cluster, module.addon-aws-ebs-csi-driver, module.node_group, resource.kubernetes_storage_class.gp2]
  version = "8.5.1"
  repository = "https://grafana.github.io/helm-charts"
  name = "practice-grafana"
  chart = "grafana"
  namespace = "monitoring"
  create_namespace = true
   set {
    name  = "adminPassword"
    value = "admin"  
  }
  set {
    name  = "persistence.enabled"
    value = "true"
  }
  set {
    name  = "persistence.storageClassName"
    value = "terraform-example"
  }
}

