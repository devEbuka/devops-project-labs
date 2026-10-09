# Scalable AWS VPC Architecture

> **Status:** In progress — network foundation and Golden AMI completed. Application deployment and end-to-end validation are pending.

## Overview

This project builds a segmented AWS network with a dedicated bastion VPC and an application VPC. The design uses public and private subnets, controlled outbound internet access, and AWS Transit Gateway for inter-VPC connectivity. The target deployment will run a web application on EC2 instances managed by an Auto Scaling Group behind an Application Load Balancer.

The lab is being implemented manually in the AWS Console to understand the infrastructure, routing, access controls, and operational dependencies before automating similar designs.

**Region:** `us-west-1` (N. California)

## Architecture

[View the architecture diagram](./Architecture.png)

The diagram represents the **target design**. Some components are already deployed, while others are planned; the progress table below is the source of truth for implementation status.

### Network layout

| VPC | CIDR | Purpose |
| --- | --- | --- |
| Bastion VPC | `192.168.0.0/16` | Controlled administrative entry point |
| Application VPC | `172.32.0.0/16` | Public-facing load balancer and private application instances |

| Subnet | CIDR | Availability Zone | Purpose |
| --- | --- | --- | --- |
| `bastion-public-subnet` | `192.168.1.0/24` | `us-west-1a` | Planned bastion EC2 host |
| `app-public-subnet-a` | `172.32.1.0/24` | `us-west-1a` | Public ALB subnet; NAT Gateway |
| `app-public-subnet-b` | `172.32.2.0/24` | `us-west-1c` | Second public ALB subnet |
| `app-private-subnet-a` | `172.32.3.0/24` | `us-west-1a` | Planned application EC2 instances |
| `app-private-subnet-b` | `172.32.4.0/24` | `us-west-1c` | Planned application EC2 instances |

### Routing design

| Route table | Destination | Target |
| --- | --- | --- |
| Bastion public | `0.0.0.0/0` | Bastion Internet Gateway |
| Bastion public | `172.32.0.0/16` | Transit Gateway |
| Application public | `0.0.0.0/0` | Application Internet Gateway |
| Application private | `0.0.0.0/0` | NAT Gateway in `app-public-subnet-a` |
| Application private | `192.168.0.0/16` | Transit Gateway |

Each VPC also has its automatically created **local** route. The Transit Gateway route table has active routes to both VPC CIDR blocks through their respective attachments.

**Availability trade-off:** The current design uses **one NAT Gateway in `us-west-1a`** for both private subnets. This is sufficient for the learning lab, but creates a single-AZ dependency for private-subnet outbound traffic. A more resilient production design would normally deploy a NAT Gateway per AZ and use AZ-local private routes.

## AWS services and components

- **Amazon VPC:** Segmented bastion and application networks.
- **Subnets and route tables:** Public/private routing across two application Availability Zones.
- **Internet Gateways:** Internet routing for public subnets.
- **NAT Gateway:** Outbound connectivity for private application subnets.
- **AWS Transit Gateway:** Routed connectivity between the two VPCs.
- **Security Groups:** Least-privilege access boundaries for bastion, load balancer, and application servers.
- **Amazon EC2 and AMIs:** Golden image preparation for repeatable application instances.
- **AWS IAM:** EC2 instance role for CloudWatch Agent and Systems Manager.
- **Amazon CloudWatch:** Custom memory-utilization telemetry.
- **Planned:** VPC Flow Logs, bastion EC2, Amazon S3, Launch Template, Auto Scaling Group, target group, Application Load Balancer, and Route 53 DNS.

## Implementation progress

| Work item | Status |
| --- | --- |
| Bastion VPC, public subnet, Internet Gateway, public routes | Completed |
| Application VPC, two public and two private subnets | Completed |
| Application Internet Gateway and public route table | Completed |
| NAT Gateway and private default route | Completed |
| Transit Gateway, both VPC attachments, and inter-VPC routes | Completed |
| Bastion, ALB, and application Security Groups | Created; application SSH rule to be finalized after bastion deployment |
| Golden AMI with Apache, Git, AWS CLI, SSM Agent, CloudWatch Agent | Completed |
| Custom CloudWatch memory metric | Verified |
| VPC Flow Logs and CloudWatch log streams | Pending |
| Bastion EC2 host and Elastic IP | Pending |
| S3 configuration bucket | Pending |
| Application Launch Template and startup user data | Pending |
| Auto Scaling Group across private subnets | Pending |
| Target group and Application Load Balancer | Pending |
| Route 53 DNS | Pending |
| End-to-end application, bastion, and SSM validation | Pending |

