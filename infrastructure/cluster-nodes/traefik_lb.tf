
resource "google_compute_managed_ssl_certificate" "traefik-lb-ssl-cert" {
  # note: this module is in beta, consider using google_compute_ssl_certificate instead
  count = var.lb_disable_tls ? 0 : 1

  provider = google-beta

  name = "traefik-lb-ssl-cert"

  managed {
    domains = concat([var.domain_name, "www.${var.domain_name}"], var.sub_domains)
  }

  #subject_alternative_names = ["www.${var.domain_name}"]
}

resource "google_compute_global_forwarding_rule" "https" {
  count = var.lb_disable_tls ? 0 : 1
  project    = var.cluster_service_project_id
  name       = "traefik-lb-global-forwarding-rule"
  target     = google_compute_target_https_proxy.traefik-lb-https-proxy.0.self_link
  port_range = "443"
  ip_address = var.load_balancer_public_ip_address
  load_balancing_scheme = "EXTERNAL"
}

resource "google_compute_ssl_policy" "traefik-lb-ssl-policy" {
  count = var.lb_disable_tls ? 0 : 1
  name    = "traefik-lb-ssl-policy"
  profile = "COMPATIBLE"
  # other possible profiles: https://cloud.google.com/load-balancing/docs/ssl-policies-concepts#defining_an_ssl_policy
}

resource "google_compute_target_https_proxy" "traefik-lb-https-proxy" {
  count = var.lb_disable_tls ? 0 : 1
  project = var.cluster_service_project_id
  name    = "traefik-lb-https-proxy"
  url_map = google_compute_url_map.traefik-lb-url-map.self_link

  ssl_certificates = [google_compute_managed_ssl_certificate.traefik-lb-ssl-cert.0.id]
  ssl_policy       = google_compute_ssl_policy.traefik-lb-ssl-policy.0.self_link
  # quic_override    = var.quic ? "ENABLE" : null
}


# ------------------------------------
# these are created if TLS is disabled on the load-balancer
resource "google_compute_global_forwarding_rule" "http" {
  count = var.lb_disable_tls ? 1 : 0

  project    = var.cluster_service_project_id
  name       = "traefik-lb-global-forwarding-rule"
  target     = google_compute_target_http_proxy.traefik-lb-http-proxy.0.self_link
  port_range = "80"
  ip_address = var.load_balancer_public_ip_address
  load_balancing_scheme = "EXTERNAL"
}

resource "google_compute_target_http_proxy" "traefik-lb-http-proxy" {
  count = var.lb_disable_tls ? 1 : 0

  project = var.cluster_service_project_id
  name    = "traefik-lb-http-proxy"
  url_map = google_compute_url_map.traefik-lb-url-map.self_link
}
# ------------------------------------


resource "google_compute_url_map" "traefik-lb-url-map" {

  project         = var.cluster_service_project_id
  name            = "traefik-lb-url-map"
  default_service = google_compute_backend_service.traefik-backend-service.self_link
}


locals {
  xss_level1 = "evaluatePreconfiguredExpr('xss-stable', ['owasp-crs-v030001-id941150-xss', 'owasp-crs-v030001-id941320-xss', 'owasp-crs-v030001-id941330-xss', 'owasp-crs-v030001-id941340-xss'])"
  sqli_level1 = "evaluatePreconfiguredExpr('sqli-stable', ['owasp-crs-v030001-id942110-sqli', 'owasp-crs-v030001-id942120-sqli', 'owasp-crs-v030001-id942150-sqli', 'owasp-crs-v030001-id942180-sqli', 'owasp-crs-v030001-id942200-sqli', 'owasp-crs-v030001-id942210-sqli', 'owasp-crs-v030001-id942260-sqli', 'owasp-crs-v030001-id942300-sqli', 'owasp-crs-v030001-id942310-sqli', 'owasp-crs-v030001-id942330-sqli', 'owasp-crs-v030001-id942340-sqli', 'owasp-crs-v030001-id942380-sqli', 'owasp-crs-v030001-id942390-sqli', 'owasp-crs-v030001-id942400-sqli', 'owasp-crs-v030001-id942410-sqli', 'owasp-crs-v030001-id942430-sqli', 'owasp-crs-v030001-id942440-sqli', 'owasp-crs-v030001-id942450-sqli', 'owasp-crs-v030001-id942251-sqli', 'owasp-crs-v030001-id942420-sqli', 'owasp-crs-v030001-id942431-sqli', 'owasp-crs-v030001-id942460-sqli', 'owasp-crs-v030001-id942421-sqli', 'owasp-crs-v030001-id942432-sqli'])"
  sqli_level2 = "evaluatePreconfiguredExpr('sqli-stable', ['owasp-crs-v030001-id942251-sqli', 'owasp-crs-v030001-id942420-sqli', 'owasp-crs-v030001-id942431-sqli', 'owasp-crs-v030001-id942460-sqli', 'owasp-crs-v030001-id942421-sqli', 'owasp-crs-v030001-id942432-sqli'])"
  rfi_level1 = "evaluatePreconfiguredExpr('rfi-canary', ['owasp-crs-v030001-id931130-rfi'])"
  lfi_all = "evaluatePreconfiguredExpr('lfi-canary')"
  rce_all = "evaluatePreconfiguredExpr('rce-canary')"
}


