# Project 02 — Scalable AWS VPC Architecture: Lab Notes

> **Status:** In progress. These notes record what was actually built, verified, and learned as of 9 October 2026. They are not a claim that the full application architecture is deployed.

## 1. Network design

| Component | Configuration |
|---|---|
| AWS Region | `us-west-1` (N. California) |
| Bastion VPC | `192.168.0.0/16` |
| Bastion public subnet | `192.168.1.0/24`, `us-west-1a` |
| Application VPC | `172.32.0.0/16` |
| App public subnet A | `172.32.1.0/24`, `us-west-1a` |
| App public subnet B | `172.32.2.0/24`, `us-west-1c` |
| App private subnet A | `172.32.3.0/24`, `us-west-1a` |
| App private subnet B | `172.32.4.0/24`, `us-west-1c` |

### Routing notes

- A VPC route table has a **local** route for traffic within its VPC CIDR.
- A subnet is public when its associated route table has a default route to an **Internet Gateway (IGW)**. An instance still needs a public IPv4 address and permissive security controls for IPv4 internet access.
- Application public subnet route table: `0.0.0.0/0 → app-igw`.
- Application private subnet route table: `0.0.0.0/0 → app-nat-gw`; `192.168.0.0/16 → Transit Gateway`.
- Bastion public subnet route table: `0.0.0.0/0 → bastion-igw`; route toward `172.32.0.0/16` via Transit Gateway was configured (reverify if needed).
- The **NAT Gateway** allows private IPv4 instances to initiate outbound connections without allowing unsolicited inbound internet connections. The lab uses **one zonal NAT Gateway** in public subnet A; this is cheaper than a per-AZ design but introduces cross-AZ dependency and a single point of failure.
- The **Transit Gateway (TGW)** connects the two VPCs. Both VPC attachments reached **Available**, and TGW route propagation for `172.32.0.0/16` and `192.168.0.0/16` was observed **Active**.
- Routes must exist in both directions. Transit Gateway routing does not bypass Security Groups or Network ACLs.

### Security Groups

| Group | Inbound rule | Purpose |
|---|---|---|
| `bastion-sg` | TCP 22 from my public IP `/32` | Restrict administrative SSH |
| `alb-sg` | TCP 80 from `0.0.0.0/0` | Planned public HTTP entry point |
| `app-sg` | TCP 80 from `alb-sg` | Planned application servers accept HTTP from ALB only |

An application SSH rule from the bastion host's **private IP `/32`** is planned after the bastion is launched. Security Groups are **stateful**: allowed request traffic permits corresponding return traffic automatically. The ALB and application instances are **not yet deployed**.

## 2. Golden AMI preparation — completed

Temporary builder EC2 instance:

- Name: `golden-ami-builder`
- OS: **Amazon Linux 2023**
- Instance type: `t3.micro`
- Location: `application-vpc`, `app-public-subnet-a`
- SSH user: `ec2-user`
- SSH key: `devops-project-02-key.pem` (private key stays local; **never commit it**)
- Golden AMI name: `devops-project-02-golden-ami` — status **Available**

### Commands used

```bash
# Verify OS and identity
whoami
cat /etc/os-release

# Install and verify software
sudo dnf upgrade -y
sudo dnf install -y httpd git
httpd -v
git --version
aws --version

# Enable Apache at boot and start it now
sudo systemctl start httpd
sudo systemctl enable httpd
sudo systemctl is-active httpd
sudo systemctl is-enabled httpd

# Test HTTP locally
curl -I http://localhost
ls -la /var/www/html

# Create a temporary test page
 echo '<h1>Golden AMI Builder - Apache Working</h1>' | sudo tee /var/www/html/index.html
curl -I http://localhost

# Check preinstalled SSM Agent
sudo systemctl status amazon-ssm-agent

# Install and verify CloudWatch Agent
sudo dnf install -y amazon-cloudwatch-agent
rpm -q amazon-cloudwatch-agent

# Verify instance IAM identity
aws sts get-caller-identity
```

**Observed:** Apache `2.4.68`, Git `2.50.1`, AWS CLI `2.36.47`, CloudWatch Agent `1.300071.0`. SSM Agent was active and enabled. `aws sts get-caller-identity` succeeded with the attached instance role.

