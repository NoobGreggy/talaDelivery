/**
 * Inspects BullMQ queue state in Redis so event fan-out problems are
 * visible without guessing from application logs.
 *
 *   node test/inspect-queues.mjs [queueName]
 */
import 'dotenv/config';
import { Queue } from 'bullmq';

const connection = {
  host: process.env.REDIS_HOST ?? '127.0.0.1',
  port: Number.parseInt(process.env.REDIS_PORT ?? '6379', 10),
};
const prefix = process.env.BULLMQ_PREFIX ?? 'bull';

const only = process.argv[2];
const names = only
  ? [only]
  : ['order-events', 'delivery-events', 'notification-jobs', 'offer-expiry', 'payment-events', 'location-events'];

for (const name of names) {
  const queue = new Queue(name, { connection, prefix });
  try {
    const counts = await queue.getJobCounts(
      'waiting', 'active', 'completed', 'failed', 'delayed', 'paused',
    );
    const total = Object.values(counts).reduce((a, b) => a + b, 0);
    console.log(
      `${name.padEnd(20)} ${total === 0 ? 'EMPTY' : JSON.stringify(counts)}`,
    );

    if (counts.waiting > 0) {
      const waiting = await queue.getWaiting(0, 4);
      for (const job of waiting) {
        console.log(
          `   waiting #${job.id} ${job.name} type=${job.data?.eventType}`,
        );
      }
    }
    if (counts.failed > 0) {
      const failed = await queue.getFailed(0, 4);
      for (const job of failed) {
        console.log(
          `   failed #${job.id} ${job.name} type=${job.data?.eventType} :: ${job.failedReason}`,
        );
      }
    }
  } catch (err) {
    console.log(`${name.padEnd(20)} ERROR ${err.message}`);
  } finally {
    await queue.close();
  }
}
