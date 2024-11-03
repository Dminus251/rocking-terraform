#비용 절약을 위해 rocking_terraform 디렉터리의 이중화를 없앰
#수정된 내용은 주석 후, 새로운 내용에 #e를 붙임

locals {
  any_port     = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]
}


############################ NETWORK Configuration ###########################
#VPC
module "vpc" { 
  source = "./modules/t-aws-vpc"
}

#Public Subnet
module "public_subnet" { 
  source 	     = "./modules/t-aws-public_subnet"
  #count 	     = length(var.public_subnet-cidr)
  count 	     = 1 #e
  vpc-id	     = module.vpc.vpc-id
  #public_subnet-cidr = var.public_subnet-cidr[count.index]
  public_subnet-cidr = var.public_subnet-cidr[0] #e
  #public_subnet-az   = count.index % 2 == 0 ? var.public_subnet-az[0] : var.public_subnet-az[1]
  public_subnet-az   = var.public_subnet-az[0] #e
  #public_subnet-name = var.public_subnet-name[count.index]
  public_subnet-name = var.public_subnet-name[0] #e
}

#Private Subnet
module "private_subnet" { #Private Subnet
  source              = "./modules/t-aws-private_subnet"
  count              = length(var.private_subnet-cidr)

  vpc-id              = module.vpc.vpc-id

  private_subnet-cidr = var.private_subnet-cidr[count.index]

  private_subnet-az   = count.index % 2 == 0 ? var.private_subnet-az[0] : var.private_subnet-az[1]

  private_subnet-name = var.private_subnet-name[count.index]
}

#DB subnet
module "db_subnet" { #DB Subnet
  source 	      = "./modules/t-aws-private_subnet"
  #count 	      = length(var.db_subnet-cidr)
  count 	      = 1 #e

  vpc-id 	      = module.vpc.vpc-id

  #private_subnet-cidr = var.db_subnet-cidr[count.index]
  private_subnet-cidr = var.db_subnet-cidr[0] #e

  #private_subnet-az   = count.index % 2 == 0 ? var.db_subnet-az[0] : var.db_subnet-az[1]
  private_subnet-az   = var.db_subnet-az[0] #e

  #private_subnet-name = var.db_subnet-name[count.index]
  private_subnet-name = var.db_subnet-name[0] #e
}

#Securty Group for DB
module "sg-db" { #
  source    = "./modules/t-aws-sg"
  sg-vpc_id = module.vpc.vpc-id 
  sg-name   = "sg_db" #sg 이름에 하이픈('-') 사용 불가
}

#Security Group Rule for sg-db: Allow Ingress SSH Traffic from Private Subent
module "sg_rule-db-allow_ingress_ssh" {
  source = "./modules/t-aws-sg_rule-cidr"
  sg_rule-type = "ingress"
  sg_rule-from_port = 22
  sg_rule-to_port = 22
  sg_rule-protocol = "tcp"
  sg_rule-sg_id = module.sg-db.sg-id #규칙을 적용할 sg
  sg_rule-cidr_blocks = var.private_subnet-cidr #허용할 cidr
}

#Security Group Rule for sg-db: Allow Ingress HTTP Traffic from Private Subent
module "sg_rule-db-allow_ingress_http" {
  source = "./modules/t-aws-sg_rule-cidr"
  sg_rule-type = "ingress"
  sg_rule-from_port = 80
  sg_rule-to_port = 80
  sg_rule-protocol = "tcp"
  sg_rule-sg_id = module.sg-db.sg-id #규칙을 적용할 sg
  sg_rule-cidr_blocks = var.private_subnet-cidr #허용할 cidr
}

#Security Group Rule for sg-db: Allow Ingress MySQL Traffic from Private Subent
module "sg_rule-db-allow_ingress_MySQL" {
  source = "./modules/t-aws-sg_rule-cidr"
  sg_rule-type = "ingress"
  sg_rule-from_port = 3306
  sg_rule-to_port = 3306
  sg_rule-protocol = "tcp"
  sg_rule-sg_id = module.sg-db.sg-id #규칙을 적용할 sg
  sg_rule-cidr_blocks = var.private_subnet-cidr #허용할 cidr
}

