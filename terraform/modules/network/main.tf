# VPC with public subnets (ALB / NAT gateways only) and private subnets
# (everything else: EKS nodes, RDS, DocumentDB, ElastiCache, MSK) across
# 3 AZs. Nothing that holds customer data or runs application code ever
# gets a public IP - the ALB in the public subnet is the only thing
# internet-facing, matching the "one gateway in, mTLS mesh behind it"
# design from docs/01-architecture.md.
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = "${var.name}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.this.id
  availability_zone       = var.azs[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  map_public_ip_on_launch = true
  tags = merge(var.tags, {
    Name                                    = "${var.name}-public-${var.azs[count.index]}"
    "kubernetes.io/role/elb"                = "1" # required tag for the AWS Load Balancer Controller to auto-discover this subnet
    "kubernetes.io/cluster/${var.name}-eks" = "shared"
  })
}

resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  tags = merge(var.tags, {
    Name                                    = "${var.name}-private-${var.azs[count.index]}"
    "kubernetes.io/role/internal-elb"       = "1"
    "kubernetes.io/cluster/${var.name}-eks" = "shared"
    # Karpenter (installed by ansible/playbooks/01-install-cluster-addons.yml)
    # discovers which subnets it's allowed to launch nodes into via this tag.
    "karpenter.sh/discovery" = "${var.name}-eks"
  })
}

# One NAT gateway per AZ, not one shared NAT - a single NAT gateway is a
# cross-AZ single point of failure for every private-subnet workload's
# egress (e.g. pulling container images, calling out to a payment
# gateway). Costs 3x more than one shared NAT; worth it for a platform
# whose whole design point is availability across AZs.
resource "aws_eip" "nat" {
  count  = length(var.azs)
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-nat-eip-${var.azs[count.index]}" })
}

resource "aws_nat_gateway" "this" {
  count         = length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = merge(var.tags, { Name = "${var.name}-nat-${var.azs[count.index]}" })
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(var.tags, { Name = "${var.name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }
  tags = merge(var.tags, { Name = "${var.name}-private-rt-${var.azs[count.index]}" })
}

resource "aws_route_table_association" "private" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
