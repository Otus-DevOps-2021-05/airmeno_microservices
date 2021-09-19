variable cloud_id {
  description = "Cloud"
}
variable folder_id {
  description = "Folder"
}
variable region_id {
  # Значение региона по умолчанию
  description = "region"
  default     = "ru-central1"
}
variable zone {
  description = "Zone"
  # Значение по умолчанию
  default = "ru-central1-a"
}
variable public_key_path {
  # Описание переменной
  description = "Path to the public key used for ssh access"
}
variable image_id {
  description = "Disk image"
}
variable subnet_id {
  description = "Subnet"
}
variable service_account_key_file {
  description = "key .json"
}
variable private_key_path {
  description = "path to private key"
}
variable node_count {
  description = "count node"
  default     = 2
}
variable cores {
  description = "VM cores"
  default     = 4
}
variable memory {
  description = "VM memory"
  default     = 8
}
variable disk {
  description = "Disk size"
  default     = 64
}
variable network_id {
  description = "Network id"
}
variable service_account_id {
  description = "Service account ID"
}
