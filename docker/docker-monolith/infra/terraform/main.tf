provider "yandex" {
  version                  = 0.35
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}

resource "yandex_compute_instance" "docker" {
  name  = "docker-${count.index}"
  count = var.instance_count

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
    }
  }

  network_interface {
    subnet_id = var.subnet_id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }
}

# Invetrory for ansible and run playbook 
resource "local_file" "inventory" {
  content = templatefile("inventory.tpl",
    {
      docker_hosts = yandex_compute_instance.docker.*.network_interface.0.nat_ip_address
    }
  )
  filename = "../ansible/inventory.ini"
}
