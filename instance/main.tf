variable "instance_name" {}
variable "instance_region" {}
variable "instance_zone" {}
variable "instance_type" {
  default = "n1-standard-1"
}
variable "image" {
  default = "ubuntu-os-cloud/ubuntu-1804-lts"
}
variable "instance_subnetwork" {}
variable "startup_script" {
  default = ""
}

# New static External IP for the VM
resource "google_compute_address" "static" {
  name   = "ipv4-address-${var.instance_name}"
  region = var.instance_region
}

# New VM
resource "google_compute_instance" "vm_instance" {
  name         = var.instance_name
  zone         = var.instance_zone
  machine_type = var.instance_type
  boot_disk {
    initialize_params {
      image = var.image
      size = 30
    }
  }

  # Add SSH access to the Compute Engine instance
  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  # Startup script
  # metadata_startup_script = "${file("update-docker.sh")}"

  network_interface {
    network = var.instance_subnetwork
    access_config {
      # Allocate a one-to-one NAT IP to the instance
      nat_ip = google_compute_address.static.address
      # network_tier="STANDARD"  # PREMIUM or STANDARD. If this field is not specified, it is assumed to be PREMIUM.
    }
  }
}

output "instance_ip_addr" {
  value       = google_compute_address.static.address
  description = "The private IP address of the main server instance."
}

output "instance_name" {
  value       = var.instance_name
  description = "The private IP address of the main server instance."
}