resource "google_compute_security_policy" "traefik-security-policy" {
    # this document, although outdated, suggests additional DDoS protection measures: https://cloud.google.com/files/GCPDDoSprotection-04122016.pdf
    # see also: https://owasp.org/www-project-top-ten/

    name = "traefik-security-policy"

    rule {
        action   = "allow"
        priority = "1005"
        match {
            expr {
              expression = "(request.method == \"PUT\") && (request.path.matches('^/v1/kv/.+'))"
            }
        }
        description = "Allow Consul UI save key/value"
    }

    rule {
        action   = "allow"
        priority = "1006"
        match {
            expr {
              expression = "(request.method == \"POST\" || request.method == \"PUT\") && (request.path.matches('^/v1/connect/intentions.*'))"
            }
        }
        description = "Allow Consul UI to create and list intentions"
    }

    rule {
        action   = "allow"
        priority = "1007"
        match {
            expr {
              expression = "request.method == \"POST\" && request.path.matches('^/v1/node/.+/drain')"
            }
        }
        description = "Allow Nomad UI to drain nodes"
    }

    rule {
        action   = "allow"
        priority = "1010"
        match {
            expr {
              expression = "${local.xss_level1} || ${local.sqli_level1} || ${local.rfi_level1}"
            }
        }
        description = "Deny access to level-1 [xss, sqli, rfi] rules"
    }

    rule {
        action   = "allow"
        priority = "1011"
        match {
            expr {
              expression = "(request.method == \"POST\") && (request.path.matches('^/v1/job.+'))"
            }
        }
        description = "Allow Nomad UI job submission"
    }

    rule {
        action   = "deny(403)"
        priority = "1012"
        match {
            expr {
              expression = "${local.xss_level1} || ${local.sqli_level2} || ${local.rfi_level1} || ${local.lfi_all} || ${local.rce_all}"
            }
        }
        description = "Deny access to rules [xss, sqli, rfi, lfi, rce]"
    }

    rule {
        action   = "allow"
        priority = "2147483647"
        description = "default rule"
        match {
          versioned_expr = "SRC_IPS_V1"
          config {
            src_ip_ranges = ["*"]
          }
        }
    }
}


resource "google_compute_backend_service" "traefik-backend-service" {
  provider = google-beta

  project = var.cluster_service_project_id
  name    = "traefik-backend-service"

  port_name                       = "http"
  protocol                        = "HTTP"
  timeout_sec                     = var.http_timeout_sec
  description                     = ""
  connection_draining_timeout_sec = 10
  enable_cdn                      = false
  security_policy                 = google_compute_security_policy.traefik-security-policy.self_link
  health_checks                   = [google_compute_health_check.traefik-health-check.self_link]
  session_affinity                = "NONE"
  affinity_cookie_ttl_sec         = 0

  backend {
    balancing_mode = "UTILIZATION"
    group = google_compute_region_instance_group_manager.traefik-instance-group-manager.instance_group
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  depends_on = [google_compute_health_check.traefik-health-check]

}

resource "google_compute_health_check" "traefik-health-check" {
  # note: health-checks are also beholden to firewalls but we don't need to add them here
  # because the Traefik instances already have a firewall tag to allow connections on port 80.
  name        = "traefik-health-check"
  project = var.cluster_service_project_id

  timeout_sec         = 5
  check_interval_sec  = 8
  healthy_threshold   = 5
  unhealthy_threshold = 5

  http_health_check {
    port_specification = "USE_FIXED_PORT"
    port = 80
    request_path       = "/ping"
    response           = "OK"
  }
}
