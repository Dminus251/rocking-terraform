#Ingress for Prometheus
resource "kubernetes_ingress_v1" "ingress-prometheus" { 
  count			= var.create_cluster ? 1 : 0
  depends_on = [module.eks-cluster, module.node_group, helm_release.prometheus, kubernetes_service_v1.service-prometheus]
  metadata {
    name = "ingress-prometheus"
    namespace = "monitoring"
    annotations = {
      "alb.ingress.kubernetes.io/scheme" =  "internet-facing"
      "alb.ingress.kubernetes.io/target-type" =  "ip"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/graph"
    }
  }
  spec {
    ingress_class_name = "alb"
    rule {
      host = "prometheus.${var.DOMAIN}"
      http {
        path {
          path_type = "Prefix"
          path = "/"
          backend {
            service{
  	      name = "service-prometheus"
              port {
                number = 9090
              }
            }
          }

        }

      }
    }
  }
}

#Service for Prometheus
resource "kubernetes_service_v1" "service-prometheus" {
  count			= var.create_cluster ? 1 : 0
  depends_on = [module.eks-cluster, module.node_group, helm_release.prometheus]
  metadata {
    name = "service-prometheus"
    namespace = "monitoring"
  }
  spec {
    type = "NodePort"
    selector = {
      "app.kubernetes.io/name" =  "prometheus"
    }
    port {
      port        = 9090
      target_port = 9090
      protocol = "TCP"
    }
  }
}


#Ingress for Grafana
resource "kubernetes_ingress_v1" "ingress-grafana" { 
  count			= var.create_cluster ? 1 : 0
  depends_on = [module.eks-cluster, module.node_group, helm_release.grafana, kubernetes_service_v1.service-grafana]
  metadata {
    name = "ingress-grafana"
    namespace = "monitoring"
    annotations = {
      "alb.ingress.kubernetes.io/scheme" =  "internet-facing"
      "alb.ingress.kubernetes.io/target-type" =  "ip"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/api/health"
    }
  }
  spec {
    ingress_class_name = "alb"
    rule {
      host = "grafana.${var.DOMAIN}"
      http {
        path {
          path_type = "Prefix"
          path = "/"
          backend {
            service{
  	      name = "service-grafana"
              port {
                number = 3000
              }
            }
          }

        }

      }
    }
  }
}

#Pod for my crud image
resource "kubernetes_pod" "pod-crud" {
  depends_on = [module.eks-cluster, module.node_group, null_resource.build_image, helm_release.grafana]
  count			= var.create_cluster ? 1 : 0
  metadata {
    name = "pod-crud"
    namespace = "monitoring"
    labels = {
      "app.kubernetes.io/name" =  "crud"
    }
  }

  spec {
    container {
      image = "dminus251/test:latest"
      name  = "practice"

      port {
        container_port = 5000 
      }
    }
  }
}

#Service for pod-crud
resource "kubernetes_service_v1" "service-crud" {
  count			= var.create_cluster ? 1 : 0
  depends_on = [module.eks-cluster, module.node_group, null_resource.build_image, helm_release.grafana]
  metadata {
    name = "service-crud"
    namespace = "monitoring"
  }
  spec {
    type = "NodePort"
    selector = {
      "app.kubernetes.io/name" =  "crud"
    }
    port {
      port        = 5000 
      target_port = 5000
      protocol = "TCP"
    }
  }
}

#Ingress for service-crud
resource "kubernetes_ingress_v1" "ingress-crud" { 
  count			= var.create_cluster ? 1 : 0
  depends_on = [module.eks-cluster, module.node_group, helm_release.grafana, kubernetes_service_v1.service-crud]
  metadata {
    name = "ingress-crud"
    namespace = "monitoring"
    annotations = {
      "alb.ingress.kubernetes.io/scheme" =  "internet-facing"
      "alb.ingress.kubernetes.io/target-type" =  "ip"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/health"
    }
  }
  spec {
    ingress_class_name = "alb"
    rule {
      host = "crud.${var.DOMAIN}"
      http {
        path {
          path_type = "Prefix"
          path = "/"
          backend {
            service{
  	      name = "service-crud"
              port {
                number = 5000
              }
            }
          }

        }

      }
    }
  }
}

