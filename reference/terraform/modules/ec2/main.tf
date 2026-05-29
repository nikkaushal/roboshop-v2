resource "aws_instance" "this" {
  for_each = var.instances

  ami                    = var.ami_id
  instance_type          = each.value.instance_type
  subnet_id              = var.subnet_ids[each.value.subnet_index]
  vpc_security_group_ids = var.security_group_ids

  user_data_base64 = base64encode(templatefile("${path.module}/user-data.sh.tpl", {
    ansible_repo_url = var.ansible_repo_url
    env              = var.env
    component        = each.value.component
  }))

  tags = merge(var.tags, {
    Name      = "${var.env}-${each.key}"
    Component = each.value.component
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }
}

resource "aws_route53_record" "db" {
  for_each = var.instances

  zone_id = var.route53_zone_id
  name    = "${each.key}.${var.dns_zone}"
  type    = "A"
  ttl     = 60
  records = [aws_instance.this[each.key].private_ip]
}
