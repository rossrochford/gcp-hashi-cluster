
variable "project_info_filepath" {
  type = string
  default = "../../build/project-info.json"
}

variable "cluster_service_project_id" {
  type = string
}

variable "shared_vpc_host_project_id" {
  type = string
}

variable "region" {}

variable "zones_allowed" {
  type = list(string)
}

variable "cluster_vm_service_account_email" {}

variable "cluster_tf_service_account_email" {}

variable "cluster_tf_service_account_username" {}

variable "cluster_tf_service_account_ssh_public_key_filepath" {}

variable "cluster_tf_service_account_ssh_private_key_filepath" {}

variable "cluster_tf_service_account_credentials_filepath" {}

variable "vpc_tf_service_account_credentials_filepath" {}

variable "shared_vpc_network_name" {}

variable "cluster_subnet_name" {}


variable "base_image_name" {
  default = "hashi-cluster-base-v20200607"  # v20200607
}

variable "domain_name" {}

variable "sub_domains" {
  type = list(string)
}

variable "num_hashi_servers" {
  # note: when changing this, you may also wish to update the "bootstrap_expect" Nomad config
  type = number
  default = 3

  validation {
    condition     = contains([3, 5, 7], var.num_hashi_servers)
    error_message = "Invalid value for: num_hashi_servers, must be 3, 5 or 7."
  }
}


variable "hashi_server_size" {
  type = string
  default = "n1-standard-1"  # 3.75 GB RAM
}


variable "num_hashi_clients" {
  type = number
  default = 1
}

variable "hashi_client_size" {
  type = string
  default = "n1-standard-2"  # 7.5 GB RAM
}

variable "vault_server_size" {
  type = string
  default = "n1-standard-1"  # 3.75 GB RAM
}

variable "num_vault_servers" {
  type = number
}

variable "num_traefik_servers" {}


variable "expose_dashboards" {
  # This adds a public IP to hashi-server-1 so you can view the dashboards in your browser. This is
  # useful for inspecting Consul or Nomad if the Traefik node is inaccessible.
  type = bool
  default = false

}

variable "load_balancer_public_ip_address" {
  type = string
}

variable "http_timeout_sec" {
  type = number
}

variable "lb_disable_tls" {
  default = false
}

variable "traefik_server_size" {
  type = string
  default = "n1-standard-1"  # 3.75 GB RAM
}


variable "kms_encryption_key" {
  type = string
}

variable "kms_encryption_key_ring" {
  type = string
}
