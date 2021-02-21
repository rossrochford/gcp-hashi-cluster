# todo: consider including a 'log shipper' task: https://learn.hashicorp.com/tutorials/nomad/jobs-accessing-logs#log-shipper-pattern
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
      port "http" {
        to = 8080
      }
    }

    service {
      name = "count-webserver"
      port = "http"
      address_mode = "host"

      connect {
        sidecar_service {
          /*proxy {
            upstreams {
              destination_name = "redis-db"
              local_bind_port = 16379
            }
          }*/
        }
      }

      /*check {
        type     = "http"
        #port     = "http"
        local_path_port = 8080
        path     = "/counter/hello"
        interval = "8s"
        timeout  = "2s"
      }*/
    }

    task "count-service-task" {
      driver = "docker"

      config {
        image = "nomad/count-webserver:v0.1"
      }

    }
  }
}