### Apache troubleshooting: HTTP 403 → HTTP 200

Initial `curl -I http://localhost` returned **`HTTP/1.1 403 Forbidden`**. Apache was reachable and responding, but `/var/www/html` was empty and directory listing was disabled. After creating `/var/www/html/index.html`, the same request returned **`HTTP/1.1 200 OK`**.

**Lesson:** An HTTP response (even 403) means an HTTP server answered the request. A timeout or connection refusal is a different failure mode. A running service does not necessarily mean it is serving the expected content.

### CloudWatch custom memory metric

Created `/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json`:

```json
{
  "agent": { "metrics_collection_interval": 60 },
  "metrics": {
    "namespace": "CWAgent",
    "append_dimensions": { "InstanceId": "${aws:InstanceId}" },
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      }
    }
  }
}
```

IAM role `devops-project-02-ec2-role` was attached to the builder instance with:

- `CloudWatchAgentServerPolicy`
- `AmazonSSMManagedInstanceCore`

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -m ec2 -a status
```

**Observed:** Agent status `running`, config status `configured`; CloudWatch `CWAgent → mem_used_percent` showed a data point around **25.62%** when graphed with a **1-minute period**. Initially the graph showed “No data available”; changing the time range/period and refreshing exposed the new data.

**Lesson:** EC2 publishes standard CPU metrics, but memory utilization requires an agent or another custom-metric publisher. Running an agent alone does not prove data is arriving; verify the metric in CloudWatch.

### AMI considerations

- The AMI captures disk contents and installed software, **not** the EC2 instance's IAM role, Security Groups, or current public IP.
- Future ASG instances will use the Golden AMI through a **Launch Template**, with an instance profile and user data configured separately.
- The temporary test `index.html` is included in the image; planned application user data should replace it when deploying the actual site.
- The builder instance has **not yet been terminated**. Avoid terminating it until the image is verified and no longer needed.

## 3. Concepts to remember

- **`systemctl start`**: starts a service now. **`systemctl enable`**: configures it to start on boot; does not guarantee crash recovery.
- **HTTP 200**: success; **403**: forbidden; **404**: resource not found; **502**: invalid upstream response at gateway/proxy; **504**: upstream timeout.
- **Least privilege**: limit bastion SSH to your IP; limit application HTTP to the ALB Security Group; use an EC2 IAM role instead of static AWS keys.
- **Golden AMI vs user data**: pre-bake shared dependencies into the AMI; use user data for launch-specific setup such as fetching application code.
- **High availability**: private app subnets span two AZs, but the single NAT Gateway remains an AZ-level dependency.

## 4. Remaining work

- [ ] Configure CloudWatch log groups/streams and VPC Flow Logs for both VPCs.
- [ ] Deploy the bastion EC2 host and test SSH access to private instances through the TGW.
- [ ] Configure the application S3 bucket and least-privilege access.
- [ ] Create the Launch Template using the Golden AMI, IAM instance profile, Security Group, and application user data.
- [ ] Create the Auto Scaling Group across both private subnets (min 2, max 4).
- [ ] Create the target group and internet-facing Application Load Balancer in public subnets.
- [ ] Configure Route 53 CNAME and validate end-to-end HTTP traffic.
- [ ] Verify Systems Manager access and CloudWatch metrics on ASG-launched instances.
- [ ] Capture validation screenshots and update README/architecture to reflect deployed state.
- [ ] Clean up billable lab resources when finished.

## 5. Cost and cleanup reminders

**Potentially billable resources:** NAT Gateway (hourly and data processing), Transit Gateway attachments (hourly and data processing), public IPv4 addresses, EC2 instances, EBS/AMI snapshots, future ALB, and CloudWatch usage. AWS credits may offset eligible charges, but do not assume all usage is free. Check Billing/Cost Explorer and remove idle resources when the lab is complete.

## 6. Useful project links

- [Upstream Project 02 README](https://github.com/NotHarshhaa/DevOps-Projects/blob/master/DevOps-Project-02/README.md)
- [Upstream sample web application](https://github.com/NotHarshhaa/DevOps-Projects/tree/master/DevOps-Project-02/html-web-app)
- [Architecture diagram](./architecture.md)
- [Project README](./README.md)
