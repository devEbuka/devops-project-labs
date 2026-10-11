# Scalable AWS VPC Architecture

**Status:** Application deployment and high-availability validation completed; infrastructure teardown pending.  
**Region:** `us-west-1` (Northern California)  
**Provisioning approach:** Manual AWS Console configuration for hands-on networking and operations practice.

## Overview

Designed and deployed a segmented AWS environment comprising a dedicated bastion VPC and an application VPC connected through AWS Transit Gateway. An internet-facing Application Load Balancer (ALB) distributes traffic to Apache web servers in private subnets across two Availability Zones. An Auto Scaling Group (ASG) maintains capacity and automatically replaces failed instances.

Application servers launch from a preconfigured Golden AMI, assume an IAM instance role, download a versioned application ZIP from a private Amazon S3 bucket, and deploy it through EC2 User Data. The lab was validated through successful public website access, healthy ALB targets, Session Manager connectivity, and a deliberate instance-termination recovery test.

## Architecture

![VPC architecture](https://github.com/user-attachments/assets/808a0c1b-eed6-402f-af11-1ef1f07bfdf9)

> **Diagram scope:** The reference diagram includes a Customer Gateway and Site-to-Site VPN. The VPN was **not provisioned** in this lab. Administrative access used an internet-reachable bastion host instead. Route 53 DNS was also not configured because no suitable domain was required for testing; the ALB-generated DNS name was used.

### Network layout

| VPC | CIDR | Purpose |
| --- | --- | --- |
| Bastion VPC | `192.168.0.0/16` | Restricted SSH administration and access to application VPC |
| Application VPC | `172.32.0.0/16` | Public ALB and private application tier |

| Subnet | CIDR | Availability Zone | Purpose |
| --- | --- | --- | --- |
| `bastion-public-subnet` | `192.168.1.0/24` | `us-west-1a` | Bastion EC2 instance with Elastic IP |
| `app-public-subnet-a` | `172.32.1.0/24` | `us-west-1a` | ALB and NAT Gateway |
| `app-public-subnet-b` | `172.32.2.0/24` | `us-west-1c` | ALB |
| `app-private-subnet-a` | `172.32.3.0/24` | `us-west-1a` | ASG-managed application instances |
| `app-private-subnet-b` | `172.32.4.0/24` | `us-west-1c` | ASG-managed application instances |

### Routing and connectivity

| Route table | Destination | Next hop |
| --- | --- | --- |
| Bastion public | `0.0.0.0/0` | Bastion VPC Internet Gateway |
| Bastion public | `172.32.0.0/16` | Transit Gateway |
| Application public | `0.0.0.0/0` | Application VPC Internet Gateway |
| Application public | `192.168.0.0/16` | Transit Gateway |
| Application private | `0.0.0.0/0` | NAT Gateway in public subnet A |
| Application private | `192.168.0.0/16` | Transit Gateway |

Both VPCs also retain their local routes. The Transit Gateway has attachments and propagated routes for both VPC CIDR blocks. SSH connectivity from the bastion into the application VPC was verified using `nc` on TCP port 22.

**Availability trade-off:** The lab uses one NAT Gateway in `us-west-1a` for private subnets in both AZs, creating a single-AZ dependency for private outbound connectivity. A stronger production design would provide NAT per AZ and route each private subnet to its local NAT Gateway.

## AWS services and components

| Component | Implementation |
| --- | --- |
| Amazon VPC, subnets, route tables, IGWs | Two segmented VPCs; application tier spans two AZs |
| AWS Transit Gateway | Inter-VPC routing and bastion-to-application connectivity |
| NAT Gateway | Outbound connectivity for private instances |
| Amazon EC2 | Bastion host, Golden AMI builder, and private application instances |
| Golden AMI | Amazon Linux 2023 with Apache, Git, AWS CLI, SSM Agent and CloudWatch Agent |
| Amazon S3 | Private, versioned bucket holding web application ZIP artifacts |
| IAM | Instance profile with SSM, CloudWatch and narrowly scoped S3 read permissions |
| EC2 Launch Template | Golden AMI, app security group, IAM profile and User Data deployment script |
| Auto Scaling Group | Two private instances desired; minimum 2, maximum 4; multi-AZ placement |
| Target Group | HTTP port 80; health checks on `/index.html` expecting HTTP 200 |
| Application Load Balancer | Internet-facing, two public subnets, HTTP:80 listener forwarding to target group |
| CloudWatch | Custom `CWAgent/mem_used_percent` metric and application VPC Flow Logs |
| AWS Systems Manager | Session Manager access to private application instances |

## Application deployment workflow

1. Prepared the Golden AMI with Apache and essential administrative/monitoring tools.
2. Packaged the reference static website as a ZIP archive and uploaded it to the private S3 bucket `devops-project-02-config-001`.
3. Created `devops-project-02-app-role`, granting `AmazonSSMManagedInstanceCore`, `CloudWatchAgentServerPolicy` and scoped `s3:GetObject` access to application artifacts.
4. Created `devops-project-02-app-template` with the Golden AMI, security group, instance profile and User Data.
5. Configured `devops-project-02-app-asg` to launch instances in both private subnets and register them with `devops-project-02-app-tg`.
6. Created `devops-project-02-alb` in the public subnets, forwarding requests from port 80 to the target group.
7. Used a Launch Template update and ASG Instance Refresh to roll out the corrected artifact; confirmed successful cloud-init execution and deployment logs.

### Bootstrap script (final version)

```bash
#!/bin/bash
set -e
exec > >(tee -a /var/log/user-data.log) 2>&1

aws s3 cp \
  s3://devops-project-02-config-001/html-web-app-v2.zip \
  /tmp/html-web-app-v2.zip \
  --region us-west-1

dnf install -y unzip
rm -rf /var/www/html/*
unzip -oq /tmp/html-web-app-v2.zip -d /var/www/html/
test -f /var/www/html/index.html
systemctl enable httpd
systemctl restart httpd

echo "Application deployment completed successfully"
```

The application ZIP has `index.html` at the root and POSIX-compatible `/` path separators. The artifact is downloaded at boot using short-lived IAM role credentials rather than embedded AWS access keys.

## Testing and validation

| Test | Observed outcome |
| --- | --- |
| Bastion SSH from restricted administrator IP | Successful |
| Bastion-to-application VPC TCP/22 test | Successful via Transit Gateway |
| Golden AMI Apache test page | HTTP `200 OK` |
| CloudWatch Agent memory monitoring | `CWAgent/mem_used_percent` published |
| Application VPC Flow Logs | ACCEPT and REJECT traffic captured in CloudWatch Logs |
| SSM Session Manager on replacement application instance | Connected, agent online |
| S3 download in User Data | Successful |
| Corrected application bootstrap | `cloud-init status --long`: `status: done` |
| Deployment completion log | `Application deployment completed successfully` |
| Local web server check | `curl -I http://localhost/index.html` returned HTTP `200 OK` |
| ALB target health | 2 healthy targets, 0 unhealthy |
| Website via public ALB DNS | Loaded successfully over HTTP |
| ASG rolling Instance Refresh | Successful |
| Deliberate EC2 instance termination | Website remained available; ASG launched replacement |
| Replacement target health | Returned to 2 healthy targets |

### High-availability failure test

Terminated one ASG-managed application EC2 instance while refreshing the site through the public ALB DNS name. The website remained available through the surviving healthy target. The ASG detected capacity loss, launched a new instance to restore its desired capacity of two, and the target group returned to two healthy targets.

**Result:** Demonstrated load-balancer failover and ASG self-healing. This is a functional test of one-instance failure tolerance, not a comprehensive production resilience or load test.

## Troubleshooting and lessons learned

### 1. Missing IAM instance profile in the first Launch Template

The initial application instances became EC2/ASG healthy but were unavailable through Session Manager; the Launch Template did not include the intended instance profile. Created Launch Template version 2 with `devops-project-02-app-role` and initiated an Instance Refresh. The replacement instance reported SSM Agent **Online** and Session Manager **Connected**.

**Lesson:** EC2 and ASG health alone do not establish that bootstrap, application deployment, or IAM integration succeeded.

### 2. Windows ZIP paths caused User Data to fail

The first ZIP, built with PowerShell, used backslashes in archive entries. Linux `unzip` extracted the website files but emitted a warning and exited with code `1`. Because User Data contained `set -e`, bootstrap stopped before its final Apache restart and success message. Apache was already enabled in the Golden AMI, so `curl` still returned HTTP `200 OK`, masking the initialization failure.

Confirmed the failure using:

```bash
sudo cloud-init status --long
unzip -oq /tmp/html-web-app-v1.zip -d /tmp/unzip-test
echo $?
```

Rebuilt the ZIP using Python's `zipfile` with `Path.as_posix()` for archive names, verified 175 entries with no backslashes and a root-level `index.html`, uploaded `html-web-app-v2.zip`, updated the IAM object permissions, and created Launch Template version 3. A subsequent Instance Refresh succeeded, and `cloud-init status --long` returned `status: done`.

**Lesson:** A working HTTP response does not prove successful bootstrap. Validate User Data/cloud-init logs and the application process explicitly.

## Security decisions

- Restricted public SSH access to the bastion host using the administrator's `/32` source IP.
- Allowed application SSH only from the bastion's private IP through the Transit Gateway path.
- Kept ASG application instances in private subnets without direct public exposure.
- Accepted public inbound HTTP/80 on the ALB security group; allowed application HTTP/80 from the ALB security group rather than arbitrary internet clients.
- Used IAM instance roles and narrowly scoped S3 object-read access instead of static AWS keys on EC2.
- Kept the artifact bucket private with Block Public Access, versioning and SSE-S3.
- Enabled CloudWatch logging of application VPC network flows.

**Production improvements:** HTTPS with an ACM certificate, tighter operational monitoring and alarms, more resilient per-AZ NAT, enhanced deployment checks, and infrastructure-as-code. This lab intentionally used HTTP without a custom domain.

## Scope decisions and cost considerations

The following were intentionally **not implemented**:

- Site-to-Site VPN / Customer Gateway displayed in the reference diagram (bastion access was used).
- Route 53 custom DNS entry (ALB-generated DNS name used for testing).
- Bastion VPC Flow Logs (Application VPC Flow Logs were already validated; skipped duplicate logging to control lab cost).
- Target group stickiness (the application serves static content and does not require instance-local client sessions).

This lab is **not free-tier-only**. NAT Gateway, Transit Gateway attachments and processing, Application Load Balancer, EC2, public IPv4/Elastic IP, CloudWatch Logs and some retained storage resources can incur charges. Resources should be removed after recording evidence.

### Teardown checklist — pending

- [ ] Capture final screenshots and confirm the README/notes are saved in Git.
- [ ] Delete the Auto Scaling Group and any remaining project EC2 instances.
- [ ] Delete the Application Load Balancer and target group.
- [ ] Delete the NAT Gateway; release its Elastic IP after deletion completes.
- [ ] Delete the Transit Gateway VPC attachments, then the Transit Gateway.
- [ ] Release the bastion Elastic IP after terminating the bastion.
- [ ] Remove any unneeded CloudWatch log groups, alarms and Flow Logs.
- [ ] Delete unused launch templates, custom AMI/snapshots and S3 objects/bucket when no longer needed.
- [ ] Delete project-only security groups, routes, subnets, IGWs and VPCs once dependencies are removed.
- [ ] Check EC2 volumes, public IPv4 allocations, AWS Billing and Cost Explorer for remaining costs.

> **Teardown is not yet confirmed.** Do not mark this checklist complete until the resources have actually been removed and verified.

## References

- [Hands-on notes and troubleshooting](./notes.md)
- [Original project instructions](https://github.com/NotHarshhaa/DevOps-Projects/blob/master/DevOps-Project-02/README.md)
- [Reference web application](https://github.com/NotHarshhaa/DevOps-Projects/tree/master/DevOps-Project-02/html-web-app)

---

*This README documents the implementation and validations observed during the lab. The deployed application and high-availability test are complete; infrastructure cleanup remains outstanding.*
