locals {
  hashi_server_tags = [
    "allow-icmp", "allow-ssh", "consul-fw-ingress", "nomad-server-fw-ingress",
    # tags for Consul/Nomad's Cloud auto-join and go-discover:
    "consul-server", "nomad-server",
  ]
}


resource "google_compute_instance" "hashi-servers" {
  name         = "hashi-server-${count.index + 1}"

  machine_type = var.hashi_server_size

  zone         = var.zones_allowed[count.index % length(var.zones_allowed)]

  count = var.num_hashi_servers

  boot_disk {
    initialize_params {
      image = var.base_image_name
      type = "pd-ssd"
    }
    auto_delete = true
  }

  network_interface {
    subnetwork = var.cluster_subnet_name
    subnetwork_project = var.shared_vpc_host_project_id

    # add external ip to hashi-server-1 if expose_dashboards == true
    dynamic "access_config" {
      for_each = (var.expose_dashboards && count.index == 0) ? [1] : []
      content {}
    }
  }

  metadata = {
    enable-oslogin = "TRUE"
    node-type = "hashi_server"
    self-elect-as-consul-leader = count.index == 0 ? "TRUE" : "FALSE"
    num-hashi-servers = var.num_hashi_servers
    ssh-keys = "${var.cluster_tf_service_account_username}:${file(var.cluster_tf_service_account_ssh_public_key_filepath)}"
    project-info = file(var.project_info_filepath)
  }
  metadata_startup_script = file("./startup_scripts/initialize_instance.sh")

  labels = {
    startup_status = "stopped"
    node_type = "hashi_server"
  }

  allow_stopping_for_update = true  # set to true when you add a service account
  service_account {
    email = count.index == 0 ? var.cluster_tf_service_account_email : var.cluster_vm_service_account_email
    scopes = ["userinfo-email", "compute-ro", "storage-ro", "cloud-platform"]
  }

  /*
  scheduling {
    # if cheap_mode is true, make all but hashi-servers.0 preemptible
    preemptible = var.cheap_mode && count.index > 0 ? true : false
    automatic_restart = var.cheap_mode && count.index > 0 ? false : true   # must be false when preemptible
  }*/
  scheduling {
    preemptible = false
    automatic_restart = true
  }

  tags = var.expose_dashboards ? concat(local.hashi_server_tags, ["nomad-consul-dashboards-fw-ingress", "hashi-server-${count.index + 1}"]) : concat(local.hashi_server_tags, ["hashi-server-${count.index + 1}"])

}

# todo: read this on outage recovery: https://learn.hashicorp.com/consul/day-2-operations/outage