#Internet Gateway
module "igw" { 
  source = "./modules/t-aws-igw"
  vpc-id = module.vpc.vpc-id
}

#Route Table: From 0.0.0.0/0 to IGW
module "route_table-igw_to_vpc" {
  source     = "./modules/t-aws-rt-igw"
  vpc-id     = module.vpc.vpc-id
  gateway-id = module.igw.igw-id
  rt-usage   = "igw"
}

#Associate Route Table: route_table_igw_to_vpc with Public Subnet
module "rta-internet_to_public_subnet" {
  source    = "./modules/t-aws-rta"
  #count     = length(module.public_subnet) #이만큼 반복해서 모듈 생성
  count	    = 1 #e

  #subnet-id = module.public_subnet[count.index].public_subnet-id
  subnet-id = module.public_subnet[0].public_subnet-id #e

  rt-id     = module.route_table-igw_to_vpc.rt-id
}

#Elastic IP 
module "eip" {
  source = "./modules/t-aws-eip"

  #count  = length(module.private_subnet)
  count = 1 #e
}

#NAT Gateway 
module "nat" { #NAT Gateway
  #count = length(module.public_subnet) 
  count = 1 #e

  source    = "./modules/t-aws-nat"

  #eip-id    = module.eip.eip-id
  eip-id    = module.eip[count.index].eip-id #e

  #subnet-id = module.public_subnet[count.index].public_subnet-id  #nat는 public subnet에 위치해야 함
  subnet-id = module.public_subnet[0].public_subnet-id  #e

  #nat-name  = "practice-nat${count.index}"
  nat-name  = "practice-nat" #e
}


#Route Table: 0.0.0.0/0 to NAT
module "route_table-internet_to_nat" { 
  source     = "./modules/t-aws-rt-nat"

  #count      = length(module.private_subnet)
  count      = 1 #e

  vpc-id     = module.vpc.vpc-id

  #gateway-id = module.nat[count.index].nat-id
  gateway-id = module.nat[0].nat-id #e

  rt-usage   = "nat"
}

#Associate Route Table: route_table_internet_to_nat with Private Subnet
module "rta-internet_to_nat" { 
  #count = length(module.private_subnet)
  count = 1 #e

  source = "./modules/t-aws-rta"

  #subnet-id = module.private_subnet[count.index].private_subnet-id
  subnet-id = module.private_subnet[0].private_subnet-id #e

  #rt-id = module.route_table-internet_to_nat[count.index].rt-id
  rt-id = module.route_table-internet_to_nat[0].rt-id #e
}


#Public EC2
#module "ec2_public" {
#  source       = "./modules/t-aws-ec2"
#  for_each     = { for i, subnet in module.public_subnet : i => subnet["public_subnet-id"] } # public subnet을 우선으로 반복
#  ec2-subnet   = each.value
#  ec2-az       = each.key % 2 == 0 ? "ap-northeast-2a" : "ap-northeast-2c"
#  ec2-key_name = data.aws_key_pair.example.key_name
#  ec2-usage    = "public-${each.key}"
#  ec2-sg       = [module.sg-public_ec2.sg-id]
#}

#Securty Group for Public EC2
module "sg-public_ec2" { #
  source    = "./modules/t-aws-sg"
  sg-vpc_id = module.vpc.vpc-id 
  sg-name   = "sg_public" #sg 이름에 하이픈('-') 사용 불가
}

#Security Group Rule for sg-public_ec2: Allow Ingress SSH Traffic from Internet
module "sg_rule-public_ec2-allow_ingress_ssh-internet" {
  source = "./modules/t-aws-sg_rule-cidr"
  sg_rule-type = "ingress"
  sg_rule-from_port = 22
  sg_rule-to_port = 22
  sg_rule-protocol = "tcp"
  sg_rule-sg_id = module.sg-public_ec2.sg-id #규칙을 적용할 sg
  sg_rule-cidr_blocks = local.all_ips #허용할 cidr
}

