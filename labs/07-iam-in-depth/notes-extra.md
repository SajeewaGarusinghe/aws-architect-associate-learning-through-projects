## The traps, condensed

1. **Explicit deny beats everything.** AdministratorAccess, the account root, a resource policy
   allow — none of them override it.
2. **A boundary grants nothing.** Effective permissions are the *intersection* of identity policy
   and boundary. A boundary with no identity policy yields zero access.
3. **`implicitDeny` and `explicitDeny` need different fixes.** Add an allow for the first; find and
   remove the Deny for the second.
4. **Within one account, identity OR resource policy is enough.** Cross-account needs **both**.
5. **Trust policy = who may assume. Permission policy = what it may do.** Both must pass.
6. **SCPs are ceilings on a whole account**, and apply to the root user too.
7. **Instance profiles deliver temporary, auto-rotated credentials.** Access keys on an instance
   are always the wrong answer.
8. **ABAC scales where role-per-team does not** — one policy, tag conditions, works for teams that
   do not exist yet.
9. **IAM is eventually consistent.** A just-changed policy can take seconds to apply everywhere.

## Reference — the evaluation order

| Step | Outcome if it fails |
|---|---|
| 1. Explicit **Deny** in any applicable policy | **Denied, immediately** — evaluation stops |
| 2. Service control policies (Organizations) | Denied — even for the account root |
| 3. Resource-control policies / session policies | Denied |
| 4. **Permission boundary** | Denied — the ceiling was not met |
| 5. Identity policy **or** resource policy allow | Allowed if either permits (same account) |
| 6. Nothing allowed it | **Implicit deny** — the default |

Two questions answer nearly every IAM problem: *is something explicitly denying it?* and *is
anything actually allowing it?*

## Reference — policy types

| Type | Attached to | Grants? | Notes |
|---|---|---|---|
| Identity policy | User, group, role | **Yes** | Managed or inline |
| Resource policy | Bucket, queue, topic, function, KMS key | **Yes** | Can grant cross-account on its own |
| Permission boundary | User or role | **No — caps only** | Intersection with the identity policy |
| Service control policy | OU or account | **No — caps only** | Organizations; applies to root too |
| Session policy | A specific STS session | **No — caps only** | Passed at assume-role time |
| Trust policy | A role | n/a | Says *who may assume*, not what they may do |

## Reference — condition keys worth recognising

| Key | Use |
|---|---|
| `aws:PrincipalTag/<k>` | The caller's tag — the ABAC half that identifies the principal |
| `aws:ResourceTag/<k>` | The resource's tag — the other ABAC half |
| `aws:RequestTag/<k>` | Tags being applied in this request — enforce tagging on create |
| `aws:SourceArn` / `aws:SourceAccount` | Restrict a service principal to one resource or account |
| `aws:PrincipalArn` | Match a specific role or user, as in this lab's explicit deny |
| `aws:SecureTransport` | Require TLS |
| `aws:MultiFactorAuthPresent` | Require MFA for sensitive actions |
| `iam:PermissionsBoundary` | Require a boundary when creating a role — the delegation pattern |
