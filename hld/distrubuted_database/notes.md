https://www.youtube.com/watch?v=chgXCko-p_Y
https://www.youtube.com/watch?v=8fd1J9mER3c

These detailed notes on designing a distributed database are compiled from the provided sources, covering architectural patterns, storage internals, and failure management.

### **1. Core Architectural Objectives**
A distributed database runs across multiple machines to provide **resilience, scalability, and improved performance**.
*   **Resilience:** Replicas ensure that if one instance fails, others can maintain operations.
*   **Scalability:** Systems can be scaled horizontally by adding new nodes, which is often more straightforward than upgrading a single machine's hardware.
*   **Latency:** Geographic distribution allows data to be placed closer to users, reducing the time for requests to travel.

### **2. Design Variations: Read-Heavy vs. Write-Heavy**
The choice of data structures and leadership models depends on the primary use case.
*   **Read-Heavy Case:**
    *   **B-trees** are often preferred for read-heavy scenarios (e.g., DynamoDB) because they are efficient for updates and optimized for page-sized disk reads.
    *   **Single-Leader Architecture** is used primarily for **right conflict handling**. By routing all writes for a specific record to one leader node, the system avoids concurrent write conflicts.
*   **Write-Heavy Case:**
    *   **LSM Trees (Log-Structured Merge Trees)** are more performant for heavy writes. However, they can be problematic for frequent updates due to "tombstones" (markers for deleted data).
    *   For extreme scenarios (e.g., a flash sale or Ticketmaster), the system should **shard heavily** and use **serializable isolation** on each leader node to maintain total ordering.

### **3. Internal Storage Engine (LSM-Style)**
For high-performance NoSQL systems like Bigtable, the following components are essential:
*   **Write-Ahead Log (WAL):** Every write is first committed to a WAL on disk to ensure data is not lost if a power outage occurs before the memory is flushed.
*   **Memtable (Skip List):** Writes are then stored in an in-memory **skip list**, which provides efficient $O(\log n)$ operations for inserts and searches.
*   **SS Tables (Sorted String Tables):** When the memtable reaches capacity, it is serialized and flushed to disk as an **immutable, sorted file**.
*   **Bloom Filters:** To avoid scanning every SS Table during a read, a **Bloom Filter** (a space-efficient probabilistic data structure) is checked first to determine if a key is definitely not present in a specific table.
*   **Compaction:** Chunks/SS Tables are periodically merged to remove duplicates and shrink file size.

### **4. Sharding and Request Routing**
To scale across multiple machines, data must be partitioned.
*   **Horizontal Sharding:** Rows are dispatched to different machines using **consistent hashing** based on the primary key.
*   **Request Router:** A component that tracks which node is responsible for which partition. It typically looks up this mapping in a **strongly consistent key-value store** like `etcd` or Zookeeper.
*   **Coordinator Pattern:** A coordinator server manages the hashmap and directs clients to the appropriate data servers.

### **5. Consistency and Replication**
*   **Consistency Levels:**
    *   **Strong Read Consistency:** Requests are sent directly to the **leader node**, which is more expensive but ensures the latest data.
    *   **Eventual Consistency:** Requests may hit read replicas, which is faster but might return stale data.
*   **Sequential Consistency:** This ensures a total ordering of records across the board. Using a single leader for all writes for a partition inherently provides sequential consistency because that node's clock is synchronized with itself.
*   **Replication:** At least one **synchronous read replica** is necessary for failover protection, ensuring no data is lost if the leader fails.

### **6. Failover and Rebalancing**
*   **Failure Detection:** Use algorithms like the **phi accrual failure detector** or hardcoded timeouts (e.g., 100ms within a data center) to determine if a leader node is dead.
*   **Leader Election:** Once a failure is detected, a synchronous replica is promoted to the new leader in the metadata store (e.g., `etcd`), and a new replica is created to maintain redundancy.
*   **Rebalancing:** When a new node is added, data is "gossiped" over until the new node is synchronized. It then becomes a synchronous replica and can eventually be promoted to a leader for specific partitions.

