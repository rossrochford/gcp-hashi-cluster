job "redis-job" {
  
  datacenters = ["dc1"]
  type = "service"

  group "redis-group" {

    ephemeral_disk {
      size = 600
    }
    network {
      mode = "bridge"
    }

    service {
      name = "redis-db"
      port = "6379"
      connect {
        sidecar_service {}
      }
    }

    task "redis-db" {
      driver = "docker"
      config {
        image = "registry.hub.docker.com/library/redis:6.0"
      }
    }
  }
}
