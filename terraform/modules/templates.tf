locals {
  user_data = templatefile("${path.module}/templates/user-data.sh", {
    instance_name = var.instance_name
    owner_name    = var.owner_name
  })
}
