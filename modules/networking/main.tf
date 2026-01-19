
############################################
# AZ disponibles et mapping AZ <-> subnets
############################################
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Hypothèse : public_subnet_cidrs et private_subnet_cidrs ont la même taille
  azs_count = length(var.public_subnet_cidrs)
  azs       = slice(data.aws_availability_zones.available.names, 0, local.azs_count)

  public_map = {
    for idx, cidr in var.public_subnet_cidrs :
    tostring(idx) => { cidr = cidr, az = local.azs[idx] }
  }
  private_map = {
    for idx, cidr in var.private_subnet_cidrs :
    tostring(idx) => { cidr = cidr, az = local.azs[idx] }
  }
}

########################
# VPC + Internet Gateway
########################
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.namespace}-vpc"
    Project     = var.namespace
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.namespace}-igw"
    Project     = var.namespace
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

######################
# Subnets publics (xN)
######################
resource "aws_subnet" "public" {
  for_each = local.public_map

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.namespace}-public-${each.value.az}"
    Tier        = "public"
    Project     = var.namespace
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

#####################
# Subnets privés (xN)
#####################
resource "aws_subnet" "private" {
  for_each = local.private_map

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name        = "${var.namespace}-private-${each.value.az}"
    Tier        = "private"
    Project     = var.namespace
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

#########################
# NAT Gateway (EIP + NAT)
#########################
locals {
  nat_keys = var.enable_nat_gateway ? (var.single_nat_gateway ? toset(["0"]) : toset(keys(local.public_map))) : toset([])
}

resource "aws_eip" "nat" {
  for_each = local.nat_keys
  domain   = "vpc"

  tags = {
    Name        = "${var.namespace}-nat-eip-${each.key}"
    Project     = var.namespace
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_nat_gateway" "nat" {
  for_each = local.nat_keys

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = var.single_nat_gateway ? aws_subnet.public["0"].id : aws_subnet.public[each.key].id

  tags = {
    Name        = "${var.namespace}-nat-${each.key}"
    Project     = var.namespace
    Environment = "dev"
    ManagedBy   = "Terraform"
  }

  depends_on = [aws_internet_gateway.igw]
}

########################
# Tables de routage
########################

# Public RT (unique) + route vers IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.namespace}-public-rt"
    Project     = var.namespace
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private RT
locals {
  private_rt_keys = var.single_nat_gateway ? toset(["all"]) : toset(keys(local.private_map))
}

resource "aws_route_table" "private" {
  for_each = local.private_rt_keys
  vpc_id   = aws_vpc.main.id

  tags = {
    Name        = var.single_nat_gateway ? "${var.namespace}-private-rt" : "${var.namespace}-private-rt-${each.key}"
    Project     = var.namespace
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_route" "private_nat" {
  for_each = var.enable_nat_gateway ? local.private_rt_keys : toset([])

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.nat["0"].id : aws_nat_gateway.nat[each.key].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = var.single_nat_gateway ? aws_route_table.private["all"].id : aws_route_table.private[each.key].id
}

##########################################
# (Optionnel) DB Subnet Group pour le RDS
##########################################
resource "aws_db_subnet_group" "this" {
  count      = var.create_database_subnet_group ? 1 : 0
  name       = coalesce(var.database_subnet_group_name, "${var.namespace}-rds-private-subnets")
  subnet_ids = [for k in sort(keys(aws_subnet.private)) : aws_subnet.private[k].id]

  tags = {
    Name        = coalesce(var.database_subnet_group_name, "${var.namespace}-rds-private-subnets")
    Project     = var.namespace
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

###############################
# Security Groups (web / admin)
###############################
resource "aws_security_group" "web" {
  name        = "${var.namespace}-web-sg"
  description = "HTTP/HTTPS pour WordPress"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP depuis Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Décommente si tu veux exposer HTTPS directement
  # ingress {
  #   description = "HTTPS depuis Internet"
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.namespace}-web-sg"
    Role        = "web"
    Project     = var.namespace
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_security_group" "admin_ssh" {
  name        = "${var.namespace}-admin-ssh-sg"
  description = "SSH restreint IP admin"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.namespace}-admin-ssh-sg"
    Role        = "admin"
    Project     = var.namespace
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
