
resource "google_compute_instance_template" "hashi-client-template" {
  name_prefix  = "hashi-client-template-"
  machine_type = var.hashi_client_size
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
    "allow-icmp", "allow-ssh", "consul-fw-ingress",
    "consul-sidecar-fw-ingress", "nomad-client-fw-ingress",
    # tags for go-discover:
    "consul-client", "nomad-client",
  ]

  metadata = {
    enable-oslogin = "TRUE"
    node-type = "hashi-client"
    num-hashi-servers = var.num_hashi_servers
    ssh-keys = "${var.cluster_tf_service_account_username}:${file(var.cluster_tf_service_account_ssh_public_key_filepath)}"
    project-info = file(var.project_info_filepath)
  }
  metadata_startup_script = file("./startup_scripts/initialize_instance.sh")

  labels = {
    startup_status = "stopped"
    node_type = "hashi_client"
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


resource "google_compute_region_instance_group_manager" "hashi-client-group-manager" {
  name               = "hashi-client-group-manager"
  base_instance_name = "hashi-client"
  version {
    instance_template  = google_compute_instance_template.hashi-client-template.self_link
  }
  region = var.region

  # target_size = var.num_hashi_clients   including this seems to prohibit dynamically updating num_hashi_clients? Presumably due to a conflict between having a target_size paired with an autoscaler.

  depends_on = [
    google_compute_instance.hashi-servers[0],
    google_compute_instance.hashi-servers[1],
    google_compute_instance.hashi-servers[2]
  ]
}

# consider using spot-inst elastigroup for low-cost clustering: https://help.spot.io/provisioning-ci-cd-sdk/provisioning-tools/terraform/resources/terraform-v-3/elastigroup-gcp/
resource "google_compute_region_autoscaler" "hashi-client-group-autoscaler" {
  name    = "hashi-client-group-autoscaler"
  region  = var.region

  target  = google_compute_region_instance_group_manager.hashi-client-group-manager.self_link

  autoscaling_policy {
    max_replicas               = var.num_hashi_clients
    min_replicas               = var.num_hashi_clients
  }
}
