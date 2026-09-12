# Exam notes — Lab 06 (Static site + CDN)

Twelve SAA-C03-style questions on object storage, lifecycle policy and content delivery, then the traps and reference tables. Answers are at the bottom — try them cold first.

---

## Questions

**1.** A static website is served by CloudFront from an S3 origin. Security requires that the bucket never be publicly accessible, while the site stays reachable. What should be configured?

- A. Use a bucket ACL granting read to AuthenticatedUsers
- B. Enable S3 static website hosting and make the bucket public
- C. Use Origin Access Control and a bucket policy naming the CloudFront service principal
- D. Place the bucket in a private subnet

**2.** A CloudFront distribution returns 403 Access Denied for a URL path that does not exist in the S3 bucket, instead of a 404. Why?

- A. CloudFront caches 404 responses as 403
- B. The distribution is misconfigured and must be redeployed
- C. The bucket policy is missing s3:GetObject
- D. S3 returns 403 rather than 404 for a missing key when the caller lacks s3:ListBucket

**3.** Data must be retained for compliance for seven years, is essentially never accessed, and a retrieval time of twelve hours is acceptable. Which storage class minimises cost?

- A. S3 Glacier Instant Retrieval
- B. S3 Glacier Deep Archive
- C. S3 Intelligent-Tiering
- D. S3 Standard-Infrequent Access

**4.** An application's access pattern is unpredictable — some objects are read constantly, others not for months, and it changes over time. Which storage class is appropriate?

- A. S3 Intelligent-Tiering
- B. S3 One Zone-IA
- C. S3 Standard for everything
- D. A lifecycle policy moving everything to Glacier after 30 days

**5.** After uploading a corrected index.html to the origin bucket, viewers still receive the old content. What explains this?

- A. The bucket policy caches the old object
- B. Edge locations serve the cached object until its TTL expires or an invalidation is issued
- C. S3 is eventually consistent for overwrites
- D. Versioning is serving the previous version

**6.** A bucket has versioning enabled. A user deletes an object. What actually happens?

- A. A delete marker becomes the current version and previous versions remain
- B. The object and all its versions are permanently removed
- C. The delete is rejected until versioning is suspended
- D. The object moves to Glacier automatically

**7.** Content must be served only to users who have paid, with access expiring after 24 hours. What is the appropriate CloudFront mechanism?

- A. Geo-restriction
- B. Origin Access Control
- C. Signed URLs or signed cookies
- D. A bucket policy restricting by IP address

**8.** An S3 bucket in ap-southeast-2 serves large files to users in Europe, who report slow uploads. Which feature most directly addresses upload speed?

- A. S3 Transfer Acceleration
- B. CloudFront with a longer TTL
- C. Multipart download
- D. Cross-Region Replication

**9.** Which statement about S3 One Zone-IA is correct?

- A. It is the cheapest class for archival data
- B. It stores data in a single AZ and is unsuitable for data that cannot be recreated
- C. It has the same durability as Standard but slower retrieval
- D. It replicates across three availability zones like Standard

**10.** A company wants to ensure no bucket in the account can ever be made public, even if someone later attaches a permissive bucket policy. What provides this?

- A. Bucket versioning
- B. Default encryption
- C. A lifecycle policy
- D. S3 Block Public Access settings at the account level

**11.** CloudFront must serve content over HTTPS using a custom domain name. Where must the ACM certificate be requested?

- A. Certificates cannot be used with CloudFront
- B. In the same region as the origin bucket
- C. In any region, CloudFront replicates it
- D. In us-east-1, regardless of where other resources are

**12.** What is the main cost difference between a CloudFront cache hit and a cache miss?

- A. A hit costs more because edge storage is billed
- B. There is no cost difference
- C. A miss is free because the origin serves it
- D. A miss adds an origin request and origin data transfer on top of the edge delivery

---

## Answers

**1 — C.** **Origin Access Control** signs origin requests with SigV4, and the bucket policy allows `s3:GetObject` to the CloudFront service principal conditioned on the specific distribution ARN. All four public-access blocks stay on. S3 is not in a VPC, so subnets are irrelevant; `AuthenticatedUsers` means any AWS user anywhere, which is a classic wrong answer.

**2 — D.** S3 deliberately returns **403 for a nonexistent key** when the caller has no `s3:ListBucket` permission — revealing whether an object exists would itself leak information. A CloudFront custom error response mapping 403 to your 404 page is the standard fix, and this trips people constantly when debugging static sites.

**3 — B.** **Glacier Deep Archive** is the cheapest S3 storage, designed for long-term retention with retrieval measured in hours and a 180-day minimum duration. Glacier Instant Retrieval costs more because it offers millisecond access. Standard-IA is far more expensive for data never read. Intelligent-Tiering suits *unknown or changing* access patterns, not a known-cold one.

**4 — A.** **Intelligent-Tiering** moves objects between access tiers automatically based on observed usage, for a small per-object monitoring fee and no retrieval charges in the frequent and infrequent tiers. Whenever a question describes an access pattern as unknown, unpredictable or changing, this is the intended answer.

**5 — B.** CloudFront caches at edge locations for the TTL set by the cache policy — with `CachingOptimized` the default is 24 hours. Uploading to the origin does not notify the edges. Either invalidate the path or, better, use **versioned object names** so every deploy is a new object and no invalidation is needed. S3 has been strongly consistent since 2020.

**6 — A.** A delete on a versioned bucket writes a **delete marker** as the new current version; every prior version remains and is billable. Removing the delete marker restores the object. This also means a versioned bucket is not empty just because objects look deleted — which is why teardown must remove versions and delete markers.

**7 — C.** **Signed URLs** (one file) and **signed cookies** (many files or a whole area of a site) grant time-limited access to specific content. OAC controls how CloudFront reaches the *origin*, not who may reach CloudFront. Geo-restriction filters by country, not by entitlement.

**8 — A.** **Transfer Acceleration** routes uploads to the nearest CloudFront edge and carries them over the AWS backbone to the bucket, which helps most over long distances. CloudFront accelerates *downloads*, not uploads. Cross-Region Replication copies objects after they arrive, so it does not help the upload itself.

**9 — B.** **One Zone-IA stores data in a single availability zone**: roughly 20% cheaper than Standard-IA, and the data is lost if that AZ is destroyed. It suits easily recreatable data such as derived thumbnails or secondary copies — never the only copy of anything important.

**10 — D.** **Block Public Access** is a backstop that overrides bucket policies and ACLs — with it enabled, a policy granting public access is simply refused. Applied at the account level it covers every bucket including future ones. This is the single most effective control against accidental S3 exposure.

**11 — D.** A certificate used by CloudFront must be in **us-east-1 (N. Virginia)**, because CloudFront is a global service managed from that region. A certificate for an Application Load Balancer, by contrast, must be in the load balancer's own region. This asymmetry is a reliable exam detail.

**12 — D.** A **hit** is served from the edge and costs the request plus data transfer out. A **miss** adds an S3 GET request and origin-to-edge transfer. This is why cache hit ratio is the main CloudFront cost lever — and why offloading traffic from the origin is a cost benefit as much as a latency one.

---

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
