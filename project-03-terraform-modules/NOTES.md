
# Project 03 — Technical Notes and Lessons Learned

## 1. Terraform Modules

Terraform modules allow infrastructure configurations to be organized into reusable components.

In this project, we created four modules:

- **VPC:** Networking infrastructure.
- **EC2:** Compute infrastructure.
- **S3:** Object storage.
- **IAM:** Identity and access management.

Each module contains:

- `main.tf` — Resource definitions.
- `variables.tf` — Input variables.
- `outputs.tf` — Output values.

### Key Lesson

Modules improve organization and reusability, but they also introduce dependencies that must be managed correctly.

For example, the EC2 module needs a subnet ID from the VPC module and an instance profile name from the IAM module.

Terraform uses these references to construct its dependency graph.

## 2. IAM Roles vs IAM Policies

An IAM role defines an identity that AWS services or users can assume.

An IAM policy defines the actions that identity is permitted to perform.

For our EC2 instance:

- We created an IAM role with an EC2 trust policy.
- We attached a custom policy granting `s3:GetObject` for objects in our project bucket.
- We attached `AmazonSSMManagedInstanceCore` for Systems Manager access.
- We created an instance profile to associate the role with EC2.

### Key Lesson

An EC2 instance can obtain temporary AWS credentials through its attached IAM role without storing long-term access keys on the server.

## 3. Least-Privilege Access

Our EC2 instance could retrieve a specific S3 object but could not list the bucket's contents.

This demonstrated the distinction between:

- `s3:GetObject` — Permission to retrieve objects.
- `s3:ListBucket` — Permission to list objects within a bucket.

### Key Lesson

Access to an object does not automatically grant permission to list its containing bucket.

IAM permissions should be limited to the actions and resources required by the workload.

## 4. Troubleshooting Linux File Permissions

### Problem

An S3 download initially failed with:

```text
[Errno 13] Permission denied
```

### Investigation

The error was caused by insufficient permissions to write the downloaded file to the chosen local directory.

It was not an AWS IAM authorization failure.

### Resolution

We changed the download destination to `/tmp`:

```bash
aws s3api get-object \
  --bucket dev-ebuka-terraform-lab-20261013 \
  --key test.txt \
  /tmp/downloaded-test.txt
```

The download succeeded.

### Key Lesson

A permission error does not always indicate an IAM problem.

Troubleshooting should identify which layer is rejecting the operation:

- AWS IAM authorization.
- Operating system filesystem permissions.
- Network connectivity.
- Application configuration.
