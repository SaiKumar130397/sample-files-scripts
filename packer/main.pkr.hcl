packer {
  required_version = ">= 1.10.0"

  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = "~> 1"
    }
  }
}

variable "image_name_prefix" {
  type    = string
  default = "devops-base"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "azure_subscription_id" {
  type    = string
  default = ""
}

variable "azure_tenant_id" {
  type    = string
  default = ""
}

variable "azure_client_id" {
  type    = string
  default = ""
}

variable "azure_client_secret" {
  type      = string
  default   = ""
  sensitive = true
}

variable "azure_location" {
  type    = string
  default = "East US"
}

variable "azure_resource_group_name" {
  type    = string
  default = "packer-images-rg"
}

variable "azure_vm_size" {
  type    = string
  default = "Standard_B2ms"
}

variable "gcp_project_id" {
  type    = string
  default = ""
}

variable "gcp_zone" {
  type    = string
  default = "us-central1-a"
}

variable "gcp_machine_type" {
  type    = string
  default = "e2-medium"
}

locals {
  timestamp  = regex_replace(timestamp(), "[- TZ:]", "")
  image_name = "${var.image_name_prefix}-${local.timestamp}"
}

source "amazon-ebs" "ubuntu" {
  ami_name      = local.image_name
  instance_type = var.aws_instance_type
  region        = var.aws_region
  ssh_username  = var.ssh_username

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
}

source "azure-arm" "ubuntu" {
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret

  managed_image_name                = local.image_name
  managed_image_resource_group_name = var.azure_resource_group_name

  location = var.azure_location
  vm_size  = var.azure_vm_size

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"

  ssh_username = var.ssh_username
}

source "googlecompute" "ubuntu" {
  project_id          = var.gcp_project_id
  source_image_family = "ubuntu-2204-lts"
  zone                = var.gcp_zone
  machine_type        = var.gcp_machine_type
  ssh_username        = var.ssh_username
  image_name          = local.image_name
}

build {
  name = "devops-base-image"

  sources = [
    "source.amazon-ebs.ubuntu",
    "source.azure-arm.ubuntu",
    "source.googlecompute.ubuntu",
  ]

  provisioner "file" {
    source      = "../bootstrap.sh"
    destination = "/tmp/bootstrap.sh"
  }

  provisioner "shell" {
    only = ["azure-arm.ubuntu"]

    inline = [
      "chmod +x /tmp/bootstrap.sh",
      "sudo CLOUD=azure /tmp/bootstrap.sh",
      "sudo cloud-init clean --logs",
    ]
  }

  provisioner "shell" {
    except = ["azure-arm.ubuntu"]

    inline = [
      "chmod +x /tmp/bootstrap.sh",
      "sudo /tmp/bootstrap.sh",
      "sudo cloud-init clean --logs",
    ]
  }
}
