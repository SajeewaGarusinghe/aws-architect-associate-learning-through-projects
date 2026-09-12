# Exam notes — Lab 05 (Decoupling)

Twelve SAA-C03-style questions on queues, topics and asynchronous failure handling, then the traps and reference tables. Answers are at the bottom — try them cold first.

---

## Questions

**1.** An order service must notify three separate downstream systems whenever an order is placed. Each system must receive every order and process it independently at its own pace. What is the appropriate design?

- A. An SNS topic with all three systems subscribed by HTTP endpoint
- B. An SNS topic with three subscribed SQS queues, one per system
- C. Three Lambda functions invoked directly by the order service
- D. One SQS queue that all three systems poll

**2.** A Lambda function consuming from SQS has a 60-second timeout. The queue's visibility timeout is 30 seconds. What is the likely consequence?

- A. Messages are deleted before processing completes
- B. The same message is delivered to a second invocation while the first is still running
- C. The function is throttled to match the visibility timeout
- D. Messages go straight to the dead-letter queue

**3.** A message in an SQS queue cannot be processed successfully — it fails every time. Without a dead-letter queue configured, what happens?

- A. It blocks the queue permanently and no other message is processed
- B. SQS deletes it after three attempts
- C. It is moved to a hidden quarantine queue automatically
- D. It is retried until the message retention period expires, up to 14 days

**4.** An SNS topic has two SQS subscribers. One should receive only messages where a `priority` attribute equals `high`. What is the most efficient way to achieve this?

- A. Use a FIFO topic with message group IDs
- B. Create a second topic and publish to both
- C. Filter inside the consumer and discard unwanted messages
- D. Apply a filter policy to that subscription

**5.** What delivery guarantee does a standard SQS queue provide?

- A. Exactly once, in the order sent
- B. At least once, with best-effort ordering
- C. At most once, with guaranteed ordering
- D. Exactly once, with no ordering guarantee

**6.** An application must process financial transactions in the exact order submitted, with no duplicates. Which service configuration is appropriate?

- A. A standard queue with a 0-second visibility timeout
- B. A standard SQS queue with a Lambda consumer
- C. An SNS standard topic with an SQS subscriber
- D. An SQS FIFO queue with message group IDs

**7.** A Lambda function consuming SQS catches all exceptions and returns normally, logging failures. Messages that fail are never retried and never reach the dead-letter queue. Why?

- A. The DLQ redrive policy is misconfigured
- B. The visibility timeout is too short
- C. Returning without raising tells Lambda the batch succeeded, so the messages are deleted
- D. Lambda only retries on timeout, not on exceptions

**8.** A queue receives a large burst of messages, and the Lambda consumer scales up to hundreds of concurrent executions, overwhelming a downstream database. What is the appropriate control?

- A. Increase the visibility timeout
- B. Reduce the queue's message retention period
- C. Switch the queue to FIFO
- D. Set reserved concurrency on the consuming function

**9.** What is the main cost benefit of long polling on an SQS queue?

- A. It reduces the number of empty ReceiveMessage responses, which are billable requests
- B. It compresses messages in transit
- C. It allows a larger batch size
- D. It reduces the per-message storage charge

**10.** An SNS topic delivers to an HTTP endpoint that is down for an hour. What happens to messages published during that window, with no dead-letter queue configured on the subscription?

- A. Publishing fails and the publisher receives an error
- B. They are queued in SNS and delivered when the endpoint recovers
- C. They are stored for 14 days like SQS messages
- D. They are retried according to the delivery policy and then discarded

**11.** What does a redrive policy with `maxReceiveCount` set to 3 actually count?

- A. The number of seconds a message may remain invisible
- B. The number of retries per second allowed
- C. The number of times a message has been received before being moved to the DLQ
- D. The number of consumers permitted to read the queue

**12.** A workload needs to route events to different targets based on the content of the event, with rules that change frequently and may match on many fields. Which service fits best?

- A. Step Functions
- B. SNS with filter policies
- C. Amazon EventBridge
- D. SQS with multiple queues

---

## Answers

**1 — B.** A standard SQS queue delivers each message to **one** consumer — three systems polling one queue would *split* the orders, not each receive a copy. SNS fan-out to one queue per subscriber gives each system its own buffer, retries and dead-letter behaviour. HTTP subscribers would receive the message but get no queue, so an outage loses it.

**2 — B.** The message becomes visible again after 30 seconds — **while the first invocation is still working** — so a second consumer picks it up and the work happens twice, with no error anywhere to reveal it. The rule is **visibility timeout ≥ function timeout**, conventionally six times it.

**3 — D.** Without a redrive policy the message keeps returning to the queue until **message retention** expires — default 4 days, maximum 14. It consumes invocations and fills logs the whole time. With a small batch size it can also delay messages behind it, though it does not block the queue permanently.

**4 — D.** A **filter policy** is evaluated at SNS, so non-matching messages are never delivered to that queue and the consumer is never invoked for them — cheaper and simpler than filtering in code. Filtering in the consumer means paying to receive and discard. A second topic makes the publisher aware of the routing again.

