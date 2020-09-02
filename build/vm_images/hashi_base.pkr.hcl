
# note: GCP docs use a slightly different setup with Cloud Build: https://cloud.google.com/cloud-build/docs/building/build-vm-images-with-packer


variable "cluster_service_project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "base_image_name" {}

variable "container_registry_hostname" {
  type = string
}


variable "cluster_tf_service_account_credentials_filepath" {
  type = string
}

variable "cluster_tf_service_account_email" {
  type = string
}

variable "shared_vpc_host_project_id" {
  type = string
}

variable "shared_vpc_network_name" {
  type = string
}

variable "cluster_subnet_name" {
  type = string
}

variable "hashi_repo_directory" {
  type = string
}


variable "cluster_tf_service_account_username" {}
variable "cluster_tf_service_account_ssh_private_key_filepath" {}
variable "cluster_tf_service_account_ssh_public_key_filepath" {}


source "googlecompute" "hashi-cluster-base" {

  account_file = var.cluster_tf_service_account_credentials_filepath
  project_id = var.cluster_service_project_id

  service_account_email = var.cluster_tf_service_account_email

  source_image = "ubuntu-2004-focal-v20200810"
  source_image_family = "ubuntu-2004-lts"

  image_name = var.base_image_name

  zone = "${var.region}-a"

  enable_vtpm = true
  enable_integrity_monitoring = true

  network = var.shared_vpc_network_name
  network_project_id = var.shared_vpc_host_project_id
  subnetwork = var.cluster_subnet_name

  tags = ["allow-ssh"]

  ssh_username = var.cluster_tf_service_account_username

  communicator = "ssh"
  ssh_private_key_file = var.cluster_tf_service_account_ssh_private_key_filepath

  metadata = {
    ssh-keys = "${var.cluster_tf_service_account_username}:${file(var.cluster_tf_service_account_ssh_public_key_filepath)}"
    block-project-ssh-keys = "TRUE"
    enable-oslogin = "FALSE"
  }
}


build {

  sources = [
    "source.googlecompute.hashi-cluster-base"
  ]

  provisioner "shell" {
    inline = [

      "sudo apt-get update -y",
      "sudo apt-get upgrade -y",

      "sudo apt install -y apt-transport-https ca-certificates gnupg-agent curl vim",

      "sudo apt-get update -y",
      "sudo apt install -y software-properties-common net-tools",

      "sudo apt autoremove -y",
      "sudo apt-get update -y",
      "sudo apt install -y zip unzip npm nodejs jq python3-pip",

      "sudo apt-get update -y",

      "sudo reboot"
    ]
    expect_disconnect = true
  }

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /home/packer/scripts",
      "sudo mkdir -p /home/packer/services",
      "sudo chown ${var.cluster_tf_service_account_username}:${var.cluster_tf_service_account_username} /home/packer/scripts",
      "sudo chown ${var.cluster_tf_service_account_username}:${var.cluster_tf_service_account_username} /home/packer/services",

      "sudo mkdir -p /etc/traefik",
      "sudo chmod -R 0777 /etc/traefik",

      "sudo mkdir -p /home/${var.cluster_tf_service_account_username}/.docker/"  # should this be copied to /home/root/.docker?
    ]
  }

  provisioner "file" {
    source = "./scripts/"  # trailing slash is important (https://www.packer.io/docs/provisioners/file.html#directory-uploads)
    destination = "/home/packer/scripts"
  }

  provisioner "file" {
    source = "${var.hashi_repo_directory}/services/"
    destination = "/home/packer/services"
  }

  provisioner shell {
    inline = [
      "sudo /home/packer/scripts/install-stackdriver-agent.sh",
      "sudo /home/packer/scripts/install-fluentd.sh",
      "sudo /home/packer/scripts/install-ntp.sh",
      "sudo /home/packer/scripts/install-docker.sh",

      "sudo cp /home/packer/scripts/hashicorp-sudoers /etc/sudoers.d/hashicorp-sudoers",
      "sudo -H pip3 install -r /home/packer/scripts/python-requirements.txt",

      "sudo /home/packer/scripts/install-ansible.sh",

      "sudo /home/packer/scripts/install-consul.sh",
      "sudo /home/packer/scripts/install-consul-template.sh",
      "sudo /home/packer/scripts/install-go-discover.sh",
      "sudo /home/packer/scripts/install-nomad.sh",
      "sudo /home/packer/scripts/install-vault.sh",
      "sudo rm -rf /home/packer/"
    ]
  }

}


# to build run:
#   packer build hashi_base.pkr.hcl