#Security Group Rule for sg-public_ec2: Allow Egress all Traffic
module "sg_rule-public_ec2-allow_egress-all_traffic" {
  source = "./modules/t-aws-sg_rule-cidr"
  sg_rule-type = "egress"
  sg_rule-from_port = local.any_port
  sg_rule-to_port = local.any_port
  sg_rule-protocol = local.any_protocol
  sg_rule-sg_id = module.sg-public_ec2.sg-id #규칙을 적용할 sg
  sg_rule-cidr_blocks = local.all_ips #허용할 cidr
}
################################ EKS Configuration ###########################
module "eks-cluster"{
  count			= var.create_cluster ? 1 : 0
  source 		= "./modules/t-aws-eks/cluster"
  cluster-name 		= var.cluster-name
  cluster-sg		= [module.sg-cluster[0].sg-id,] #클러스터 메인 보안 그룹
  cluster-role_arn 	= module.eks-role[0].arn
  cluster-subnet_ids 	= [ for i in module.private_subnet: i["private_subnet-id"] ]
}

module "eks-role"{
  count			= var.create_cluster ? 1 : 0
  source = "./modules/t-aws-eks/role/eks_role"
}

module "sg-cluster" {
  count			= var.create_cluster ? 1 : 0
  source     = "./modules/t-aws-sg"
  sg-vpc_id  = module.vpc.vpc-id
  sg-name    = "sg_cluster"
}

module "sg-node_group" { 
  count			= var.create_cluster ? 1 : 0
  source     = "./modules/t-aws-sg"
  sg-vpc_id  = module.vpc.vpc-id
  sg-name    = "sg_nodegroup"
}

#module "sg_rule-cluster" {
#  source 	       = "./modules/t-aws-sg_rule-sg"
#  sg_rule-type         = "ingress"
#  sg_rule-from_port    = 443
#  sg_rule-to_port      = 443
#  sg_rule-protocol     = "tcp"
#  sg_rule-sg_id	       = module.sg-cluster.sg-id #규칙을 적용할 sg
#  sg_rule-source_sg_id = module.sg-node_group.sg-id #허용할 sg
#}

#private subnet끼리의 모든 통신 허용
module "sg_rule_ng-allow_private_subnet" {
  count		            = var.create_cluster ? 1 : 0
  source      		    = "./modules/t-aws-sg_rule-cidr"
  sg_rule-type              = "ingress"
  sg_rule-from_port         = local.any_port
  sg_rule-to_port           = local.any_port
  sg_rule-protocol          = local.any_protocol
  sg_rule-sg_id             = module.sg-node_group[0].sg-id
  sg_rule-cidr_blocks	    = ["10.0.0.0/24", "10.0.2.0/24"] #허용할 cidr block
}

#노드 그룹의 sg에서 클러스터 sg의 ingress traffic 허용
module "sg_rule-ng-allow_https-from_cluster" {
  count		       = var.create_cluster ? 1 : 0
  source 	       = "./modules/t-aws-sg_rule-sg"
  sg_rule-type         = "ingress"
  sg_rule-from_port    = 443
  sg_rule-to_port      = 443
  sg_rule-protocol     = "tcp"
  sg_rule-sg_id        = module.sg-node_group[0].sg-id #규칙을 적용할 sg
  sg_rule-source_sg_id = module.sg-cluster[0].sg-id #허용할 sg
}

#노드 그룹의 sg에서 public subnet의 ssh ingress 허용
module "sg_rule-ng-allow_ssh-from_public_subnet" { 
  count			= var.create_cluster ? 1 : 0
  source 	       = "./modules/t-aws-sg_rule-sg"
  sg_rule-type 	       = "ingress"
  sg_rule-from_port    = 22
  sg_rule-to_port      = 22
  sg_rule-protocol     = "tcp"
  sg_rule-sg_id        = module.sg-node_group[0].sg-id #규칙을 적용할 sg
  sg_rule-source_sg_id = module.sg-public_ec2.sg-id #허용할 sg
}

