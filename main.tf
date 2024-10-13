# Cognito User Pool
resource "aws_cognito_user_pool" "learnai_pool" {
  name = var.cognito_user_pool_name

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  auto_verified_attributes = ["email"]
}

resource "aws_cognito_user_pool_client" "learnai_client" {
  name         = "learnai-client"
  user_pool_id = aws_cognito_user_pool.learnai_pool.id

  generate_secret = false
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

# S3 Bucket for textbooks
resource "aws_s3_bucket" "textbook_bucket" {
  bucket = var.s3_bucket_name
}

resource "aws_s3_bucket_public_access_block" "textbook_bucket_public_access" {
  bucket = aws_s3_bucket.textbook_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload PDFs to S3 bucket
resource "aws_s3_object" "pdf_upload" {
  for_each = fileset(var.pdf_folder_path, "*.pdf")

  bucket = aws_s3_bucket.textbook_bucket.id
  key    = "pdfs/${each.value}"
  source = "${var.pdf_folder_path}/${each.value}"

  etag = filemd5("${var.pdf_folder_path}/${each.value}")

  depends_on = [aws_s3_bucket.textbook_bucket]
}

# EC2 Instance for running the application
resource "aws_instance" "learnai_app" {
  ami           = "ami-0ebfd941bbafe70c6" # Amazon Linux 2 AMI (adjust for your region)
  instance_type = var.ec2_instance_type
  key_name      = aws_key_pair.learnai_key.key_name

  vpc_security_group_ids = [aws_security_group.learnai_sg.id]

  tags = {
    Name = "LearnAI-App-Server"
  }

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3 git
              git clone https://github.com/manvirchakal/LearnAI /home/ec2-user/learnai
              EOF
}

# Security Group for EC2 instance
resource "aws_security_group" "learnai_sg" {
  name        = "learnai-security-group"
  description = "Security group for LearnAI application"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Knowledge Base
resource "time_sleep" "wait_30_seconds" {
  depends_on = [aws_opensearchserverless_collection.learnai_collection]
  create_duration = "60s"  # Increase this to 60 seconds or more if needed
}

resource "aws_bedrockagent_knowledge_base" "learnai_kb" {
  name        = "learnai-knowledge-base"
  description = "Knowledge base for LearnAI application"
  role_arn    = aws_iam_role.bedrock_kb_role.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v1"
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.learnai_collection.arn
      vector_index_name = "learnai-vector-index"
      field_mapping {
        text_field     = "text"
        metadata_field = "metadata"
        vector_field   = "vector_field"
      }
    }
  }

  depends_on = [null_resource.create_vector_index]
}

# IAM Role for Bedrock Knowledge Base
resource "aws_iam_role" "bedrock_kb_role" {
  name = "bedrock-kb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "bedrock.amazonaws.com",
            "aoss.amazonaws.com"
          ]
        }
      }
    ]
  })
}

# IAM Policy for Bedrock Knowledge Base
resource "aws_iam_role_policy" "bedrock_kb_policy" {
  name = "bedrock-kb-policy"
  role = aws_iam_role.bedrock_kb_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.textbook_bucket.arn,
          "${aws_s3_bucket.textbook_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "aoss:*",
          "opensearchserverless:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.bedrock_kb_role.arn
      },
      {
        Effect = "Allow"
        Action = [
          "aoss:CreateCollection",
          "aoss:DeleteCollection",
          "aoss:GetCollection",
          "aoss:ListCollections",
          "aoss:BatchGetCollection",
          "aoss:CreateAccessPolicy",
          "aoss:CreateSecurityPolicy",
          "aoss:GetAccessPolicy",
          "aoss:GetSecurityPolicy",
          "aoss:ListAccessPolicies",
          "aoss:ListSecurityPolicies",
          "aoss:UpdateAccessPolicy",
          "aoss:UpdateSecurityPolicy"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "aoss:BatchGetCollection",
          "aoss:CreateIndex",
          "aoss:DeleteIndex",
          "aoss:UpdateIndex",
          "aoss:DescribeIndex"
        ]
        Resource = "*"
      }
    ]
  })
}

