https://www.youtube.com/watch?v=9JKBlkwg0yM&t=918s

https://www.youtube.com/watch?v=-eMtcFqj8vI - recap 55:00

https://www.youtube.com/watch?v=EX5uZV3Tzss&pp=ugUEEgJlbg%3D%3D



These detailed notes explore the system design for a collaborative text editor (like Google Docs), focusing on real-time synchronization, conflict resolution, and large-scale architecture.

### **1. Core System Requirements**
#### **Functional Requirements**
*   **CRUD Operations:** Users must be able to create, read, update, and delete documents.
*   **Concurrent Editing:** Multiple users should be able to edit the same document simultaneously.
*   **Real-time Visibility:** Updates and cursor positions of other active users must be visible in near real-time.
*   **Versioning and History:** The system should maintain a version history for rollback and tracking.

#### **Non-Functional Requirements**
*   **Massive Scale:** The system should support millions of concurrent users and billions of documents.
*   **Low Latency:** To prevent chaotic editing experiences, update latency should be under **100ms to 200ms**.
*   **Consistency vs. Availability:** While the system should be highly available, **consistency** is prioritized during collaborative sessions to ensure all users see the same state.
*   **Concurrency Limits:** A realistic limit of **100 concurrent users per document** is standard to maintain a manageable user experience.

---

### **2. High-Level Architecture**
The system utilizes a microservices architecture to separate concerns and scale effectively:
*   **Load Balancer / API Gateway:** Handles initial traffic, authentication, and rate limiting.
*   **Document Metadata Service:** Manages document titles, permissions, and owner information.
*   **Document Editor Service:** The core service handling real-time editing logic and WebSocket connections.
*   **Storage Layers:**
    *   **Relational/NoSQL DB:** Stores metadata (PostgreSQL, MySQL, or Cassandra).
    *   **Object Storage (S3/Blob Store):** Stores the actual textual content, as these files can grow large.
    *   **CDN:** Fronts object storage to provide fast, low-latency access for read-only users.

---

### **3. Real-time Communication & Scaling**
For real-time collaboration, standard HTTP polling is inefficient. Instead, the system uses:
*   **WebSockets:** Provides a **bi-directional, full-duplex connection** allowing the server to push updates instantly to all clients.
*   **Stateful Scaling (Consistent Hashing):** Because collaborative editing requires a "source of truth" for ordering, all users of a single document must be routed to the **same WebSocket server instance**. **Consistent hashing** is used to map Document IDs to specific servers.
*   **WebSocket Registry:** A backend registry tracks which user is connected to which server to maintain connection stickiness.

---

### **4. Conflict Resolution Strategies**
The primary challenge in collaborative editing is resolving conflicts when two users edit the same text simultaneously.

#### **A. Operational Transform (OT)**
*   **Mechanism:** OT takes an edit (e.g., "insert 'A' at index 5") and transforms its index based on concurrent operations from other users to maintain consistency.
*   **Server-Side Logic:** The server acts as the sequencer, ordering edits and broadcasting the transformed instructions to all clients.
*   **Usage:** This is the method used by **Google Docs**.

#### **B. Conflict-free Replicated Data Types (CRDT)**
*   **Mechanism:** A data structure where every character is assigned a unique, fractional position value rather than a simple index.
*   **Benefit:** Conflicts are resolved automatically based on these unique values without requiring a central sequencer.

---

### **5. Data Flow & Persistence (Deep Dive)**
To maintain performance while ensuring durability, a **hybrid approach** is used for saving data:
1.  **Deltas vs. Full Files:** Instead of sending the whole document for every keystroke, clients only send the **"delta" (the specific change)**.
2.  **In-Memory Buffer:** Active document states are stored in a **Redis cluster** (the "canonical copy") for immediate access.
3.  **Message Queues (Kafka):** Edits are pushed to a queue for asynchronous persistence into a write-heavy database like **Cassandra**.
4.  **Compaction & Snapshots:** Every 10–20 seconds (or when users leave the "room"), a **compaction worker** takes the recent edits, applies them to the base file in object storage, and saves a new version.
5.  **Reconciliation:** After a session ends, a reconciliation service merges all intermediate "minor versions" into a final "major version" to optimize storage space.

### **6. Specialized Features**
*   **Cursor Tracking:** The positions of user cursors are sent via WebSockets and stored in Redis with a Time-to-Live (TTL) to manage presence.
*   **Offline Access:** While complex, this typically involves local storage of edits that are synchronized once the connection is restored.
* 