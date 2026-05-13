https://www.youtube.com/watch?v=iHrsHqSAe18
https://www.youtube.com/watch?v=F06tdYgcz_A

### **Overview of Apache ZooKeeper and Coordination Services**

**ZooKeeper** is an open-source, centralized **coordination service** designed to manage configuration, naming, and synchronization across large-scale distributed systems. It acts as a shared "source of truth," ensuring all nodes in a cluster stay in sync regarding the system's state.

---

### **Core Concepts and Data Model**
*   **Hierarchical Structure:** ZooKeeper organizes data in a tree-like structure similar to a file system.
*   **Z-nodes:** The primary data units are called **Z-nodes**, which can store small amounts of configuration or state data.
*   **Types of Z-nodes:**
    *   **Persistent:** These remain in the system until explicitly deleted, surviving client disconnections or server restarts.
    *   **Ephemeral:** These exist only as long as the client session that created them is active; they are automatically deleted if the client fails or disconnects, preventing stale data.
*   **Watches:** Clients can register "watches" on Z-nodes to receive **real-time notifications** when data changes, allowing for responsive configurations.

---

### **Architecture: The Ensemble**
ZooKeeper typically runs as a cluster known as an **ensemble**.
*   **Leader Node:** All **write requests** are funneled through a single leader to ensure updates are orderly, consistent, and serialized.
*   **Follower Nodes:** Followers handle **read requests** from their local copies of the data and participate in consensus protocols to replicate writes.
*   **In-Memory Storage:** Every server in the ensemble maintains an in-memory copy of the entire Z-node hierarchy to ensure high-speed access.

---

### **Distributed Consensus and Reads**
*   **Consensus Algorithms:** Coordination services are built on top of consensus algorithms like **Raft** (used by etcd) or **Zab** (ZooKeeper Atomic Broadcast).
*   **Performance Trade-offs:** While consensus is slow due to the need for a "two-phase commit" style agreement, it is used for critical configuration data where **correctness** is more important than speed.
*   **Linearizable Reads:** To ensure a client doesn't read stale data from a follower that is lagging behind the leader, ZooKeeper uses a **sync keyword**.
    *   A client can issue a `sync` command which is written to the log and propagated.
    *   Once the `sync` reaches the follower, the client is guaranteed that its subsequent reads from 그 follower are up-to-date and linearizable.

---

### **Key Use Cases**
1.  **Configuration Management:** Centralizing settings for microservices so they can dynamically discover details.
2.  **Leader Election:** Helping a cluster of services agree on which node should be the "Master" (e.g., for a database or scheduler).
3.  **Service Discovery:** Dynamically identifying available services as they start or stop.
4.  **Distributed Locking:** Implementing locking mechanisms to ensure only one client can update a shared resource at a time.

---

### **Real-World Application**
*   **Technologies:** Major distributed frameworks like **Apache Kafka, Apache HBase, and Apache Hadoop** use ZooKeeper for internal coordination.
*   **Companies:** High-scale infrastructure at companies such as **Netflix, LinkedIn, and Pinterest** relies on ZooKeeper to manage critical systems.