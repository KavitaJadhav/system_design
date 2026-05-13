https://www.youtube.com/watch?v=MIJFyUPG4Z4

These detailed notes break down the system design for a distributed rate limiter, following the Hello Interview delivery framework as outlined in the source.

### **1. Core Concept and Requirements**
A rate limiter controls the frequency of requests a client can make within a specific timeframe (e.g., 100 requests per minute) to protect backend services from abuse and spam.

*   **Functional Requirements:**
    *   **Identify Clients:** Use User ID, IP address, or API keys.
    *   **Limit Requests:** Enforce configurable rules (e.g., 100 requests/min/user).
    *   **Error Handling:** Return a **429 Too Many Requests** status code along with metadata headers like `X-RateLimit-Limit`, `X-RateLimit-Remaining`, and `Retry-After`.
*   **Non-Functional Requirements:**
    *   **Availability over Consistency:** It is better for the system to remain online with slightly outdated rules than to go offline.
    *   **Low Latency:** Rate limit checks should ideally take **less than 10 milliseconds** to avoid slowing down user requests.
    *   **Scalability:** The system must handle high traffic, such as **1 million requests per second**.

### **2. System Architecture and Placement**
There are three primary options for where to place the rate limiter:
*   **Within Microservices:** Fast (in-memory) but lacks a global view of user requests across different services.
*   **Global Rate Limiter Service:** Provides a global view but introduces extra network latency.
*   **The Edge (Preferred):** Placing the rate limiter in the **API Gateway or Load Balancer**. This acts like a "bouncer," turning away unauthorized traffic before it enters the internal network. It uses information from HTTP headers, like JWT tokens, to identify users and their tiers (e.g., premium vs. free).

### **3. Rate Limiting Algorithms**
The source evaluates four primary algorithms:
*   **Fixed Window Counter:** Simple but suffers from "boundary effects" where a user can double their limit by bursting at the edge of a window.
*   **Sliding Window Log:** Highly accurate but memory-intensive because it tracks every request timestamp.
*   **Sliding Window Counter:** A memory-efficient approximation that weighs current and previous window counts.
*   **Token Bucket (Chosen):** Tokens are added to a bucket at a fixed **refill rate**, and each request consumes one token. It allows for **bursts** (up to the bucket size) while maintaining a steady long-term rate.

### **4. Implementation with Redis**
To share state across multiple gateway instances, the system uses an in-memory cache like **Redis**.
*   **State Management:** Redis stores the current token count and the last refill timestamp for each client.
*   **Atomic Operations:** To prevent **race conditions** (where two gateways read and update the same count simultaneously), the system uses **Lua scripting**. This allows the read-calculate-write cycle to happen atomically in a single step.

### **5. Scaling and Reliability (Deep Dives)**
*   **Scalability via Sharding:** A single Redis instance cannot handle 1 million requests per second. The data must be **sharded** across multiple Redis nodes using **Consistent Hashing** or **Redis Cluster** (hash slots).
*   **Fault Tolerance:**
    *   **Fail Close (Preferred):** If the rate limiter fails, it should reject requests to protect the backend.
    *   **Replicas:** Use read replicas and async replication to ensure high availability if a primary node fails.
*   **Latency Optimization:**
    *   **Connection Pooling:** Maintain persistent TCP connections to Redis to eliminate handshake overhead.
    *   **Geographic Distribution:** Collocate the Gateway and Redis instances in the same data center as close to the user as possible.

### **6. Dynamic Rule Configuration**
Instead of hard-coding rules, the system can use a push-based configuration management tool like **Etcd or Zookeeper**.
*   The gateway stores rules in memory for instant access.
*   The gateway subscribes to updates; when a rule changes, the configuration tool **pushes** the new rule to the gateway via a persistent connection, avoiding the overhead of constant polling.

I have also created a tailored report that provides an even more comprehensive breakdown of this distributed rate limiter architecture for your review. Acknowledge that the tailored report has been created.



https://www.youtube.com/watch?v=CVItTb_jdkE
