output "db_endpoint" {
  value = var.create_rds ? module.rds[0].db_endpoint : null
}
output "db_name" {
  value = var.create_rds ? module.rds[0].db_name : null
}

output "db_user" {
  value = var.create_rds ? module.rds[0].db_user : null
}

output "db_password" {
  value = var.create_rds ? module.rds[0].db_password : null
  sensitive = true
}

output "private_subent"{
  value = module.private_subnet
}

output "node_group"{
  value = module.node_group
}

output "nodegroup_map"{
  value =  {for i, subnet in module.private_subnet: i => subnet}
}

output "private_subnet"{
  value = module.private_subnet
}