module "sg_rule-ng-allow_Kubelet" {
  count			= var.create_cluster ? 1 : 0
  source 	       = "./modules/t-aws-sg_rule-sg"
  description	       = "Kubelet API"
  sg_rule-type 	       = "ingress"
  sg_rule-from_port    = 10250
  sg_rule-to_port      = 10250
  sg_rule-protocol     = "tcp"
  sg_rule-sg_id        = module.sg-node_group[0].sg-id #규칙을 적용할 sg
  sg_rule-source_sg_id = module.eks-cluster[0].cluster-sg #허용할 sg
}


module "sg_rule-ng-allow_kube-porxy" {
  count			= var.create_cluster ? 1 : 0
  source 	       = "./modules/t-aws-sg_rule-sg"
  description	       = "kube-proxy"
  sg_rule-type 	       = "ingress"
  sg_rule-from_port    = 10256
  sg_rule-to_port      = 10256
  sg_rule-protocol     = "tcp"
  sg_rule-sg_id        = module.sg-node_group[0].sg-id #규칙을 적용할 sg
  sg_rule-source_sg_id = module.eks-cluster[0].cluster-sg #허용할 sg
}


module "sg_rule-ng-allow_NodePort" {
  count			= var.create_cluster ? 1 : 0
  source 	       = "./modules/t-aws-sg_rule-sg"
  description	       = "NodePort Services"
  sg_rule-type 	       = "ingress"
  sg_rule-from_port    = 30000
  sg_rule-to_port      = 32767
  sg_rule-protocol     = "tcp"
  sg_rule-sg_id        = module.sg-node_group[0].sg-id #규칙을 적용할 sg
  sg_rule-source_sg_id = module.eks-cluster[0].cluster-sg #허용할 sg
}


module "sg_rule-ng-allow_webhook" {
  count			= var.create_cluster ? 1 : 0
  source 	       = "./modules/t-aws-sg_rule-sg"
  description	       = "allow webhook"
  sg_rule-type 	       = "ingress"
  sg_rule-from_port    = 9443
  sg_rule-to_port      = 9443
  sg_rule-protocol     = "tcp"
  sg_rule-sg_id        = module.sg-node_group[0].sg-id #규칙을 적용할 sg
  sg_rule-source_sg_id = module.eks-cluster[0].cluster-sg #허용할 sg
}

#클러스터 메인 보안 그룹에서 노드 그룹의 https ingress 허용
module "sg_rule-main_cluster" {
  count			= var.create_cluster ? 1 : 0
  source = "./modules/t-aws-sg_rule-sg"
  sg_rule-type = "ingress"
  sg_rule-from_port = 443
  sg_rule-to_port = 443
  sg_rule-protocol = "tcp"
  sg_rule-sg_id = module.eks-cluster[0].cluster-sg #규칙을 적용할 sg
  sg_rule-source_sg_id = module.sg-node_group[0].sg-id #허용할 sg
  depends_on = [module.eks-cluster]
}

module "sg_rule-main_cluster-allow_kube_API" { 
  count			= var.create_cluster ? 1 : 0
  source = "./modules/t-aws-sg_rule-sg"
  description = "Kubernetes API server"
  sg_rule-type = "ingress"
  sg_rule-from_port = 6443
  sg_rule-to_port = 6443
  sg_rule-protocol = "tcp"
  sg_rule-sg_id = module.eks-cluster[0].cluster-sg #규칙을 적용할 sg
  sg_rule-source_sg_id = module.sg-node_group[0].sg-id #허용할 sg
  depends_on = [module.eks-cluster]
}


