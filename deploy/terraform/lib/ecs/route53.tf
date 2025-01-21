resource "aws_route53_zone" "private" {
  name = "retailstore.local"

  vpc {
    vpc_id = var.vpc_id
  }

  tags = {
    Environment = var.environment_name
  }
}
