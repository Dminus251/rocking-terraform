variable "sg_rule-type" {
  type = string
}
variable "description"{
  type = string
  default = ""
}
variable "sg_rule-from_port" {
  type = number
}
variable "sg_rule-to_port" {
  type = number
}

variable "sg_rule-protocol" {
  type = string
}

variable "sg_rule-sg_id" {
  type = string
}
variable "sg_rule-cidr_blocks" {
  type = list(string)
}