module "sg_rule-main_cluster-allow_etcd" { 
  count			= var.create_cluster ? 1 : 0
  source = "./modules/t-aws-sg_rule-sg"
  description = "etcd server clien API"
  sg_rule-type = "ingress"
  sg_rule-from_port = 2379
  sg_rule-to_port = 2380
  sg_rule-protocol = "tcp"
  sg_rule-sg_id = module.eks-cluster[0].cluster-sg #규칙을 적용할 sg
  sg_rule-source_sg_id = module.sg-node_group[0].sg-id #허용할 sg
  depends_on = [module.eks-cluster]
}


module "sg_rule-main_cluster-allow_kubelet" { 
  count			= var.create_cluster ? 1 : 0
  source = "./modules/t-aws-sg_rule-sg"
  description = "kubelet API"
  sg_rule-type = "ingress"
  sg_rule-from_port = 10250
  sg_rule-to_port = 10250
  sg_rule-protocol = "tcp"
  sg_rule-sg_id = module.eks-cluster[0].cluster-sg #규칙을 적용할 sg
  sg_rule-source_sg_id = module.sg-node_group[0].sg-id #허용할 sg
  depends_on = [module.eks-cluster]
}


module "sg_rule-main_cluster-allow_kube-scheduler" { 
  count			= var.create_cluster ? 1 : 0
  source = "./modules/t-aws-sg_rule-sg"
  description = "kube-scheduler"
  sg_rule-type = "ingress"
  sg_rule-from_port = 10259
  sg_rule-to_port = 10259
  sg_rule-protocol = "tcp"
  sg_rule-sg_id = module.eks-cluster[0].cluster-sg #규칙을 적용할 sg
  sg_rule-source_sg_id = module.sg-node_group[0].sg-id #허용할 sg
  depends_on = [module.eks-cluster]
}


module "sg_rule-main_cluster-allow_kube-controller-manager" { 
  count			= var.create_cluster ? 1 : 0
  source = "./modules/t-aws-sg_rule-sg"
  description = "kube-controller-manager"
  sg_rule-type = "ingress"
  sg_rule-from_port = 10257
  sg_rule-to_port = 10257
  sg_rule-protocol = "tcp"
  sg_rule-sg_id = module.eks-cluster[0].cluster-sg #규칙을 적용할 sg
  sg_rule-source_sg_id = module.sg-node_group[0].sg-id #허용할 sg
  depends_on = [module.eks-cluster]
}

module "sg_rule-main_cluster-allow_webhook" { 
  count			= var.create_cluster ? 1 : 0
  source = "./modules/t-aws-sg_rule-sg"
  description = "allow webhook"
  sg_rule-type = "ingress"
  sg_rule-from_port = 9443
  sg_rule-to_port = 9443
  sg_rule-protocol = "tcp"
  sg_rule-sg_id = module.eks-cluster[0].cluster-sg #규칙을 적용할 sg
  sg_rule-source_sg_id = module.sg-node_group[0].sg-id #허용할 sg
  depends_on = [module.eks-cluster]
}

#클러스터 메인 보안 그룹에, private subnet으로부터 온 DNS 포트 53번 허용
module "sg_rule-main_cluster-allow_coreDNS-53" {
  count			= var.create_cluster ? 1 : 0
  source = "./modules/t-aws-sg_rule-cidr"
  sg_rule-type = "ingress"
  sg_rule-from_port = 53
  sg_rule-to_port = 53
  sg_rule-protocol = "tcp"
  #sg_rule-sg_id = module.eks-cluster[0].cluster-sg #규칙을 적용할 sg
  sg_rule-sg_id = module.sg-node_group[0].sg-id #규칙을 적용할 sg
  sg_rule-cidr_blocks = ["10.0.0.0/24", "10.0.2.0/24"] #허용할 cidr
}


