# Teardown report — 01-vpc-from-scratch

| | |
|---|---|
| Stack | `saa-lab-01-vpc-from-scratch` |
| Deployed | 2026-09-12 08:49:42Z |
| Destroyed | 2026-09-12 09:08:42Z |
| **Live for** | **19 minutes** |
| Status | `DELETE_COMPLETE` — verified by tag sweep |

## Billable resources

| Resource | $/hr | Cost for 19 min |
|---|---:|---:|
| VPC interface endpoint | 0.0130 | 0.0041 |
| Elastic IP / public IPv4 | 0.0050 | 0.0016 |
| NAT Gateway | 0.0590 | 0.0187 |
| EC2 t3.micro | 0.0132 | 0.0042 |
| VPC gateway endpoint (free) | 0.0000 | 0.0000 |
| VPC interface endpoint | 0.0130 | 0.0041 |
| VPC interface endpoint | 0.0130 | 0.0041 |
| **Total** | | **$0.0368** |

Free resources in this stack (VPC, subnets, route tables, internet gateway,
security groups, NACLs, IAM roles, gateway endpoints) are omitted — they carry
no hourly charge. Data transfer and CloudWatch Logs ingestion are negligible at
this scale and not itemised.