### **7. Distributed SQL vs. NoSQL**
*   **NoSQL:** Built to be cloud-native and horizontally scalable but often sacrifices strict schema enforcement and **ACID guarantees**.
*   **Distributed SQL:** A newer class of database that aims to provide the horizontal scaling of NoSQL while maintaining the **ACID transactions** and schemas of traditional relational databases.

----------------

Based on the sources, the performance differences between B-trees and LSM (Log-Structured Merge) trees are primarily defined by their optimization for either read or write workloads.

### **Read Performance**
*   **B-trees:** These are highly optimized for **read-heavy use cases**. They are effective for reads because they allow for optimizations like the "von Emde Boas" layout, which aligns the size of data pages pulled from the hard disk with the system's cache. This makes them more efficient for random read access.
*   **LSM trees:** These can be less efficient for reads because data may be spread across multiple **SS Tables** (Sorted String Tables) on disk. If a key is not in the in-memory "memtable," the system must search these disk-based tables. To mitigate this performance hit, LSM-based systems use **Bloom filters**—space-efficient data structures that tell the system if a key is definitely not in a particular SS Table, allowing it to skip unnecessary disk lookups.

### **Write Performance**
*   **LSM trees:** These are specifically designed for **heavy write scenarios**. They achieve high performance by treating writes as **append operations**. Data is first written to a Write-Ahead Log (WAL) and an in-memory "memtable" (often a skip list), which is extremely fast. Only when the memory reaches capacity is the data flushed to disk as an immutable SS Table.
*   **B-trees:** While B-trees are standard for many databases, they are generally considered **less performant than LSM trees for extremely heavy write workloads**, such as those encountered during a flash sale.

### **Update and Delete Performance**
*   **B-trees:** These are generally considered **good for updates**.
*   **LSM trees:** These can be **inefficient for frequent updates**. Because SS Tables are immutable, updates and deletes are handled by adding "tombstones" (markers indicating data has been deleted or changed). A high volume of updates can lead to many tombstones, which requires periodic **compaction**—a process that merges chunks to clean up duplicates and shrink the file size.

### **Summary Table**
| Feature | B-tree Performance | LSM tree Performance |
| :--- | :--- | :--- |
| **Primary Strength** | **Read-heavy** workloads | **Write-heavy** workloads |
| **Write Mechanism** | Update-in-place (typically) | Fast **append-only** writes |
| **Read Mechanism** | Optimized page-sized disk reads | Multi-layer search (Memtable → Bloom Filter → SS Table) |
| **Updates/Deletes** | Efficient updates | Uses **tombstones**; can be problematic if frequent |

--------------

In a distributed database, particularly one using an LSM-style storage engine, **Bloom filters** improve read speeds by acting as a fast, in-memory gatekeeper that prevents the system from performing unnecessary and expensive disk lookups.

Here is how they facilitate faster reads:

### **1. Avoiding Unnecessary Disk I/O**
Data in these systems is often stored in multiple **Sorted String Tables (SS Tables)** on disk. Without a Bloom filter, a read request would have to search through every SS Table to find a key, which involves time-consuming disk I/O operations. A Bloom filter allows the system to check in memory whether a key exists in a specific SS Table before ever touching the disk.

### **2. The "Definite No" Guarantee**
A Bloom filter is a **probabilistic data structure** based on hashing. It provides two types of answers:
*   **100% Negative:** If the filter says a key is **not present**, the system can skip that SS Table with absolute certainty, saving the time that would have been spent searching it.
*   **Possible Positive:** If the filter says a key **is present**, it means the key *might* be in that table. Because "false positives" are possible, the system will then proceed to perform a more expensive binary search on the actual disk-based SS Table to confirm.

### **3. Efficient Memory Usage**
Bloom filters are **extremely space-efficient** and have a fixed size that does not expand as more elements are added to the set. This allows the database to keep all Bloom filters for all SS Tables in **RAM**, ensuring that the initial check is always performed at high-speed memory latencies rather than slower disk latencies.

### **4. Integration into the Read Path**
In the full process of a read operation, the Bloom filter is checked immediately after the system fails to find a key in the in-memory **skip list** (memtable). By filtering out the majority of SS Tables that do not contain the requested data, the system dramatically reduces the number of disk reads required to return a result.