#클러스터 메인 보안 그룹에, private subnet으로부터 온 codrDNS 포트 9153번 허용
module "sg_rule-main_cluster-allow_coreDNS-9153" {
  count			= var.create_cluster ? 1 : 0
  source = "./modules/t-aws-sg_rule-cidr"
  sg_rule-type = "ingress"
  sg_rule-from_port = 9153
  sg_rule-to_port = 9153
  sg_rule-protocol = "tcp"
  #sg_rule-sg_id = module.eks-cluster[0].cluster-sg #규칙을 적용할 sg
  sg_rule-sg_id = module.sg-node_group[0].sg-id #규칙을 적용할 sg
  sg_rule-cidr_blocks = ["10.0.0.0/24", "10.0.2.0/24"] #허용할 cidr
}
module "sg_rule-cluster-outbound" {
  count			= var.create_cluster ? 1 : 0
  source = "./modules/t-aws-sg_rule-cidr"
  sg_rule-type = "egress"
  sg_rule-from_port = local.any_port
  sg_rule-to_port = local.any_port
  sg_rule-protocol = local.any_protocol
  sg_rule-sg_id = module.sg-cluster[0].sg-id #규칙을 적용할 sg
  sg_rule-cidr_blocks = local.all_ips #허용할 cidr
}

module "sg_rule-ng-outbound" {
  count			= var.create_cluster ? 1 : 0
  source = "./modules/t-aws-sg_rule-cidr"
  sg_rule-type = "egress"
  sg_rule-from_port = local.any_port
  sg_rule-to_port = local.any_port
  sg_rule-protocol = local.any_protocol
  sg_rule-sg_id = module.sg-node_group[0].sg-id #규칙을 적용할 sg
  sg_rule-cidr_blocks = local.all_ips #허용할 cidr
}


#role of node_group
module "ng-role"{
  count			= var.create_cluster ? 1 : 0
  source = "./modules/t-aws-eks/role/ng_role"
}

#launch template for node_group
module "lt-ng"{
  count		= var.create_cluster ? 1 : 0
  source 	= "./modules/t-aws-launch_template"
  lt-sg 	= [module.sg-node_group[0].sg-id]
  lt-key_name	= data.aws_key_pair.example.key_name
  cluster-name 	= module.eks-cluster[0].cluster-name
  aws_access_key_id = var.AWS_ACCESS_KEY
  aws_access_key_secret = var.AWS_SECRET_KEY
  region = var.AWS_REGION
}

module "node_group"{
  #for_each         = var.create_cluster ? {for i, subnet in module.private_subnet: i => subnet} : {}
  count		   = 1 #e

  source 	   = "./modules/t-aws-eks/ng"

  cluster-name     = module.eks-cluster[0].cluster-name
  #ng-name 	   = "practice-ng-${each.key}"
  ng-name 	   = "practice-ng" #e

  ng-role_arn      = module.ng-role[0].arn

  #subnet-id	   = [each.value["private_subnet-id"]]
  subnet-id	   = [module.private_subnet[0].private_subnet-id] #e

  ng-lt_id         = module.lt-ng[0].lt_id 
  depends_on       = [module.eks-cluster, module.ng-role]

  #ng-labels = { #얘도 둘다 2c 나옴
  #	"subnet" = "private_subnet-${each.key == "0" ? "2a" : "2c"}"
  #} 
  ng-labels = { #e
  	"subnet" = "private_subnet-2a" 
  } 
}


#OCID 공급자 연결
module "openid_connect_provider"{
  count			= var.create_cluster ? 1 : 0
  source ="./modules/t-aws-openid_connect_provider"
  client_id_list = ["sts.amazonaws.com"]
  url = module.eks-cluster[0].oidc_url
  depends_on = [module.eks-cluster]
}

#add on 
module "addon-aws-ebs-csi-driver"{
  count			= var.create_cluster ? 1 : 0
  source = "./modules/t-aws-eks/addon/"
  addon-cluster_name = module.eks-cluster[0].cluster-name
  addon-name = "aws-ebs-csi-driver"
  addon-role = module.role-ecd-sa[0].arn
  depends_on = [module.node_group]
}

############################ Helm Configuration ###########################

