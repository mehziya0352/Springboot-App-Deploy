#!/bin/bash
set -e

# ----------------------------
# Variables
# ----------------------------
REGION="us-east-1"
BUCKET_NAME="my-springsboot-state-bucket"   # fixed name; change if you want
DYNAMODB_TABLE="terraform-locks"

echo "-------------------------------"
echo "AWS Backend Setup Script"
echo "Region: $REGION"
echo "S3 Bucket: $BUCKET_NAME"
echo "DynamoDB Table: $DYNAMODB_TABLE"
echo "-------------------------------"

# ----------------------------
# Create S3 bucket
# ----------------------------
echo "Creating S3 bucket: $BUCKET_NAME ..."

if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "Bucket $BUCKET_NAME already exists and is owned by you."
else
    if [ "$REGION" == "us-east-1" ]; then
        # us-east-1 must NOT have LocationConstraint
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" || { echo "Failed to create bucket"; exit 1; }
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION" || { echo "Failed to create bucket"; exit 1; }
    fi
    echo "Bucket created successfully."
fi

# Enable versioning
echo "Enabling versioning on bucket ..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled || echo "Cannot enable versioning, maybe not owned"

# ----------------------------
# Create DynamoDB table
# ----------------------------
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" 2>/dev/null; then
    echo "DynamoDB table $DYNAMODB_TABLE already exists."
else
    echo "Creating DynamoDB table: $DYNAMODB_TABLE ..."
    aws dynamodb create-table \
      --table-name "$DYNAMODB_TABLE" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --region "$REGION" || echo "Failed to create DynamoDB table"
fi

echo "-------------------------------"
echo "✅ AWS backend setup completed!"
echo "S3 Bucket: $BUCKET_NAME"
echo "DynamoDB Table: $DYNAMODB_TABLE"
echo "-------------------------------"

# Output Terraform backend snippet
echo ""
echo "Use this backend in your Terraform config:"
echo "-------------------------------------------------"
echo "terraform {"
echo "  backend \"s3\" {"
echo "    bucket         = \"$BUCKET_NAME\""
echo "    key            = \"terraform.tfstate\""
echo "    region         = \"$REGION\""
echo "    dynamodb_table = \"$DYNAMODB_TABLE\""
echo "    encrypt        = true"
echo "  }"
echo "}"
echo "-------------------------------------------------"
