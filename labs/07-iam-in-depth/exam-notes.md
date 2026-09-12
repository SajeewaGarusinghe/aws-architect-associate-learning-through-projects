# Exam notes — Lab 07 (IAM in depth)

Twelve SAA-C03-style questions on how IAM evaluates a request, then the traps and reference tables. Answers are at the bottom — try them cold first.

---

## Questions

**1.** A role has an identity policy allowing `s3:*`. The bucket's resource policy contains an explicit Deny for that role's ARN. The role also has AdministratorAccess attached. Can it read the bucket?

- A. No — an explicit Deny anywhere overrides every Allow
- B. Yes — AdministratorAccess overrides resource policies
- C. Only if the request comes from inside the VPC
- D. Yes — identity policies take precedence over resource policies

**2.** A role has an identity policy allowing `s3:*` and `ec2:*`, and a permission boundary allowing only `s3:Get*` and `s3:List*`. What can the role actually do?

- A. Everything in the identity policy — boundaries only apply to users
- B. Everything in the boundary, plus ec2:*
- C. Only s3:Get* and s3:List* — the intersection of policy and boundary
- D. Nothing, because the two conflict

**3.** A permission boundary allowing `s3:*` is attached to a role that has no identity policy at all. What can the role do?

- A. Only read operations in S3
- B. Everything in S3, since the boundary allows it
- C. Everything, because an empty identity policy means unrestricted
- D. Nothing — a boundary grants no permissions

**4.** A team must be able to create IAM roles for their applications without being able to grant those roles more access than the security team permits. What is the standard approach?

- A. Apply a service control policy to their IAM user
- B. Require a permission boundary on any role they create, enforced by a condition on iam:CreateRole
- C. Give them read-only IAM access and create roles on their behalf
- D. Grant them iam:* and audit role creation with CloudTrail

**5.** An EC2 instance in Account A must read an S3 bucket in Account B. What is the recommended mechanism?

- A. Make the bucket public and restrict by IP
- B. Create an IAM user in Account B and put its access keys on the instance
- C. Enable cross-region replication into Account A
- D. A role in Account B that the instance's role assumes, or a bucket policy granting the instance role

**6.** The policy simulator reports `implicitDeny` for an action. What does that mean?

- A. The simulator could not evaluate the request
- B. A service control policy blocked it
- C. No policy allowed the action, so the default deny applies
- D. A policy explicitly denied the action

**7.** A company has 40 teams and wants each to manage only its own EC2 instances, without writing 40 policies. Which approach fits best?

- A. A permission boundary per team
- B. One shared role with a very long policy listing every instance
- C. Attribute-based access control using tag conditions
- D. One IAM group per team with a team-specific policy

**8.** Which credential type does an application running on EC2 receive when it uses an instance profile?

- A. Temporary credentials that are automatically rotated
- B. A password stored in Secrets Manager
- C. A permanent access key and secret stored in the instance metadata
- D. The credentials of the user who launched the instance

**9.** An SCP attached to an account denies `s3:DeleteBucket`. A user in that account has AdministratorAccess. Can they delete a bucket?

- A. Only from the AWS console, not the CLI
- B. Only if they use the root user
- C. Yes — AdministratorAccess is evaluated after SCPs
- D. No — an SCP sets a ceiling the account cannot exceed, including for root

**10.** A role's trust policy determines what?

- A. What actions the role may perform
- B. How long the role's credentials remain valid
- C. Which principals are allowed to assume the role
- D. Which resources the role may access

**11.** Within a single account, an IAM role has no S3 permissions in its identity policy, but a bucket policy explicitly allows that role to GetObject. Can it read the object?

- A. Only if the bucket is in the same region
- B. No — the identity policy must also allow it
- C. Yes — within one account, an allow in either policy is sufficient
- D. Only if the role has s3:ListBucket as well

**12.** What is the practical difference between an IAM role and an IAM user?

- A. Roles are for AWS services, users are for people — nothing else differs
- B. A user has long-lived credentials; a role is assumed and issues temporary credentials
- C. Users can be assumed by services, roles cannot
- D. Roles cannot have policies attached

---

## Answers

**1 — A.** **Explicit deny wins, always.** It is evaluated first and nothing overrides it — not AdministratorAccess, not the account root, not a resource policy allow. This is the first rule of IAM evaluation and the most reliably tested one.

**2 — C.** Effective permissions are the **intersection** of the identity policy and the boundary. The boundary is a ceiling that grants nothing on its own — every EC2 action and every S3 write falls outside it and is denied, even though the identity policy plainly allows them.

**3 — D.** A boundary **only ever subtracts**. With no identity policy there is nothing to intersect with, so the effective permission set is empty and the role can do nothing. Treating a boundary as a way to grant access is the classic misunderstanding.

**4 — B.** A condition requiring `iam:PermissionsBoundary` on `CreateRole` means every role they create is capped, whatever policy they attach. This is the canonical use of boundaries: delegating role creation without enabling privilege escalation. Auditing after the fact does not prevent it.

**5 — D.** Either **cross-account role assumption** — a role in B trusting A, assumed via STS — or a **bucket policy in B** naming the instance's role directly. Both avoid long-lived credentials. Access keys on an instance are the anti-pattern the instance role exists to eliminate.

**6 — C.** **Implicit deny** is the default: nothing granted the action. **Explicit deny** means a policy actively forbade it. They need different fixes — an implicit deny is solved by adding an allow, an explicit deny by finding and removing the Deny statement, which no amount of additional allows will overcome.

**7 — C.** **ABAC** matches `aws:ResourceTag/team` against `aws:PrincipalTag/team` in a single policy that works for every team — including teams that do not exist yet. The trade-off is that tagging discipline becomes a security control. Role-per-team is correct but multiplies the policies to maintain.

**8 — A.** The instance profile delivers **temporary credentials via STS**, retrieved from the instance metadata service and rotated automatically before expiry. Nothing long-lived exists to leak or rotate — which is exactly why instance roles beat access keys in every scenario the exam presents.

**9 — D.** A **service control policy** is a ceiling on an entire account in an Organization. It grants nothing and cannot be overridden from inside the account — **including by the account root user**. Like a permission boundary, it only ever subtracts.

**10 — C.** The **trust policy** (the assume-role policy document) says *who may become* the role. The **permission policy** says *what the role may do* once assumed. Both must permit the operation: a principal with `sts:AssumeRole` still fails if the trust policy does not name it.

**11 — C.** **Within the same account**, an allow in the identity policy *or* the resource policy is enough. This is why S3 access can appear from nowhere when reading only the identity side. **Cross-account is different**: both the resource policy in the target account and the identity policy in the caller's account must allow it.

**12 — B.** A **user** is an identity with long-lived credentials — a password and/or access keys. A **role** has no credentials of its own: principals assume it and receive temporary STS credentials that expire. Current best practice is to avoid users almost entirely, using federation or instance/service roles instead.

---

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
