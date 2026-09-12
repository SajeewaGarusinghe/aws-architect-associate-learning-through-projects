## The traps, condensed

1. **Never fix a CloudFront 403 by making the bucket public.** It is almost always OAC, the bucket
   policy's source-ARN condition, or a missing key. Turning off public access blocks exposes every
   object permanently.
2. **S3 returns 403, not 404, for a missing key** when the caller has no `ListBucket`. Map it with a
   custom error response.
3. **Uploading does not update the edges.** Versioned object names beat invalidation; reserve
   invalidation for names that cannot change.
4. **A delete on a versioned bucket writes a delete marker.** The old versions remain and keep
   billing — and the bucket is not empty for teardown purposes.
5. **Intelligent-Tiering is the answer whenever the access pattern is unknown or changing.**
6. **One Zone-IA is one AZ.** Only for data you can recreate.
7. **CloudFront certificates live in us-east-1.** ALB certificates live in the ALB's region.
8. **Block Public Access overrides policies and ACLs.** Apply it account-wide.
9. **Transfer Acceleration is for uploads; CloudFront is for downloads.**

## Reference — S3 storage classes

| Class | Retrieval | Min duration | Use for |
|---|---|---|---|
| Standard | ms | none | Active data |
| Intelligent-Tiering | ms | none | **Unknown or changing** access patterns |
| Standard-IA | ms | 30 days | Infrequent, needs instant access |
| One Zone-IA | ms | 30 days | Recreatable secondary copies (single AZ) |
| Glacier Instant Retrieval | ms | 90 days | Archives still needing instant access |
| Glacier Flexible Retrieval | minutes–hours | 90 days | Archives, occasional restore |
| Glacier Deep Archive | ~12 hours | 180 days | Compliance retention, cheapest of all |

All classes except One Zone-IA store data across at least three availability zones, and all offer
eleven nines of durability. The differences are retrieval time, retrieval cost, and minimums.

## Reference — CloudFront essentials

| Concept | What to remember |
|---|---|
| Origin Access Control | Current mechanism; SigV4-signed origin requests; supports KMS. Replaces OAI. |
| Cache behaviours | Path patterns route to different origins and cache policies; `/api/*` is the classic case. |
| Invalidation | First 1,000 paths a month free; slow. Prefer versioned filenames. |
| Signed URLs / cookies | Time-limited access — URLs for one file, cookies for many. |
| Geo-restriction | Allow or block by country. |
| Price class | Restricting edge locations lowers cost at the expense of global reach. |
| Custom error responses | Map origin 403/404 to your own pages; also how SPAs serve deep links. |
| Certificates | Must be in **us-east-1** for a custom domain. |

## Reference — protecting an S3 bucket

| Control | Scope | Notes |
|---|---|---|
| Block Public Access | Account or bucket | Overrides policies and ACLs — the strongest backstop |
| Bucket policy | Bucket | Resource policy; can grant cross-account on its own |
| IAM policy | Principal | Identity side; either an identity or resource allow suffices in-account |
| ACLs | Object/bucket | Legacy; AWS recommends disabling via Object Ownership |
| Versioning | Bucket | Makes overwrite and delete recoverable |
| Object Lock | Object | WORM retention; needed for genuine immutability claims |
