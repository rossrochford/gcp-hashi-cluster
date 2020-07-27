
# some useful firewall examples:
# -ssh to/from bastion:  https://github.com/steinim/gcp-terraform-workshop/blob/e045b98f38ca53c774b5abda745ba701fa6c94f3/terraform/modules/network/main.tf
# -ssh access via IAP: https://github.com/GoogleCloudPlatform/gce-public-connectivity-terraform/blob/master/iap/vpc_firewall_rules.tf

# modules:
# - https://github.com/gruntwork-io/terraform-google-network/tree/master/modules/network-firewall  (for modules for VPCs in general see: https://github.com/gruntwork-io/terraform-google-network)

provider "google" {
  credentials = file(var.vpc_tf_service_account_credentials_filepath)
  project = var.shared_vpc_host_project_id
  region = var.region
}

/*
data "google_compute_subnetwork" "region-subnetwork" {
  name   = "default"
  region = var.region
  project = var.project_id
}

data "google_netblock_ip_ranges" "google-netblocks-ip-range" {
  range_type = "google-netblocks"
}


locals {
    private_subnet_cidr_range = data.google_compute_subnetwork.region-subnetwork.ip_cidr_range
}*/

locals {
  private_subnet_cidr_range = var.cluster_subnet_ip_range  #"10.132.0.0/20"
  # data.google_compute_subnetwork.region-subnetwork.ip_cidr_range
}

# todo: compare the firewall rules to these:
# https://github.com/hashicorp/terraform-google-nomad/blob/master/modules/nomad-firewall-rules/main.tf
# https://github.com/hashicorp/terraform-google-consul/blob/master/modules/consul-cluster/main.tf


/*

Implied Firewall Rules:

Every VPC network has two implied firewall rules. These rules exist, but are not shown in the Cloud Console:

    Implied allow egress rule. An egress rule whose action is allow, destination is 0.0.0.0/0, and priority is the lowest possible (65535) lets any instance send traffic to any
    destination, except for traffic blocked by Google Cloud. A higher priority firewall rule may restrict outbound access. Internet access is allowed if no other firewall rules
    deny outbound traffic and if the instance has an external IP address or uses a Cloud NAT instance. For more information, see Internet access requirements.

    Implied deny ingress rule. An ingress rule whose action is deny, source is 0.0.0.0/0, and priority is the lowest possible (65535) protects all instances by blocking incoming
    traffic to them. A higher priority rule might allow incoming access. The default network includes some additional rules that override this one, allowing certain types of incoming traffic.

The implied rules cannot be removed, but they have the lowest possible priorities. You can create rules that override them as long as your rules have higher priorities (priority numbers less than 65535). Because deny rules take precedence over allow rules of the same priority, an ingress allow rule with a priority of 65535 never takes effect.


Pre-populated rules for default network:


    default-allow-internal
    Allows ingress connections for all protocols and ports among instances in the network. This rule has the second-to-lowest priority of 65534, and it effectively permits incoming connections to VM instances from others in the same network.

    default-allow-ssh
    Allows ingress connections on TCP port 22 from any source to any instance in the network. This rule has a priority of 65534.

    default-allow-rdp
    Allows ingress connections on TCP port 3389 from any source to any instance in the network. This rule has a priority of 65534, and it enables connections to instances running the Microsoft Remote Desktop Protocol (RDP).

    default-allow-icmp
    Allows ingress ICMP traffic from any source to any instance in the network. This rule has a priority of 65534, and it enables tools such as ping.


"For INGRESS traffic, you cannot specify the destinationRanges field, and for EGRESS
traffic, you cannot specify the sourceRanges or sourceTags fields."
*/


# no longer used but can be used to access the Traefik dashboard directly, if you add
# a public IP to instances instead of routing through the load-balancer
resource "google_compute_firewall" "traefik-public-fw" {
  name = "traefik-public-fw"
  network = var.shared_vpc_network_name
  direction = "INGRESS"

  # traefik dashboard UI and API
  allow {
      protocol = "tcp"
      ports = ["80", "443", "8080-8081"]
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags = ["traefik-public-fw"]
}


resource "google_compute_firewall"  "fw-allow-network-lb-health-checks" {
    name = "fw-allow-network-lb-health-checks"
    network = var.shared_vpc_network_name

    direction = "INGRESS"
    allow {
        protocol = "tcp"
        ports = ["80"]
    }

   source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]

    priority = 1000
    target_tags = ["fw-allow-network-lb-health-checks"]
}


