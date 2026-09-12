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
