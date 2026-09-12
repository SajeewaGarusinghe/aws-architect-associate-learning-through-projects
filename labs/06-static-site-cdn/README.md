# Lab 06 — Private bucket, public site

A bucket with every public-access setting blocked, serving a public website — because CloudFront is
not "the public", it is a named principal in the bucket policy.

**Architecture document:** [`docs/architecture.html`](docs/architecture.html) — open this first.

## What gets built

- An **S3 bucket** with all four Block Public Access settings on, encrypted and versioned
- **Origin Access Control** signing every origin request with SigV4
- A **bucket policy** naming the CloudFront service principal, conditioned on this one distribution
- A **CloudFront distribution** with HTTPS enforced and a second `/nocache/*` cache behaviour
- **Lifecycle rules**: noncurrent versions expire in a day; `archive/` tiers to Standard-IA then
  Glacier IR
- **Custom error responses** mapping S3's 403 to a sensible 404 page

Site content lives in [`site/`](site/) and is uploaded as the first step of the tour — the bucket
is created empty.

## Exam domains

| Domain | Weight | Covered here |
|---|---|---|
| D1 — Design Secure Architectures | 30% | Block Public Access, OAC, resource policy conditions |
| D4 — Design Cost-Optimized Architectures | 20% | Storage classes, lifecycle transitions, cache hit ratio |
| D3 — Design High-Performing Architectures | 24% | Edge caching, invalidation, path-pattern behaviours |

## The three ideas worth keeping

1. **Never fix a CloudFront 403 by making the bucket public.** It is almost always OAC, the
   policy's source-ARN condition, or a missing key — and public access exposes everything, silently.
2. **S3 returns 403, not 404, for a missing key** when the caller has no `ListBucket`.
3. **Uploading does not update the edges.** Versioned filenames beat invalidation.

## Runbook

```bash
./scripts/verify-clean.sh
./scripts/deploy.sh  labs/06-static-site-cdn --yes    # 3–5 minutes
#   → upload site/, then console-tour.md  (~15 min)
./labs/06-static-site-cdn/verify/checks.sh
./scripts/teardown.sh labs/06-static-site-cdn --yes
```

## Cost

**$0.00 per hour idle.** ~1.2 cents per 10,000 requests, plus storage. Teardown takes ~4 minutes —
the distribution must be disabled first and the bucket emptied **including every version**.
