resource "google_compute_instance_template" "traefik-instance-template" {

  name_prefix  = "traefik-instance-template-"
  machine_type = var.traefik_server_size
  region       = var.region

  disk {
    source_image = var.base_image_name
    auto_delete  = true
    boot         = true
    disk_type = "pd-standard"
  }

  network_interface {
    subnetwork = var.cluster_subnet_name
    subnetwork_project = var.shared_vpc_host_project_id
  }

  tags = [
    "allow-icmp", "allow-ssh", "consul-fw-ingress", "consul-sidecar-fw-ingress",
    "nomad-client-fw-ingress", "fw-allow-network-lb-health-checks",  #"traefik-public-fw",
    # tag for go-discover:
    "traefik-server", "consul-client", "nomad-client",
  ]

  metadata = {
    enable-oslogin = "TRUE"
    node-type = "traefik"
    num-hashi-servers = var.num_hashi_servers
    ssh-keys = "${var.cluster_tf_service_account_username}:${file(var.cluster_tf_service_account_ssh_public_key_filepath)}"
    project-info = file(var.project_info_filepath)
  }
  metadata_startup_script = file("./scripts/hashi_vm_startup.sh")

  labels = {
    node_type = "traefik"
  }

  service_account {
    email = var.cluster_vm_service_account_email
    scopes = ["userinfo-email", "compute-ro", "storage-ro", "cloud-platform"]
  }

  scheduling {
    preemptible = false
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "google_compute_region_instance_group_manager" "traefik-instance-group-manager" {
  name               = "traefik-instance-group-manager"
  base_instance_name = "traefik-instance"
  version {
    instance_template  = google_compute_instance_template.traefik-instance-template.self_link
  }
  region = var.region

  target_size = var.num_traefik_servers

  depends_on = [
    google_compute_instance.hashi-servers[0],
    google_compute_instance.hashi-servers[1],
    google_compute_instance.hashi-servers[2]
  ]
}

data "google_compute_region_instance_group" "data_source" {
  self_link = google_compute_region_instance_group_manager.traefik-instance-group-manager.instance_group
}