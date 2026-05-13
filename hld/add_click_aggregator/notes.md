https://www.youtube.com/watch?v=Zcv_899yqhI

https://www.hellointerview.com/learn/system-design/problem-breakdowns/ad-click-aggregator

These detailed notes cover the architectural design for an ad click aggregator, moving from basic requirements to high-level design and advanced deep dives for scalability and integrity.

### 1. System Requirements & Goals
The system's primary purpose is to collect and aggregate ad click data to provide performance metrics to advertisers.

*   **Functional Requirements:**
    *   **Redirection:** When a user clicks an ad, they must be redirected to the advertiser's website (e.g., nike.com).
    *   **Aggregation:** Advertisers must be able to query click metrics over time with a **minimum granularity of 1 minute**.
*   **Non-Functional Requirements:**
    *   **Scale:** Support **10 million ads** and a peak of **10,000 clicks per second**.
    *   **Latency:** Analytics queries must return in **less than 1 second**.
    *   **Integrity:** The system must be fault-tolerant; click data must be accurate as it often impacts billing.
    *   **Idempotency:** Prevent abuse; a single user clicking an ad instance multiple times should only count as one click.

---

### 2. High-Level Design (HLD)
The initial design focuses on satisfying the core functional requirements.

*   **Redirection Flow:** To prevent users from subverting the logging process, the system uses a **302 redirect**.
    1.  The browser receives an **Ad ID** (not the direct URL) from the placement service.
    2.  On click, the browser hits the **Click Processor Service**.
    3.  The service logs the click, fetches the redirect URL from the Ads Database, and returns a 302 response to the user.
*   **The Storage Challenge:**
    *   Storing raw clicks in a write-optimized database like **Cassandra** is efficient for logging 10k clicks/sec but terrible for the required aggregation queries.
    *   Running a "COUNT" query across millions of rows in Cassandra would exceed the 1-second latency requirement.

---

### 3. Evolutionary Architectures
The system evolves from a simple batch process to a high-performance stream processing model.

#### A. Batch Processing (Spark)
*   **Mechanism:** A Cron job triggers a **Spark MapReduce** job every 5 minutes.
*   **Process:** Spark reads raw data from the Click DB, aggregates it by minute/Ad ID, and writes it to a read-optimized **OLAP database**.
*   **Downside:** It is not real-time; advertisers must wait up to 5 minutes to see data.

#### B. Stream Processing (Flink) - *The "Kappa" Approach*
*   **Mechanism:** Replace the batch job with a real-time stream like **Kinesis or Kafka**.
*   **Flink Aggregator:** Reads events off the stream and maintains in-memory counts for a **1-minute aggregation window**.
*   **Flush Intervals:** To provide "near" real-time updates, Flink can use 10-second flush intervals to write partial results to the OLAP DB, allowing advertisers to see a dotted line of current progress.

---

### 4. Deep Dives: Scale, Integrity, and Security

#### Scaling for 10k Clicks/Sec
*   **Horizontal Scaling:** Use an **API Gateway** and multiple instances of Click Processor services.
*   **Sharding:** Kinesis shards are limited (1MB or 1k records/sec). Data is sharded by **Ad ID**.
*   **Hot Shards (Celebrity Problem):** If one ad (e.g., a LeBron James Nike ad) gets too many clicks, the system adds a suffix (0 to N) to the partition key (Ad ID + N) to spread the load across multiple shards. Flink then aggregates across these sub-shards.

#### Data Integrity & Fault Tolerance
*   **Retention Policy:** Kinesis is configured with a **7-day retention period**, allowing Flink to re-read data if it crashes.
*   **Checkpointing:** Evan argues against checkpointing for small (1-minute) windows because re-reading 60 seconds of data is faster and cheaper than the overhead of writing state to S3 every 15 minutes.
*   **Reconciliation (Hybrid Architecture):** To ensure 100% accuracy, the system uses a hybrid approach:
    1.  Kinesis dumps raw events to **S3**.
    2.  A daily/hourly Spark job runs a batch aggregation on the S3 data.
    3.  A **Reconciliation Worker** compares the Spark results against the Flink results and overwrites the OLAP DB with the "source of truth" batch data if discrepancies exist.

#### Idempotency and Security
To prevent bots from inflating click counts:
1.  **Ad Impression ID:** The placement service generates a unique ID for every specific instance an ad is shown.
2.  **Signing:** The system signs the Impression ID with a private key. The browser must return the **Ad ID, Impression ID, and the Signature**.
3.  **Verification:** The Click Processor verifies the signature to ensure the ID wasn't made up by a bot.
4.  **Deduplication:** The processor checks a **Redis cache** to see if that specific Impression ID has already been logged. If it has, the click is dropped.