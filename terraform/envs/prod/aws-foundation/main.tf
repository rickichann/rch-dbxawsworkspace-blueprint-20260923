locals {
  name = "${var.company_name}-dbx-${var.environment}"

  tags = merge(var.common_tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
  })

  # Subnet name suffix is "<az index><tier letter>": the number counts AZs from 1,
  # the letter marks the tier (a = public, b = private). So the first AZ gets
  # public-subnet-1a and private-subnet-1b, the second gets 2a and 2b.
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, {
    Name = "${local.name}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, {
    Name = "${local.name}-igw"
  })
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name = "${local.name}-public-subnet-${count.index + 1}a"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.tags, {
    Name = "${local.name}-private-subnet-${count.index + 1}b"
    Tier = "private"
  })
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.tags, {
    Name = "${local.name}-nat-eip"
  })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(local.tags, {
    Name = "${local.name}-nat"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.tags, {
    Name = "${local.name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = merge(local.tags, {
    Name = "${local.name}-private-rt"
  })
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "workspace" {
  name        = "${local.name}-workspace-sg"
  description = "Security group for Databricks workspace compute"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Allow all TCP from self"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Allow all UDP from self"
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    self        = true
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.name}-workspace-sg"
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# S3 Gateway VPC Endpoint
#
# Databricks compute in the private subnets talks to S3 constantly: DBFS root,
# Unity Catalog data, cluster logs, library downloads. Without this endpoint all
# of that traffic leaves via the NAT gateway and is billed as NAT data
# processing. A gateway endpoint keeps it on the AWS network, costs nothing, and
# is the single biggest cost lever in this layer.
#
# Gateway endpoints work by adding a prefix-list route, so they attach to route
# tables rather than subnets. Only the private route table needs it; the public
# subnets carry nothing but the NAT gateway.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = merge(local.tags, {
    Name = "${local.name}-s3-endpoint"
  })
}

resource "aws_s3_bucket" "root_bucket" {
  bucket = "${local.name}-root-bucket"

  tags = merge(local.tags, {
    Name = "${local.name}-root-bucket"
  })
}

resource "aws_s3_bucket_versioning" "root_bucket" {
  bucket = aws_s3_bucket.root_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "root_bucket" {
  bucket = aws_s3_bucket.root_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
