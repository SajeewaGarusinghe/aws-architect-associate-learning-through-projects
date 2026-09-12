#!/usr/bin/env bash
# Read-only. Asserts the deployed reality matches what docs/architecture.html claims.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../../.."
source scripts/guardrails.sh

PASS=0; FAIL=0
check() {
  if [[ "$2" == "$3" ]]; then ok "$1"; PASS=$((PASS+1))
  else bad "$1 — doc says '$2', account says '$3'"; FAIL=$((FAIL+1)); fi
}
F=("Name=tag:Project,Values=$TAG_PROJECT")

hdr "Comparing the live account against the architecture document"

VPC=$(aws ec2 describe-vpcs --filters "${F[@]}" --query 'Vpcs[0].VpcId' --output text)
[[ "$VPC" == "None" || -z "$VPC" ]] && die "no lab VPC found — is the stack deployed?"
check "VPC CIDR is 10.30.0.0/16" "10.30.0.0/16" \
  "$(aws ec2 describe-vpcs --vpc-ids "$VPC" --query 'Vpcs[0].CidrBlock' --output text)"

hdr "No egress by design"
check "zero NAT gateways in this VPC" "0" \
  "$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" --query 'length(NatGateways[?State!=`deleted`])' --output text)"
PRIV_RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC" "Name=tag:Name,Values=*rt-private*" \
  --query 'RouteTables[0].RouteTableId' --output text)
check "private route table has no 0.0.0.0/0 route at all" "0" \
  "$(aws ec2 describe-route-tables --route-table-ids "$PRIV_RT" --query 'length(RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`])' --output text)"

hdr "Load balancing"
ALB=$(aws elbv2 describe-load-balancers --names saa-lab-02-alb --query 'LoadBalancers[0]' --output json 2>/dev/null)
[[ -z "$ALB" || "$ALB" == "null" ]] && die "load balancer saa-lab-02-alb not found"
check "ALB is internet-facing" "internet-facing" "$(echo "$ALB" | jq -r '.Scheme')"
check "ALB is active" "active" "$(echo "$ALB" | jq -r '.State.Code')"
check "ALB spans two availability zones" "2" "$(echo "$ALB" | jq '.AvailabilityZones | length')"
ok "ALB DNS name: $(echo "$ALB" | jq -r '.DNSName')"

TG=$(aws elbv2 describe-target-groups --names saa-lab-02-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)
check "health check path is /" "/" \
  "$(aws elbv2 describe-target-groups --target-group-arns "$TG" --query 'TargetGroups[0].HealthCheckPath' --output text)"
check "deregistration delay shortened to 30s" "30" \
  "$(aws elbv2 describe-target-group-attributes --target-group-arn "$TG" --query 'Attributes[?Key==`deregistration_delay.timeout_seconds`].Value|[0]' --output text)"
HEALTHY=$(aws elbv2 describe-target-health --target-group-arn "$TG" \
  --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' --output text)
check "two healthy targets" "2" "$HEALTHY"

hdr "Auto Scaling"
ASG=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names saa-lab-02-asg \
  --query 'AutoScalingGroups[0]' --output json 2>/dev/null)
[[ -z "$ASG" || "$ASG" == "null" ]] && die "auto scaling group saa-lab-02-asg not found"
check "health check type is ELB, not EC2" "ELB" "$(echo "$ASG" | jq -r '.HealthCheckType')"
check "grace period is 120s" "120" "$(echo "$ASG" | jq -r '.HealthCheckGracePeriod')"
check "min 2 / desired 2 / max 4" "2/2/4" \
  "$(echo "$ASG" | jq -r '"\(.MinSize)/\(.DesiredCapacity)/\(.MaxSize)"')"
check "instances spread across two AZs" "2" \
  "$(echo "$ASG" | jq -r '[.Instances[].AvailabilityZone] | unique | length')"
check "all instances report InService" "0" \
  "$(echo "$ASG" | jq -r '[.Instances[] | select(.LifecycleState != "InService")] | length')"

hdr "The security group chain"
APPSG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC" "Name=tag:Name,Values=*sg-app*" \
  --query 'SecurityGroups[0].GroupId' --output text)
ALBSG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC" "Name=tag:Name,Values=*sg-alb*" \
  --query 'SecurityGroups[0].GroupId' --output text)
check "app SG admits the ALB's security group, not a CIDR" "$ALBSG" \
  "$(aws ec2 describe-security-groups --group-ids "$APPSG" --query 'SecurityGroups[0].IpPermissions[0].UserIdGroupPairs[0].GroupId' --output text)"
check "app SG has no CIDR-based inbound rule" "0" \
  "$(aws ec2 describe-security-groups --group-ids "$APPSG" --query 'length(SecurityGroups[0].IpPermissions[0].IpRanges)' --output text)"

hdr "Instances"
check "no instance has a public IP" "0" \
  "$(aws ec2 describe-instances --filters "${F[@]}" "Name=instance-state-name,Values=running" \
     --query 'length(Reservations[].Instances[?PublicIpAddress!=`null`][])' --output text)"
check "IMDSv2 required on every instance" "0" \
  "$(aws ec2 describe-instances --filters "${F[@]}" "Name=instance-state-name,Values=running" \
     --query 'length(Reservations[].Instances[?MetadataOptions.HttpTokens!=`required`][])' --output text)"

echo
if (( FAIL == 0 )); then printf '\033[1;32mAll %d checks passed\033[0m — the diagram and the account agree.\n' "$PASS"
else printf '\033[1;31m%d of %d checks failed\033[0m — the doc and reality disagree.\n' "$FAIL" "$((PASS+FAIL))"; exit 1; fi
