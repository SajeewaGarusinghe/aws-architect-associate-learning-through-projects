# Console tour — Lab 05

Keep [the architecture diagram](docs/architecture.html) open beside the console. Budget about
12 minutes. Most of this happens in a terminal — there is no infrastructure to look at.

`./scripts/console-links.sh labs/05-decoupling` prints deep links.

---

## 1. Fan-out (3 min)

Take `TopicArn` from the stack outputs, then publish a high-priority message:

```bash
aws sns publish --topic-arn <TopicArn> --message "order-1234" \
  --message-attributes '{"priority":{"DataType":"String","StringValue":"high"}}'
```

**SQS console → `saa-lab-05-orders`** and **`saa-lab-05-audit`**. Both received it, from one publish.

Now publish a low-priority message:

```bash
aws sns publish --topic-arn <TopicArn> --message "order-5678" \
  --message-attributes '{"priority":{"DataType":"String","StringValue":"low"}}'
```

**The audit queue does not receive it.** That is the subscription's filter policy — evaluated at
SNS, so the audit consumer is never invoked and never pays for a message it would discard.

> The orders queue's messages disappear quickly: Lambda's poller is consuming them. Check
> **CloudWatch → `/aws/lambda/saa-lab-05-consumer`** to see `processed OK`.

## 2. The poison message (5 min) — the main event

```bash
aws sns publish --topic-arn <TopicArn> --message "poison-message"
```

Open the consumer's log group and watch. Roughly a minute apart you will see:

```
receive #1: poison-message
ERROR ValueError: cannot process (attempt 1): poison-message
receive #2: poison-message
receive #3: poison-message
```

Three things to notice:

| | |
|---|---|
| **The gap between attempts** | ~60 seconds — that is the **visibility timeout**, not a backoff setting |
| **`ApproximateReceiveCount`** | 1 → 2 → 3. This counter, not a timer, triggers the redrive |
| **Nothing else was blocked** | Publish another normal message mid-retry; it processes immediately |

After the third failure, **SQS → `saa-lab-05-orders-dlq` → Send and receive messages → Poll for
messages.** The poison message is here, with its attributes intact, and no further processing
attempts are being made against it.

## 3. Read the redrive configuration (2 min)

**SQS → `saa-lab-05-orders` → Dead-letter queue tab.**

- Maximum receives: **3**
- Dead-letter queue: the DLQ's ARN

**Details tab** shows visibility timeout 60s and retention 4 days. Compare with the DLQ's retention
of **14 days** — the maximum, chosen so evidence outlives the weekend.

> **The relationship that matters:** the consumer's timeout is 30 seconds and the visibility
> timeout is 60. If those were reversed, a second invocation would pick up the message while the
> first was still working, and the work would silently happen twice.

## 4. Redrive it back (2 min, optional)

Fix-and-retry is a real operational workflow. In the DLQ, choose **Start DLQ redrive → Redrive to
source queue**. The message returns to the orders queue and is retried — and since it is still
poison, it makes three more trips and comes straight back. That is the correct behaviour: redrive
is for after you have fixed the consumer.

---

## Then

```bash
./labs/05-decoupling/verify/checks.sh
./scripts/teardown.sh labs/05-decoupling --yes
```

Teardown is under a minute. Like Lab 04 this stack costs nothing at rest — it is destroyed for
consistency, so `verify-clean.sh` keeps meaning what it says.