#Role for aws-loadbalacner-controller sa
module "role-alc-sa"{
  count			= var.create_cluster ? 1 : 0
  source = "./modules/t-aws-eks/role/alc"
  role-alc_role_name = "alb-ingress-sa-role"
  role-alc-oidc_without_https = module.eks-cluster[0].oidc_url_without_https
  role-alc-namespace = module.sa-alc[0].sa-namespace
  role-alc-sa_name = module.sa-alc[0].sa-name
  depends_on = [module.eks-cluster]
}

#Service Account for aws-loadbalacner-controller
module "sa-alc"{ 
  count			= var.create_cluster ? 1 : 0
  source = "./modules/t-k8s-sa"
  sa-labels = {
    "app.kubernetes.io/component" = "controller" #구성 요소
    "app.kubernetes.io/name" = "aws-load-balacner-controller" #애플리케이션 이름
  }
  sa-name = "aws-load-balancer-controller"
  sa-namespace = "kube-system"
  sa-annotations = {
    "eks.amazonaws.com/role-arn" = "arn:aws:iam::992382518527:role/alb-ingress-sa-role"
  }
  depends_on = [module.eks-cluster]
}


#Role of EBS-CSI-DRIVER sa
module "role-ecd-sa"{
  count			= var.create_cluster ? 1 : 0
  source = "./modules/t-aws-eks/role/ebs-csi-driver"
  role-ecd_role_name = "ebs-csi-controller-sa"
  role-ecd-oidc_without_https = module.eks-cluster[0].oidc_url_without_https
  role-ecd-namespace = "kube-system"
  role-ecd-sa_name = "ebs-csi-controller-sa"
  depends_on = [module.eks-cluster]
}

#Service Account for EBS-CSI-Driver
#addon 구성 시 자동으로 생성돼서 필요 없음
#module "sa-ecd"{
#  source = "./modules/t-k8s-sa"
#  sa-labels = {
#    "app.kubernetes.io/component" = "controller" #구성 요소
#    "app.kubernetes.io/name" = "ebs-csi-controller" #애플리케이션 이름
#    
#  }
#  sa-name = "ebs-csi-controller-sa"
#  sa-namespace = "kube-system"
#  sa-annotations = {
#    "eks.amazonaws.com/role-arn" = "arn:aws:iam::992382518527:role/ebs-csi-controller-sa"
#  }
#  depends_on = [module.eks-cluster]
#}


############################ RDS Configuration ###########################
resource "aws_db_subnet_group" "default" {
  count = var.create_rds ? 1 : 0
  name       = "main"
  subnet_ids = [module.db_subnet[0].private_subnet-id, module.db_subnet[1].private_subnet-id]
  tags = {
    Name = "My DB subnet group"
  }
}

module "rds" {
  source = "./modules/t-aws-rds"
  count = var.create_rds ? 1 : 0
  rds-allocated_storage    = 10
  rds-db_name              = "yyk_db" #DBName must begin with a letter and contain only alphanumeric characters.
  rds-engine               = "mysql"
  rds-engine_version       = "8.0"
  rds-instance_class       = "db.t3.micro"
  rds-username             = "yyk"
  rds-password             = var.rds-password
  rds-db_subnet_group_name = aws_db_subnet_group.default[0].name
  rds-vpc_security_group_ids = [module.sg-db.sg-id]
  rds-multi_az = true
}

#db 정보를 json 파일로 저장
resource "local_file" "outputs" {
  count = var.create_rds ? 1 : 0
  content  = jsonencode({
    db_endpoint = module.rds[0].db_endpoint,
    db_name     = module.rds[0].db_name,
    db_user     = module.rds[0].db_user,
    db_password = module.rds[0].db_password
  })
  filename = "./yyk-server/terraform_outputs.json"
}


#CRUD 이미지 빌드하기
resource "null_resource" "build_image" {
  count = var.create_rds ? 1 : 0
  depends_on = [local_file.outputs] #output update하고 build해야 함
  provisioner "local-exec" {
    command = <<EOT
      docker build -t dminus251/test:latest ./yyk-server/
      docker push dminus251/test:latest
    EOT
  }
}
