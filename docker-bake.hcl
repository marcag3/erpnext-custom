# Docker Buildx Bake build definition file
# Reference: https://github.com/docker/buildx/blob/master/docs/reference/buildx_bake.md

variable "PYTHON_VERSION" {
  default = "3.11.6"
}

variable "DEBIAN_BASE" {
  default = "bookworm"
}

variable "FRAPPE_BRANCH" {
  default = "version-15"
}

variable "FRAPPE_PATH" {
  default = "https://github.com/frappe/frappe"
}

variable "APPS_JSON_BASE64" {
  default = ""
}

target "erpnext-nginx" {
  context = "."
  dockerfile = "src/variations/erpnext-nginx/Dockerfile"
  args = {
    PYTHON_VERSION = "${PYTHON_VERSION}"
    DEBIAN_BASE = "${DEBIAN_BASE}"
    FRAPPE_BRANCH = "${FRAPPE_BRANCH}"
    FRAPPE_PATH = "${FRAPPE_PATH}"
    APPS_JSON_BASE64 = "${APPS_JSON_BASE64}"
  }
  tags = [
    "ghcr.io/marcag3/erpnext-custom:latest",
    "ghcr.io/marcag3/erpnext-custom:${PYTHON_VERSION}",
    "ghcr.io/marcag3/erpnext-custom:${PYTHON_VERSION}-${DEBIAN_BASE}"
  ]
}

target "erpnext-nginx-dev" {
  inherits = ["erpnext-nginx"]
  tags = [
    "ghcr.io/marcag3/erpnext-custom:dev",
    "ghcr.io/marcag3/erpnext-custom:${PYTHON_VERSION}-dev"
  ]
  target = "final"
}