## Golden AMI preparation

A temporary EC2 image-builder instance was launched in `app-public-subnet-a` using **Amazon Linux 2023**. It was configured with:

- Apache HTTP Server (`httpd`), enabled at boot
- Git
- AWS CLI v2
- Amazon SSM Agent, enabled and running
- Amazon CloudWatch Agent, configured to collect `mem_used_percent` every 60 seconds

An EC2 IAM role named `devops-project-02-ec2-role` was attached with the managed policies `CloudWatchAgentServerPolicy` and `AmazonSSMManagedInstanceCore`. The instance's AWS identity was verified with `aws sts get-caller-identity`.

The reusable image was created as **`devops-project-02-golden-ami`** and its state was confirmed as **Available**.

> The AMI captures disk contents, **not** the instance's IAM role, Security Group, or subnet configuration. Those must be specified separately when launching instances through a Launch Template.

## Validation performed

| Check | Result |
| --- | --- |
| SSH access to Golden AMI builder | Successful |
| Operating system | Amazon Linux 2023 confirmed |
| Apache and Git versions | Confirmed installed |
| Apache service | `active` and `enabled` |
| Initial `curl -I http://localhost` | `403 Forbidden` because the document root was empty |
| Added a test `index.html` | HTTP `200 OK` |
| AWS CLI | Installed and functional |
| SSM Agent | Running and enabled |
| IAM role credentials | Verified with STS |
| CloudWatch Agent | Running and configured |
| `CWAgent / mem_used_percent` | Visible in CloudWatch with a data point around 25.62% |
| Golden AMI | State `Available` |

**Not yet validated:** Traffic through the future ALB, Auto Scaling behavior, SSH through the bastion to private EC2 instances, SSM Session Manager connectivity, and public DNS.

## Security decisions

- Bastion SSH access is restricted to **My IP** (`/32`) instead of being open to the internet.
- The ALB Security Group allows inbound HTTP (`80`) from the internet for the public demo.
- The application Security Group allows HTTP (`80`) **from the ALB Security Group**, rather than from arbitrary public IP addresses.
- Private application instances will use private subnets without direct public inbound access.
- Application SSH access from the bastion will be finalized after its private IP is known.
- EC2 services use an **IAM instance role**, not long-lived access keys stored on disk.

## Remaining implementation plan

1. Configure CloudWatch log groups/streams and VPC Flow Logs for both VPCs.
2. Launch the bastion host in the bastion public subnet, associate an Elastic IP, and validate access.
3. Create the S3 bucket for application configuration.
4. Build a Launch Template using the Golden AMI, instance profile, application Security Group, and user data to retrieve and serve the web application.
5. Configure an Auto Scaling Group across the two private application subnets (minimum 2, maximum 4 instances).
6. Create an HTTP target group and an internet-facing Application Load Balancer in the two application public subnets.
7. Configure Route 53 DNS, where a suitable domain is available.
8. Validate application reachability, target health, bastion-to-private access, Systems Manager connectivity, and scaling behavior.
9. Capture evidence, update documentation, and clean up chargeable resources when the lab is complete.

## Cost considerations

This is an AWS learning lab, **not** a zero-cost architecture. NAT Gateway, Transit Gateway attachments/data processing, public IPv4 addresses, load balancing, EC2, and other services may incur charges even if an account has promotional credits. Monitor billing while resources are running and delete unused resources after testing.

## Project notes and source

- [Hands-on notes and troubleshooting](./notes.md)
- [Architecture diagram](./architecture.md)
- [Original project instructions](https://github.com/NotHarshhaa/DevOps-Projects/blob/master/DevOps-Project-02/README.md)
- [Reference web application](https://github.com/NotHarshhaa/DevOps-Projects/tree/master/DevOps-Project-02/html-web-app)

---

*This README records verified progress as the lab is built. Planned resources are explicitly identified and will be updated after deployment and testing.*