resource "google_compute_firewall"  "allow-all-egress-tcp" {
    name = "allow-all-egress-tcp"
    network = var.shared_vpc_network_name

    direction = "EGRESS"
    allow {
        protocol = "tcp"
    }

    priority = 1000
    target_tags = ["allow-all-egress-tcp"]
}


resource "google_compute_firewall" "allow-ssh" {
  name    = "allow-ssh"
  network = var.shared_vpc_network_name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = ["allow-ssh"]
  source_ranges = ["0.0.0.0/0"]
}


resource "google_compute_firewall" "allow-icmp" {
  name    = "allow-icmp"
  network = var.shared_vpc_network_name

  allow {
    protocol = "icmp"
  }

  target_tags   = ["allow-icmp"]
  source_ranges = ["0.0.0.0/0"]
}


resource "google_compute_firewall" "consul-fw-ingress" {
    name = "consul-fw-ingress"
    network = var.shared_vpc_network_name

    allow {
        protocol = "tcp"
        ports = [
          "8300-8302", "8500-8502", "8600"
        ]
    }
    allow {
      protocol = "udp"
      ports = ["8301-8302", "8600"]
    }
    source_ranges = [local.private_subnet_cidr_range]

    priority = 1000
    enable_logging = true
    target_tags = ["consul-fw-ingress"]
}

resource "google_compute_firewall" "consul-sidecar-fw-ingress" {
    name = "consul-sidecar-fw-ingress"
    network = var.shared_vpc_network_name

    allow {
        protocol = "tcp"
        ports = ["21000-21255", "20000-32000"]  # todo: 20000-32000 should have a separate tag, its for Nomad not sidecars (https://www.nomadproject.io/docs/install/production/requirements)
    }
    source_ranges = [local.private_subnet_cidr_range]

    priority = 1000
    target_tags = ["consul-sidecar-fw-ingress"]
}


resource "google_compute_firewall" "nomad-consul-dashboards-fw-ingress" {
    name = "nomad-consul-dashboards-fw-ingress"
    network = var.shared_vpc_network_name

    allow {
        protocol = "tcp"
        ports = ["4646", "8500"]
    }

    source_ranges = ["0.0.0.0/0"]

    priority = 999  # prioritise over "nomad-server-fw-ingress"
    target_tags = ["nomad-consul-dashboards-fw-ingress"]
}


resource "google_compute_firewall" "nomad-server-fw-ingress" {
    name = "nomad-server-fw-ingress"
    network = var.shared_vpc_network_name

    allow {
        protocol = "tcp"
        ports = ["4646-4648"]
    }

    allow {
        protocol = "udp"
        ports = ["4648"]
    }

    source_ranges = [local.private_subnet_cidr_range]

    priority = 1000
    enable_logging = true
    target_tags = ["nomad-server-fw-ingress"]
}

resource "google_compute_firewall" "nomad-client-fw-ingress" {
    name = "nomad-client-fw-ingress"
    network = var.shared_vpc_network_name

    allow {
        protocol = "tcp"
        ports = ["4646-4647"]
    }

    source_ranges = [local.private_subnet_cidr_range]

    priority = 1000
    enable_logging = true
    target_tags = ["nomad-client-fw-ingress"]
}


resource "google_compute_firewall" "vault-fw-ingress" {
    name = "vault-fw-ingress"
    network = var.shared_vpc_network_name

    allow {
        protocol = "tcp"
        ports = ["8200-8201"]
    }

    source_ranges = [local.private_subnet_cidr_range]

    priority = 1000
    enable_logging = true
    target_tags = ["vault-fw-ingress"]
}


resource "google_compute_router" "nat-router-1" {
  name    = "nat-router-${var.region}"
  region  = var.region
  network = var.shared_vpc_network_name
  # note: sometimes you'll need to delete this with:
  #  $ gcloud compute routers delete nat-router-<region>
}


resource "google_compute_router_nat" "nat-config1" {
  # note: you can also control source IP assignment if you're connecting with a service
  # over the internet and want it to restrict access to a set of known IP addresses
  name                               = "nat-config1"
  router                             = google_compute_router.nat-router-1.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  /*
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }*/
}
