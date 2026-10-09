# Project 02 — Scalable AWS VPC Architecture

**Legend:** Solid nodes = provisioned/configured; dashed nodes = planned/not yet deployed. The builder instance and Golden AMI are prepared, but the application fleet is not deployed yet.

```mermaid
flowchart TB
    Internet((Internet))
    User[Administrator]
    TGW{{Transit Gateway<br/>devops-tgw}}

    subgraph B["Bastion VPC — 192.168.0.0/16"]
      BIGW[Bastion Internet Gateway]
      BRT[Public route table<br/>0.0.0.0/0 → IGW<br/>172.32.0.0/16 → TGW]
      subgraph BS["Public subnet — 192.168.1.0/24 — us-west-1a"]
        Bastion[Bastion EC2 — planned]
      end
      BIGW --- BRT
      BRT --- BS
    end

    subgraph A["Application VPC — 172.32.0.0/16"]
      AIGW[Application Internet Gateway]
      NAT[NAT Gateway — app-public-subnet-a]
      subgraph AZA["us-west-1a"]
        subgraph PA["Public subnet A — 172.32.1.0/24"]
          Builder[Golden AMI builder EC2]
        end
        subgraph PRA["Private subnet A — 172.32.3.0/24"]
          EC2A[ASG EC2 instance — planned]
        end
      end
      subgraph AZC["us-west-1c"]
        subgraph PC["Public subnet B — 172.32.2.0/24"]
          ALB[Application Load Balancer — planned]
        end
        subgraph PRC["Private subnet B — 172.32.4.0/24"]
          EC2C[ASG EC2 instance — planned]
        end
      end
      AIGW --- PA
      AIGW --- PC
      PA --- NAT
      NAT -. "0.0.0.0/0 outbound" .-> PRA
      NAT -. "0.0.0.0/0 outbound" .-> PRC
      ALB -. "HTTP 80" .-> EC2A
      ALB -. "HTTP 80" .-> EC2C
    end

    User -. "SSH from your IP — planned" .-> Bastion
    Internet --> BIGW
    Internet --> AIGW
    Bastion -. "private routing" .-> TGW
    TGW -. "192.168.0.0/16 ↔ 172.32.0.0/16" .-> A
    Internet -. "HTTP 80 — planned" .-> ALB

    AMI[(Golden AMI — available)]
    CW[(CloudWatch: mem_used_percent — verified)]
    Builder --> AMI
    Builder --> CW
    AMI -. "Launch Template — planned" .-> EC2A
    AMI -. "Launch Template — planned" .-> EC2C

    classDef planned stroke-dasharray:5 5,stroke:#777,fill:#f6f6f6,color:#333;
    class Bastion,ALB,EC2A,EC2C planned;
```

## Implementation notes

- Both Transit Gateway VPC attachments and TGW route propagation have been verified.
- Both application private subnets currently share **one zonal NAT Gateway in us-west-1a**. This is not fully AZ-resilient and may incur cross-AZ data transfer charges.
- The Application Load Balancer will be associated with **both public subnets**, even though its diagram node is drawn in one for legibility.
- App Security Group allows HTTP from the ALB Security Group; SSH from the bastion's private IP is to be added after the bastion is deployed.
- VPC Flow Logs, S3 configuration bucket, bastion EC2, launch template, ASG, ALB, and Route 53 are still pending.
- The Golden AMI contains software and agent configuration, not the IAM instance role or security groups.
