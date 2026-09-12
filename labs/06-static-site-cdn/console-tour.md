# Console tour — Lab 06

Keep [the architecture diagram](docs/architecture.html) open beside the console. Budget ~15 minutes.

---

## 0. Upload the site (2 min) — the bucket is created empty

```bash
BUCKET=$(aws cloudformation describe-stacks --stack-name saa-lab-06-static-site-cdn \
  --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" --output text)
aws s3 cp labs/06-static-site-cdn/site/index.html s3://$BUCKET/index.html
aws s3 cp labs/06-static-site-cdn/site/error.html s3://$BUCKET/error.html
```

Until this runs the site returns an error. That is expected, not a fault.

## 1. The site, and the bucket that is not public (3 min)

Open `SiteUrl` from the stack outputs — it loads over HTTPS with a CloudFront certificate, no
domain or ACM setup involved.

Now try the origin directly:

```bash
curl -I https://$BUCKET.s3.ap-southeast-2.amazonaws.com/index.html
```

**403 Access Denied.** The site works and the bucket is genuinely private — those are not in
tension. **S3 → the bucket → Permissions** shows all four Block Public Access settings on.

## 2. Where the permission actually comes from (3 min)

**Permissions tab → Bucket policy.** One statement:

| | |
|---|---|
| Principal | `cloudfront.amazonaws.com` — a service, not a person or `*` |
| Action | `s3:GetObject` only |
| Condition | `AWS:SourceArn` equals **this** distribution |

That condition is what stops any other CloudFront distribution, in any AWS account, using your
bucket as its origin.

**CloudFront → the distribution → Origins → the S3 origin** shows the Origin Access Control
attached. OAC signs every origin request with SigV4; the bucket policy accepts that signature.

## 3. Caching, observed (3 min)

```bash
curl -sI https://<domain>/index.html | grep -i x-cache   # Miss from cloudfront
curl -sI https://<domain>/index.html | grep -i x-cache   # Hit from cloudfront
```

The first request travelled to S3; the second was answered at the edge and never reached your
bucket. That single header explains most CDN behaviour — and most CDN cost.

Compare with the uncached behaviour:

```bash
curl -sI https://<domain>/nocache/index.html | grep -i x-cache
```

That path pattern uses the `CachingDisabled` policy. Path-pattern behaviours are the same
mechanism that routes `/api/*` to a different origin in a real architecture.

## 4. Stale content (3 min) — the failure everyone meets

Edit `index.html` locally, upload it again, and reload the site. **The old content is still
served**, because the edge cached it and uploading to the origin notifies nobody.

```bash
aws cloudfront create-invalidation --distribution-id <id> --paths "/*"
```

Wait a minute and reload — the new content appears. In production you avoid this entirely by using
versioned object names (`app.a1b2c3.js`), so every deploy is a new object and no invalidation is
needed.

## 5. The 403-that-should-be-404 (2 min)

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://<domain>/no-such-page
```

You get **404**, because the distribution maps origin 403s to your error page. Without that
mapping you would see Access Denied — S3 returns 403 rather than 404 for a missing key when the
caller has no `ListBucket`, since revealing whether an object exists would itself leak information.

---

## Then

```bash
./labs/06-static-site-cdn/verify/checks.sh
./scripts/teardown.sh labs/06-static-site-cdn --yes
```

Teardown takes ~4 minutes: the distribution must be disabled before deletion, and the bucket must
be emptied **including every old version** — versioning is what makes that step necessary.
