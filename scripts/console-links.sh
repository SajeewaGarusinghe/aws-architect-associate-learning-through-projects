#!/usr/bin/env bash
# Print AWS console deep links for a deployed lab, so the console tour is
# click-through rather than hunt-and-search.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/guardrails.sh

LAB="${1:?usage: console-links.sh LAB_DIR}"; LAB="${LAB%/}"
STACK="$(stack_name_for "$LAB")"
R="$AWS_REGION"
C="https://${R}.console.aws.amazon.com"

VPC=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=$TAG_PROJECT" \
      --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
INST=$(aws ec2 describe-instances --filters "Name=tag:Project,Values=$TAG_PROJECT" \
       "Name=instance-state-name,Values=running" \
       --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || echo "None")

hdr "Console links — open these on your own machine"
echo
echo "START HERE (the visual map of the whole VPC):"
[[ "$VPC" != "None" ]] && echo "  $C/vpcconsole/home?region=$R#VpcDetails:VpcId=$VPC" \
                       || echo "  (no lab VPC found — is the stack deployed?)"
echo
echo "Stack and its resources:"
echo "  $C/cloudformation/home?region=$R#/stacks/resources?stackId=$STACK"
echo
echo "Networking:"
echo "  Subnets        $C/vpcconsole/home?region=$R#subnets:VpcId=$VPC"
echo "  Route tables   $C/vpcconsole/home?region=$R#RouteTables:VpcId=$VPC"
echo "  Internet GW    $C/vpcconsole/home?region=$R#igws:"
echo "  NAT gateways   $C/vpcconsole/home?region=$R#NatGateways:"
echo "  Endpoints      $C/vpcconsole/home?region=$R#Endpoints:"
echo "  Security grps  $C/vpcconsole/home?region=$R#SecurityGroups:VpcId=$VPC"
echo "  Network ACLs   $C/vpcconsole/home?region=$R#acls:VpcId=$VPC"
echo
echo "Compute:"
echo "  Instances      $C/ec2/home?region=$R#Instances:tag:Project=$TAG_PROJECT"
[[ "$INST" != "None" ]] && {
echo "  Instance       $C/ec2/home?region=$R#InstanceDetails:instanceId=$INST"
echo "  Shell (SSM)    $C/systems-manager/session-manager/$INST?region=$R"; } || \
echo "  (no lab instance running)"

# Load balancing and Auto Scaling — only printed when the lab actually has them.
ALBDNS=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?starts_with(LoadBalancerName,'saa-lab-')]|[0].DNSName" --output text 2>/dev/null || echo None)
if [[ "$ALBDNS" != "None" && -n "$ALBDNS" ]]; then
echo
echo "Load balancing:"
echo "  THE SITE       http://$ALBDNS   ← reload this repeatedly"
echo "  Load balancers $C/ec2/home?region=$R#LoadBalancers:"
echo "  Target groups  $C/ec2/home?region=$R#TargetGroups:"
fi
ASG=$(aws autoscaling describe-auto-scaling-groups \
  --query "AutoScalingGroups[?starts_with(AutoScalingGroupName,'saa-lab-')]|[0].AutoScalingGroupName" --output text 2>/dev/null || echo None)
if [[ "$ASG" != "None" && -n "$ASG" ]]; then
echo "  Auto Scaling   $C/ec2/home?region=$R#AutoScalingGroupDetails:id=$ASG;view=activity"
fi
TABLE=$(aws dynamodb list-tables --query "TableNames[?starts_with(@,'saa-lab-')]|[0]" --output text 2>/dev/null || echo None)
if [[ "$TABLE" != "None" && -n "$TABLE" ]]; then
echo
echo "DynamoDB:"
echo "  Table          $C/dynamodbv2/home?region=$R#table?name=$TABLE"
echo "  Explore items  $C/dynamodbv2/home?region=$R#item-explorer?table=$TABLE"
fi
FN=$(aws lambda list-functions --query "Functions[?starts_with(FunctionName,'saa-lab-')]|[0].FunctionName" --output text 2>/dev/null || echo None)
if [[ "$FN" != "None" && -n "$FN" ]]; then
echo
echo "Lambda:"
echo "  Function       $C/lambda/home?region=$R#/functions/$FN"
fi

echo
echo "Observability:"
echo "  Flow logs      $C/cloudwatch/home?region=$R#logsV2:log-groups"
echo