# OpenSearch Serverless Collection
resource "aws_opensearchserverless_collection" "learnai_collection" {
  name       = "learnai-collection"
  type       = "VECTORSEARCH"
  depends_on = [
    aws_opensearchserverless_security_policy.learnai_security_policy,
    aws_opensearchserverless_access_policy.learnai_access_policy
  ]
}

# EC2 Key Pair
resource "aws_key_pair" "learnai_key" {
  key_name   = "learnai-key"
  public_key = file("${path.module}/learnai-key.pub")
}

# OpenSearch Serverless Security Policy
resource "aws_opensearchserverless_security_policy" "learnai_security_policy" {
  name        = "learnai-security-policy"
  type        = "encryption"
  description = "Security policy for LearnAI OpenSearch collection"
  policy = jsonencode({
    Rules = [
      {
        Resource = [
          "collection/learnai-collection"
        ],
        ResourceType = "collection"
      }
    ],
    AWSOwnedKey = true
  })
}

# OpenSearch Serverless Network Policy
resource "aws_opensearchserverless_security_policy" "learnai_network_policy" {
  name        = "learnai-network-policy"
  type        = "network"
  description = "Network policy for LearnAI OpenSearch collection"
  policy = jsonencode([
    {
      Description = "Public access for LearnAI OpenSearch collection",
      Rules = [
        {
          ResourceType = "collection",
          Resource     = ["collection/learnai-collection"]
        }
      ],
      AllowFromPublic = true
    }
  ])
}

# OpenSearch Serverless Access Policy
resource "aws_opensearchserverless_access_policy" "learnai_access_policy" {
  name        = "learnai-access-policy"
  type        = "data"
  description = "Access policy for LearnAI OpenSearch collection"
  policy = jsonencode([
    {
      Description = "Access policy for LearnAI OpenSearch collection",
      Rules = [
        {
          ResourceType = "index",
          Resource     = ["index/learnai-collection/*"],
          Permission = [
            "aoss:ReadDocument",
            "aoss:WriteDocument",
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex"
          ]
        },
        {
          ResourceType = "collection",
          Resource     = ["collection/learnai-collection"],
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:DeleteCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DescribeCollectionItems"
          ]
        }
      ],
      Principal = [
        aws_iam_role.bedrock_kb_role.arn,
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/bedrock.amazonaws.com/AWSServiceRoleForAmazonBedrock"
      ]
    }
  ])
}

data "aws_caller_identity" "current" {}

resource "null_resource" "create_vector_index" {
  depends_on = [aws_opensearchserverless_collection.learnai_collection, time_sleep.wait_30_seconds]

  provisioner "local-exec" {
    command = <<EOF
export AWS_ACCESS_KEY_ID=${var.aws_access_key}
export AWS_SECRET_ACCESS_KEY=${var.aws_secret_key}
export AWS_DEFAULT_REGION=${var.aws_region}

COLLECTION_ENDPOINT=$(aws opensearchserverless batch-get-collection --ids ${aws_opensearchserverless_collection.learnai_collection.id} --query 'collectionDetails[0].collectionEndpoint' --output text)

echo "Collection ID: ${aws_opensearchserverless_collection.learnai_collection.id}"
echo "Collection Endpoint: $COLLECTION_ENDPOINT"

if [ -z "$COLLECTION_ENDPOINT" ]; then
  echo "Failed to retrieve collection endpoint"
  exit 1
fi

curl -v -X PUT "$COLLECTION_ENDPOINT/learnai-vector-index" \
  -H "Content-Type: application/json" \
  -d '{
    "mappings": {
      "properties": {
        "text": { "type": "text" },
        "metadata": { "type": "keyword" },
        "vector_field": { 
          "type": "knn_vector", 
          "dimension": 1536,
          "method": {
            "name": "hnsw",
            "space_type": "l2",
            "engine": "nmslib"
          }
        }
      }
    }
  }'
EOF
  }
}

resource "aws_iam_role_policy" "terraform_opensearch_policy" {
  name = "terraform-opensearch-policy"
  role = aws_iam_role.bedrock_kb_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aoss:CreateIndex",
          "aoss:DeleteIndex",
          "aoss:UpdateIndex",
          "aoss:DescribeIndex",
          "aoss:ListIndices"
        ]
        Resource = aws_opensearchserverless_collection.learnai_collection.arn
      }
    ]
  })
}