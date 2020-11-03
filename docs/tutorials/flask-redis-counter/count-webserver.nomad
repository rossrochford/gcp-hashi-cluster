job "count-service-job" {
  datacenters = ["dc1"]
  type = "service"

  group "count-service-group" {
    count = 1

    ephemeral_disk {
      size = 500
    }
    network {
      mode = "bridge"
    }

    service {
      name = "count-webserver"
      port = "8080"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "redis-db"
              local_bind_port = 16379
            }
          }
        }
      }

    }

    task "count-service-task" {
      driver = "docker"

      config {
        image = "nomad/count-webserver:v0.1"
      }

      /*
      vault {
        policies = ["nomad-client-base"]
        change_mode   = "noop"
      }

      template {
        data = <<EOH
          {{ with secret "secret/data/nomad/counter/social-auth-facebook" }}
          FACEBOOK_KEY="{{ .Data.data.app_key }}"
          FACEBOOK_SECRET="{{ .Data.data.app_secret }}"
          {{ end }}
EOH
        destination = "secrets/file.env"
        env         = true
      }
      */

    }
  }
}
