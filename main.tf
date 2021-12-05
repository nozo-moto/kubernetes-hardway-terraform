variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "project" {
  type = string
}

variable "credential_path" {
  type = string
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.2.1"
    }
  }
}

provider "google" {
  credentials = file(var.credential)

  project = var.project
  region  = var.region
  zone    = var.zone
}

resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "vpc_network_subnet" {
  name          = "terraform-subnetwork"
  ip_cidr_range = "10.240.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_address" "static" {
  name         = "ipv4-address"
  region       = var.region
}

resource "google_compute_firewall" "allow_icmp" {
  name    = "allow-icmp"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
  source_tags = ["cluster"]
}

resource "google_compute_firewall" "allow_tcp" {
  name    = "allow-tcp"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22", "6443"]
  }

  source_ranges = ["0.0.0.0/0"]
  source_tags = ["cluster"]
}

resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
  source_tags = ["cluster"]
}

variable "controller_instance_variables" {
  type = map(object({
    ip  = string
  }))

  default = {
    controller1 = {
      ip = "10.240.0.11"
    }
    controller2 = {
      ip = "10.240.0.12"
    }
    controller3 = {
      ip = "10.240.0.13"
    }
  }
}

resource "google_compute_instance" "controller_instances" {
  for_each = var.controller_instance_variables

  name = each.key
  machine_type = "e2-standard-2"
  zone = var.zone
  can_ip_forward = true
  tags = ["cluster","controller"]

  network_interface {
    network_ip = each.value.ip
    subnetwork = google_compute_subnetwork.vpc_network_subnet.name
    access_config {}
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
      size  = "200"
    }
  }

  service_account {
    scopes = ["compute-rw","storage-ro","service-management","service-control","logging-write","monitoring"]
  }
}

variable "worker_instance_variables" {
  type = map(object({
    ip   = string
    cidr = string
  }))
  default = {
    worker1 = {
      ip   = "10.240.0.21"
      cidr = "10.200.1.0/24"
    }
    worker2 = {
      ip   = "10.240.0.22"
      cidr = "10.200.2.0/24"
    }
    worker3 = {
      ip   = "10.240.0.23"
      cidr = "10.200.3.0/24"
    }
  }
}

resource "google_compute_instance" "worker_instances" {
  for_each = var.worker_instance_variables

  name = each.key
  machine_type = "e2-standard-2"
  zone = var.zone
  can_ip_forward = true
  tags = ["cluster","controller"]

  network_interface {
    network_ip = each.value.ip
    subnetwork = google_compute_subnetwork.vpc_network_subnet.name
    access_config {}
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
      size  = "200"
    }
  }

  service_account {
    scopes = ["compute-rw","storage-ro","service-management","service-control","logging-write","monitoring"]
  }

  metadata = {
    pod-cidr = each.value.cidr
  }
}

