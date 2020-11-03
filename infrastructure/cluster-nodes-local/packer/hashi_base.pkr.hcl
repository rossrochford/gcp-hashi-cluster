
variable "hashi_repo_directory" {
  type = string
}

variable "cluster_tf_service_account_username" {}


source "vagrant" "example" {
  communicator = "ssh"
  source_path = "./ubuntu2004.box"
  provider = "virtualbox"
  add_force = true
  output_dir = "/home/ross/code/gcp-hashi-cluster/infrastructure/cluster-nodes-local/packer/base_image"
  #ssh_username = var.cluster_tf_service_account_username
  #ssh_password = "123456789"
}

build {
  sources = ["source.vagrant.example"]

  provisioner "shell" {
    inline = [

      "sudo apt-get update -y",
      "sudo apt-get upgrade -y",

      "sudo apt install -y apt-transport-https ca-certificates gnupg-agent curl vim",

      "sudo apt-get update -y",
      "sudo apt install -y software-properties-common net-tools",

      "sudo apt autoremove -y",
      "sudo apt-get update -y",
      "sudo apt install -y zip unzip npm nodejs jq python3-pip python3-testresources sshpass",

      "sudo apt-get update -y",

      #"sudo reboot"
    ]
    #expect_disconnect = true
  }

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /home/vagrant",
      #"sudo useradd --system --home /home/vagrant --shell /bin/false vagrant",
      "sudo useradd --system --home /home/ubuntu --shell /bin/false ubuntu",

      "sudo mkdir -p /home/vagrant/scripts",
      "sudo mkdir -p /home/vagrant/services",
      "sudo chown vagrant:vagrant /home/vagrant/scripts",
      "sudo chown vagrant:vagrant /home/vagrant/services",

      "sudo mkdir -p /etc/traefik",  # todo: do these in ansible playbook
      "sudo chmod -R 0777 /etc/traefik",

      "sudo mkdir -p /home/vagrant/.docker/"  # should this be copied to /home/root/.docker?
    ]
  }

  provisioner "file" {
    source = "${var.hashi_repo_directory}/build/vm_images/scripts/" # trailing slash is important (https://www.packer.io/docs/provisioners/file.html#directory-uploads)
    destination = "/home/vagrant/scripts"
  }

  provisioner "file" {
    source = "${var.hashi_repo_directory}/services/"
    destination = "/home/vagrant/services"
  }

  provisioner shell {
    inline = [
      "sudo chmod +x -R /home/vagrant/scripts/",
      #"sudo /home/vagrant/scripts/install-stackdriver-agent.sh",
      #"sudo /home/vagrant/scripts/install-fluentd.sh",
      #"sudo /home/vagrant/scripts/install-ntp.sh",
      "sudo /home/vagrant/scripts/install-docker.sh",

      "sudo cp /home/vagrant/scripts/hashicorp-sudoers /etc/sudoers.d/hashicorp-sudoers",
      "sudo -H pip3 install -r /home/vagrant/scripts/python-requirements.txt",

      "sudo /home/vagrant/scripts/install-ansible__vagrant.sh",

      "sudo /home/vagrant/scripts/install-consul.sh",
      "sudo /home/vagrant/scripts/install-consul-template.sh",
      "sudo /home/vagrant/scripts/install-go-discover.sh",
      "sudo /home/vagrant/scripts/install-nomad.sh",
      "sudo /home/vagrant/scripts/install-vault.sh",
      #"sudo rm -rf /home/vagrant/"
    ]
  }
}