#Service for Grafana
resource "kubernetes_service_v1" "service-grafana" {
  count			= var.create_cluster ? 1 : 0
  depends_on = [module.eks-cluster, module.node_group, helm_release.grafana]
  metadata {
    name = "service-grafana"
    namespace = "monitoring"
  }
  spec {
    type = "NodePort"
    selector = {
      "app.kubernetes.io/name" =  "grafana"
    }
    port {
      port        = 3000
      target_port = 3000
      protocol = "TCP"
    }
  }
}


#ClusterIP: grafana가 prometheus 메트릭을 얻어오기 위해 사용함
resource "kubernetes_service_v1" "cluster-ip" {
  count			= var.create_cluster ? 1 : 0
  depends_on = [module.eks-cluster, module.node_group, helm_release.prometheus]
  metadata {
    name = "practice-clusterip"
    namespace = "monitoring"
  }
  spec {
    type = "ClusterIP"
    selector = {
      "app.kubernetes.io/name" =  "prometheus"
    }
    port {
      port        = 9090
      target_port = 9090
      protocol = "TCP"
    }
  }
}



#Provisioner가 'ebs.csi.aws.com'인 storageClass 생성 
#volume_binding_mode는 Immdediate를 사용함
#만약 WaitForFirstConsumer 사용 시 pvc는 pod의 State가 Running이 될 때까지 Pending되는데
#grafana Pod는 pvc가 Running이 될 때까지 Pending 상태가 됨
#즉 pvc와 pod가 서로 running 상태가 될 때까지 기다리는 교착 상태 발생
resource "kubernetes_storage_class" "gp2" {
  count		       = var.create_cluster ? 1 : 0
  depends_on = [module.eks-cluster, module.public_subnet, module.node_group]
  metadata {
    name = "terraform-example"
  }
  storage_provisioner = "ebs.csi.aws.com" #이걸 사용해야 ebs-csi-driver addon이 ebs를 생성함
  volume_binding_mode = "Immediate"
  reclaim_policy = "Delete"
  parameters = {
    type = "gp2"
  }
}


resource "kubernetes_pod" "ubuntu-private_subnet-2a" {
  depends_on = [module.eks-cluster, module.node_group]
  count			= var.create_cluster ? 1 : 0
  metadata {
    name = "ubuntu-2a"
    namespace = "default"
  }

  spec {
    container {
      image = "ubuntu:latest"
      name  = "ubuntu"
      command = ["sleep", "infinity"] #아무 command도 없으면 CrashLoopBackOff 발생
      port {
        container_port = 5001
      }
    }
    dns_policy = "None" #defalt는 ClusterFirst
    #custom dns_config를 위해 dns_policy를 None으로 설정해야 함
    dns_config {
      nameservers = ["8.8.8.8"]
    }
    affinity{
      node_affinity{
        required_during_scheduling_ignored_during_execution{
          node_selector_term{
            match_expressions{
              key = "subnet"
              operator = "In"
              values = ["private_subnet-2a"]
            }
          }
        }
      }
    }
  }
}


resource "kubernetes_pod" "ubuntu-private_subnet-2c" {
  depends_on = [module.eks-cluster, module.node_group]
  count			= var.create_cluster ? 1 : 0
  metadata {
    name = "ubuntu-2c"
    namespace = "default"
  }

  spec {
    container {
      image = "ubuntu:latest"
      name  = "ubuntu"
      command = ["sleep", "infinity"]
      port {
        container_port = 5002
      }
    }
    
    dns_policy = "None"
    dns_config {
      nameservers = ["8.8.8.8"]
    }
    affinity{
      node_affinity{
        required_during_scheduling_ignored_during_execution{
          node_selector_term{
            match_expressions{
              key = "subnet"
              operator = "In"
              values = ["private_subnet-2c"]
            }
          }
        }
      }
    }
  }
}

