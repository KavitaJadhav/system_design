https://www.youtube.com/watch?v=MIJFyUPG4Z4
These detailed notes provide a comprehensive breakdown of designing a scalable distributed rate limiter, following the Hello Interview delivery framework.

### **1. Core Requirements and Scale**
*   **Functional Requirements:** The system must identify users (by ID, IP, or API key), limit requests based on **configurable rules** (e.g., 100 requests/minute), and return informative error headers and status codes.
*   **Non-Functional Requirements:**
    *   **High Availability:** Prioritized over strong consistency; the rate limiter should remain online even if rules are propagating.
    *   **Low Latency:** Checks should ideally take **under 10 milliseconds** to avoid slowing down user requests.
    *   **Scalability:** The system must handle approximately **1 million requests per second (RPS)**, supporting 100 million daily active users.
*   **Core Entities:** These include the incoming **Request**, the **Client** (identified by IP/ID), and the **Rules** (rate limits).

### **2. High-Level Design: Architecture and Placement**
*   **Placement Choice:** The rate limiter is best placed at the **Edge (API Gateway or Load Balancer)**. This acts like a "bouncer," rejecting unauthorized traffic before it reaches backend microservices, though it limits context to HTTP headers and JWT tokens.
*   **Shared State:** To avoid coordination issues where different servers track different counts, the rate limiter state must be stored in a **centralized in-memory cache like Redis**.

### **3. Rate Limiting Algorithms**
*   **Fixed Window Counter:** Simple to implement but suffers from a **boundary effect**, potentially allowing double the rate limit at the edge of time windows.
*   **Sliding Window Log:** Offers perfect accuracy but is **memory-intensive** because it tracks every request timestamp in a heap or deck.
*   **Sliding Window Counter:** A memory-efficient approximation that weighs the previous and current window counts.
*   **Token Bucket (Recommended):** The chosen algorithm for this design because it handles **bursts** (bucket size) and **steady rates** (refill rate) elegantly while remaining simple to implement with just two numbers: current tokens and last refill timestamp.

### **4. Implementation Details and Race Conditions**
*   **Redis Workflow:** When a request arrives, the gateway fetches the current token count and last refill time from Redis. It calculates new tokens based on the time elapsed, determines if the request can pass, and writes the updated state back.
*   **Atomic Operations:** To prevent **race conditions** (where two gateways read and write simultaneously, leading to incorrect counts), the system should use **Lua scripting**. This ensures the read-calculate-write cycle happens atomically in a single Redis thread.
*   **Error Responses:** Failed requests should return an **HTTP 429 (Too Many Requests)** status code. Best practice includes headers like `X-RateLimit-Limit`, `X-RateLimit-Remaining`, and `Retry-After`.

### **5. Deep Dives: Scaling and Reliability**
*   **Scalability via Sharding:** A single Redis instance cannot handle 1M RPS (typically capped at ~100k operations/sec). The solution is to use **Redis Cluster** to shard data across multiple nodes based on client IDs using hash slots.
*   **Fault Tolerance:**
    *   **Fail Close vs. Fail Open:** In this design, **failing close** is generally preferred to protect backend services, though a local backup (like a simple fixed window in gateway memory) can mitigate total outages.
    *   **Replication:** Use **async replication** with read replicas; if a primary node fails, a replica is promoted to maintain availability.
*   **Latency Optimization:**
    *   **Connection Pooling:** Maintain persistent TCP connections between the gateway and Redis to eliminate handshake overhead.
    *   **Geographic Proximity:** Colocate gateways and Redis instances in the same data centers near users to minimize network round trips.

### **6. Dynamic Configuration Management**
*   Rather than hard-coding rules or constant polling (which wastes CPU), use a **push-based system like Etcd or Zookeeper**. Gateways keep rules in memory for speed and subscribe to updates via persistent TCP connections, ensuring rules update in real-time without added latency to rate-limit checks.

### **7. Interview Performance Expectations**
*   **Mid-Level:** Should understand algorithm trade-offs, justify the edge placement, and explain the need for global state.
*   **Senior:** Must be proactive in identifying bottlenecks (like the 1M RPS limit), perform the math for sharding, and discuss fault tolerance (fail open/close).
*   **Staff:** Expected to lead the conversation, discussing advanced nuances like **Lua scripting for atomicity** or specific experiences with tuning connection pools.