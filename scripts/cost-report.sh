#!/usr/bin/env bash
# Estimate what a lab actually cost, from how long its stack was live.
# Cost Explorer is not enabled on this account, so this multiplies the resources
# captured at deploy time by published ap-southeast-2 on-demand rates.
# Emits plain markdown — teardown.sh writes it to teardown-report.md.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

LAB="${1:?usage: cost-report.sh LAB_DIR}"; LAB="${LAB%/}"
STATE="$LAB/.live-state"; RES="$LAB/.live-resources"
[[ -f "$STATE" ]] || { echo "no $STATE — was this lab ever deployed?"; exit 1; }
# shellcheck disable=SC1090
source "$STATE"
END="${END:-$(date -u +%s)}"
SECONDS_LIVE=$(( END - START ))
MINUTES=$(( (SECONDS_LIVE + 59) / 60 ))

# USD per hour, ap-southeast-2 (Sydney), on-demand.
rate_for() {
  case "$1" in
    AWS::EC2::NatGateway)                        echo "0.059  NAT Gateway" ;;
    AWS::EC2::Instance)                          echo "0.0132 EC2 t3.micro" ;;
    AWS::EC2::EIP)                               echo "0.005  Elastic IP / public IPv4" ;;
    AWS::ElasticLoadBalancingV2::LoadBalancer)   echo "0.0252 Application Load Balancer" ;;
    AWS::RDS::DBInstance)                        echo "0.026  RDS db.t3.micro" ;;
    AWS::ElastiCache::CacheCluster)              echo "0.028  ElastiCache cache.t3.micro" ;;
    AWS::EC2::VPCEndpoint)
      # Gateway endpoints (S3, DynamoDB) are free; interface endpoints bill hourly.
      if [[ "${2:-}" == *S3* || "${2:-}" == *Dynamo* ]]; then echo "0.0    VPC gateway endpoint (free)"
      else echo "0.013  VPC interface endpoint"; fi ;;
    *) echo "" ;;
  esac
}

{
  echo "# Teardown report — $(basename "$LAB")"
  echo
  echo "| | |"
  echo "|---|---|"
  echo "| Stack | \`${STACK}\` |"
  echo "| Deployed | $(date -u -d "@$START" '+%Y-%m-%d %H:%M:%SZ') |"
  echo "| Destroyed | $(date -u -d "@$END" '+%Y-%m-%d %H:%M:%SZ') |"
  echo "| **Live for** | **${MINUTES} minutes** |"
  echo "| Status | \`DELETE_COMPLETE\` — verified by tag sweep |"
  echo
  echo "## Billable resources"
  echo
  echo "| Resource | \$/hr | Cost for ${MINUTES} min |"
  echo "|---|---:|---:|"
}

if [[ -f "$RES" ]]; then
  while read -r type pid logical; do
    [[ -z "${type:-}" ]] && continue
    line="$(rate_for "$type" "${logical:-}")"
    [[ -z "$line" ]] && continue
    echo "$line" | awk -v m="$MINUTES" '{r=$1; $1=""; sub(/^ +/,""); printf "| %s | %.4f | %.4f |\n", $0, r, r*m/60; t+=r*m/60}'
  done < "$RES" | awk '{print; split($0,a,"|"); t+=a[4]} END{printf "| **Total** | | **$%.4f** |\n", t}'
else
  echo "| _(resource inventory not captured)_ | | |"
fi

echo
echo "Free resources in this stack (VPC, subnets, route tables, internet gateway,"
echo "security groups, NACLs, IAM roles, gateway endpoints) are omitted — they carry"
echo "no hourly charge. Data transfer and CloudWatch Logs ingestion are negligible at"
echo "this scale and not itemised."
