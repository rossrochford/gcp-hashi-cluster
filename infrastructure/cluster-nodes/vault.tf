
resource "google_compute_instance" "vault-servers" {
  count = var.num_vault_servers

  name = "vault-server-${count.index + 1}"

  machine_type = var.vault_server_size

  # ensure vault servers are placed in more that one zone
  zone         = var.zones_allowed[count.index % length(var.zones_allowed)]

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
  }

  metadata = {
    enable-oslogin = "TRUE"
    node-type = "vault"
    num-hashi-servers = var.num_hashi_servers
    ssh-keys = "${var.cluster_tf_service_account_username}:${file(var.cluster_tf_service_account_ssh_public_key_filepath)}"
    project-info = file(var.project_info_filepath)
  }
  metadata_startup_script = file("./scripts/hashi_vm_startup.sh")

  labels = {
    node_type = "vault"
  }

  allow_stopping_for_update = true  # set to true when you add a service account
  service_account {
    email = var.cluster_vm_service_account_email
    scopes = ["cloud-platform", "compute-rw", "userinfo-email", "storage-ro"]  # note: we're using compute-rw here
  }

  tags = [
    "allow-icmp", "allow-ssh", "consul-fw-ingress", "vault-fw-ingress",
    # tags for go-discover:
    "vault-server", "consul-client"
  ]

  depends_on = [
    google_compute_instance.hashi-servers[0],
    google_compute_instance.hashi-servers[1],
    google_compute_instance.hashi-servers[2]
  ]
}
