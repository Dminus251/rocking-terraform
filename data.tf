#k8s provider의 token을 얻는 데 사용
data "aws_eks_cluster_auth" "example" {
  count = var.create_cluster ? 1 : 0
  name = module.eks-cluster[0].cluster-name
  depends_on = [module.eks-cluster] #클러스터 먼저 생성돼야 cluster-name output 사용 가능
}

#key_name이 0827인 key_pair 찾아옴
data "aws_key_pair" "example" {
  key_name           = "0827"
  include_public_key = true
}