**5 — B.** Standard queues guarantee **at least once** delivery with best-effort ordering — a message can be delivered more than once and out of order. Consumers must therefore be **idempotent**. FIFO queues provide exactly-once processing and strict ordering, at much lower throughput.

**6 — D.** **FIFO queues** give strict ordering within a message group and exactly-once processing inside a 5-minute deduplication window. The cost is throughput — 300 messages/second, or 3,000 with batching, versus effectively unlimited for standard. Order is preserved *per message group*, so the group ID choice determines how much parallelism remains.

**7 — C.** Lambda's managed poller deletes messages when the handler **returns without raising**. Swallowing the exception is therefore indistinguishable from success: the data is silently discarded, the queue looks healthy, and the DLQ stays empty. Failure must propagate as a raised exception — or be reported via batch item failures for partial batches.

**8 — D.** **Reserved concurrency** caps how many instances of the function may run at once, so the queue absorbs the burst while the database sees a bounded rate — which is exactly the buffering a queue exists to provide. Retention and visibility timeout do not limit concurrency. FIFO would serialise things but for the wrong reason and at a heavy throughput cost.

**9 — A.** Short polling returns immediately even when the queue is empty, and **every empty receive is a billable request**. Long polling — `ReceiveMessageWaitTimeSeconds` up to 20 — waits for a message to arrive, cutting empty receives dramatically. It also reduces latency, since the message is returned the moment it lands.

**10 — D.** **SNS is push-based and does not store messages indefinitely.** It retries per the delivery policy and then drops them unless the subscription has a dead-letter queue. This is precisely why the SNS-to-SQS pattern exists: the queue provides the durable buffer that a raw HTTP subscription does not.

**11 — C.** It counts **receives**, tracked as `ApproximateReceiveCount` on each message. When a message has been received more than `maxReceiveCount` times without being deleted, SQS moves it to the dead-letter queue instead of making it visible again. The interval between attempts is the visibility timeout, not a backoff setting.

**12 — C.** **EventBridge** is the event bus built for content-based routing: rich rule patterns over the event body, many target types, schema registry, and third-party SaaS sources. SNS filter policies work on message *attributes* and suit simpler cases. Step Functions orchestrate multi-step workflows rather than route events.

---

## The traps, condensed

1. **One queue does not fan out.** Several consumers on one standard queue *split* the messages.
   Each consumer needing every message means SNS → one queue each.
2. **Visibility timeout ≥ function timeout.** Get this backwards and the same message is processed
   twice with no error anywhere. Conventionally six times the function timeout.
3. **Swallowing the exception deletes the message.** A Lambda SQS consumer signals failure by
   raising. `try/except: pass` is silent data loss that looks like a healthy queue.
4. **At least once means design for duplicates.** Consumers must be idempotent unless you are on
   FIFO — and even FIFO's exactly-once applies within a 5-minute dedup window.
5. **SNS does not store messages.** No subscriber, or a failing one with no DLQ, means the message
   is gone. The queue is what provides durability.
6. **`maxReceiveCount` counts receives, not seconds.** The gap between retries is the visibility
   timeout.
7. **Long polling is nearly free money.** Empty receives are billable; `ReceiveMessageWaitTimeSeconds`
   of 20 removes most of them and lowers latency too.
8. **Reserved concurrency is how you protect what is downstream.** A queue absorbing a spike is
   useless if the consumer scales to hundreds and floods the database behind it.

## Reference — SQS standard vs FIFO

| | Standard | FIFO |
|---|---|---|
| Throughput | Effectively unlimited | 300/s, 3,000/s batched |
| Ordering | Best effort | **Strict, per message group** |
| Delivery | **At least once** | Exactly once within the dedup window |
| Deduplication | None | 5-minute window, by ID or content hash |
| Queue name | Any | Must end `.fifo` |
| Use when | Throughput matters, consumers idempotent | Order or exactly-once genuinely required |

## Reference — choosing the messaging service

| Service | Model | Reach for it when |
|---|---|---|
| **SQS** | Pull, durable buffer | Absorb spikes, survive consumer outages, decouple pace |
| **SNS** | Push, fan-out | One event must reach many independent subscribers |
| **SNS → SQS** | Both | Fan-out *and* durability — the pattern in this lab |
| **EventBridge** | Push, content routing | Rules over event content, many targets, SaaS sources |
| **Step Functions** | Orchestration | A multi-step workflow with state, retries and branching |
| **Kinesis** | Streaming, replayable | Ordered stream, multiple readers at different positions, replay |

## Reference — the SQS settings that get tested

| Setting | Default | Controls |
|---|---|---|
| Visibility timeout | 30 s | How long a received message stays hidden |
| Message retention | 4 days | How long an unprocessed message survives (max 14) |
| `maxReceiveCount` | none | Receives before redrive to the DLQ |
| Receive wait time | 0 s (short poll) | Long polling, up to 20 s |
| Delivery delay | 0 s | Delay before a message becomes visible at all (max 15 min) |
| Max message size | 256 KB | Larger payloads go to S3 with a pointer in the message |
