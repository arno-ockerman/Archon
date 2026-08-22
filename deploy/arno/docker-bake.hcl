variable "ARCHON_VERSION" {
  default = "0.9.0"
}

variable "REGISTRY" {
  default = "ghcr.io/arno-ockerman"
}

group "default" {
  targets = ["server", "makeithappen", "club-app"]
}

target "server" {
  context    = "../.."
  dockerfile = "deploy/arno/Dockerfile.server"
  args = {
    ARCHON_VERSION = ARCHON_VERSION
  }
  tags = ["${REGISTRY}/archon-server:${ARCHON_VERSION}", "arno/archon-server:${ARCHON_VERSION}"]
}

target "makeithappen" {
  context    = "../.."
  dockerfile = "deploy/arno/workers/Dockerfile.makeithappen"
  contexts = {
    "arno/archon-server:${ARCHON_VERSION}" = "target:server"
  }
  args = {
    ARCHON_SERVER_IMAGE = "arno/archon-server:${ARCHON_VERSION}"
  }
  tags = ["${REGISTRY}/archon-worker-makeithappen:${ARCHON_VERSION}"]
}

target "club-app" {
  context    = "../.."
  dockerfile = "deploy/arno/workers/Dockerfile.club-app"
  contexts = {
    "arno/archon-server:${ARCHON_VERSION}" = "target:server"
  }
  args = {
    ARCHON_SERVER_IMAGE = "arno/archon-server:${ARCHON_VERSION}"
  }
  tags = ["${REGISTRY}/archon-worker-club-app:${ARCHON_VERSION}"]
}
