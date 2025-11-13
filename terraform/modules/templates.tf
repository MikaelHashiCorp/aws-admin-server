data "template_file" "user_data" {
  template = file("${path.module}/templates/user-data.sh")

  vars = {
    instance_name = var.instance_name
    owner_name    = var.owner_name
  }
}
