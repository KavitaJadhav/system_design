https://www.youtube.com/watch?v=Y-BO_4XNw8c&list=PLPtUyMfD0mNJDZg50fg2CptjLBavHot47

These detailed notes cover the comprehensive system design for a URL shortener like Bitly, based on the five-step framework discussed in the source material.

### **1. Requirement Gathering**
Before designing, it is crucial to establish the scope through functional and non-functional requirements.

*   **Functional Requirements:**
    *   **Core Feature:** Convert a long URL into a short URL (5-6 characters) and redirect users to the original URL when the short link is accessed.
    *   **Custom URLs:** Allow premium users to define their own short URL aliases (e.g., `bit.ly/my-custom-link`).
    *   **Expiration:** Support expiration dates for links; default is 90 days, but premium users can set custom dates.
*   **Non-Functional Requirements:**
    *   **Low Latency:** Redirection and URL creation should ideally happen within **200 milliseconds**.
    *   **Scalability:** The system must handle **100 million daily active users** and transform **1 billion URLs**.
    *   **Availability vs. Consistency:** Using the **CAP Theorem**, the system prioritizes **High Availability** over strong consistency, opting for **eventual consistency** to ensure the service is always reachable.
    *   **Uniqueness:** Every shortened URL must be unique to prevent mapping collisions.

### **2. Core Entities and API Design**
The system centers on three main entities: **User**, **Long URL**, and **Short URL**.

*   **API Endpoints:**
    *   `POST /v1/shorten`: Accepts a long URL in the body with optional fields for a custom alias and expiration date.
    *   `GET /v1/{shortUrl}`: Retrieves the original long URL for redirection.

### **3. High-Level Design (HLD)**
The basic flow involves a **Client**, a **Backend Server**, and a **Database**.
1.  The client sends a long URL to the server.
2.  The server generates a unique short key and saves the mapping (Long URL ↔ Short URL) in the database.
3.  The server returns the short URL to the client.
4.  For redirection, the server looks up the short key in the database and sends the long URL back to the client.

### **4. Low-Level Design (LLD) and Shortening Strategies**
The source explores three main approaches to generating short URLs, moving from simple to advanced:

#### **Approach A: Encryption/Hashing (MD5/SHA1)**
*   **Logic:** Use libraries like MD5 or SHA1 to hash the long URL and take the first 6 characters.
*   **Cons:** High chance of **collisions** (different long URLs producing the same 6-character hash). Resolving this requires expensive database scans to check for existing keys, significantly increasing latency.

#### **Approach B: Counter-Based (Redis)**
*   **Logic:** Use a global counter (stored in a **Redis cache**) that increments with every request. The unique number is returned as the short ID.
*   **Pros:** Very fast (2-3ms) and guarantees uniqueness without database lookups.
*   **Cons:** **Single point of failure**. If the Redis instance dies, ID generation stops. Clustering Redis can introduce synchronization issues and duplicate IDs.

#### **Approach C: The Hybrid Snowflake Solution (Recommended)**
*   **Logic:** Use **Zookeeper** to coordinate a distributed system where each server generates IDs locally using a **64-bit Snowflake ID** template.
*   **Snowflake ID Components:** Sign bit + 41-bit Timestamp + 10-bit Worker ID (from Zookeeper) + 12-bit Local Counter.
*   **Process:** The server generates a unique Snowflake ID locally, then encrypts it (MD5) and takes the first 6 characters.
*   **Pros:** **Bulletproof uniqueness** and extremely low latency because IDs are generated locally without external network calls per request.

### **5. Advanced Optimizations and Data Management**
*   **Microservice Separation:** Split the backend into **Encryption Servers** (for link creation, ~20% traffic) and **Decryption Servers** (for redirection, ~80% traffic) to scale them independently.
*   **Caching Layer:** Place a **Redis cluster** in front of the database for the redirection flow. This reduces redirection latency from ~15ms to ~7ms by avoiding frequent database reads.
*   **Redirection Codes:**
    *   **301 (Permanent):** Browser caches the mapping; reduces server load but prevents tracking/analytics.
    *   **302 (Temporary):** Every hit reaches the server; allows for detailed **analytics and logging** for premium users.
*   **Database Choice:** **PostgreSQL or MySQL** are suitable for storing the simple key-value mappings. A **primary index** must be placed on the `shortURL` column to ensure fast lookups.
*   **Cleanup:** Use a **Cron job** to delete expired records from the database daily, and ensure Redis entries have a **TTL (Time to Live)** matching the expiration date.