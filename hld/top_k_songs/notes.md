https://www.youtube.com/watch?v=HjazbLlrWxI

Designing a system to track the **Top K Heavy Hitters** (like Spotify's most played songs) requires handling massive data streams and providing real-time or near-real-time results. Below are detailed notes based on the system design for this problem.

### **1. Requirements Gathering**
To design the system effectively, several functional and non-functional requirements must be established:

*   **Functional Requirements:**
    *   **Top K:** The system should return the top $K$ songs, where $K$ typically ranges from **100 to 1,000**.
    *   **Time Windows:** It must support multiple windows, such as **all-time**, the **last hour**, or the **last month**. These windows are grounded in the current time (e.g., "the last hour from now").
*   **Non-Functional Requirements:**
    *   **High Throughput:** The system must handle approximately **10 billion events per day**, which translates to roughly **100,000 events per second**.
    *   **Scale:** It must track a catalog of roughly **100 million total songs**.
    *   **Low Latency:** Fetching the top $K$ list should take less than **100 milliseconds**.
    *   **Data Freshness:** A song play should be included in the ranking within about **one minute**.

### **2. High-Level Architecture**
The system follows a stream-processing pattern to avoid the high latency of batch jobs.
1.  **Event Collection:** Every song play generates an event sent to a message broker like **Apache Kafka**.
2.  **Stream Processing:** A consumer (either a framework like Flink or custom workers) aggregates these events.
3.  **Storage:** The aggregated top $K$ results are stored in a fast-access sink, such as **Redis**, for the API to query.
4.  **API Design:** A simple `GET` endpoint, such as `/topK?k=1000&window=1m`, allows clients to fetch the data via an API Gateway.

---

### **3. Solution Option A: Apache Flink**
Apache Flink is a powerful out-of-the-box solution for stream processing that handles much of the complexity of windowing and state management.

*   **Windowing:** Flink supports **sliding windows** (e.g., a 1-hour window that shifts every 5 seconds) and **tumbling windows**.
*   **State Management:** Flink is **stateful**; it can manage counts in memory (using hashmaps) and provides built-in mechanisms for persistence and snapshots.
*   **Scaling:** Flink can be scaled horizontally by **partitioning the data by Song ID**, allowing multiple subtasks to process different subsets of songs concurrently.

---

### **4. Solution Option B: Custom Distributed System**
If Flink is not used, the system must be built using custom workers and specific data structures.

#### **Core Data Structures**
*   **Hashmap:** Used to store the **song ID and its corresponding play count**.
*   **Min-Heap:** A min-heap of size $K$ is used to track the top songs.
    *   **Why Min-Heap?** When the heap is at capacity ($K$), and a new song count comes in, you compare it to the **minimum** value in the heap. If the new count is larger, you pop the minimum and push the new song.
*   **Index Map:** A second hashmap can store the **index of each song ID within the heap** to allow for $O(1)$ lookups and efficient $O(\log K)$ updates when counts change.

#### **Scalability and Fault Tolerance**
*   **Partitioning (Sharding):** To handle 100k events/sec, Kafka and the workers are **partitioned by Song ID**. Each worker is responsible for a subset of the total song catalog.
*   **Top K Service (Merge Step):** Since each worker only knows the top $K$ for its own partition, a separate **Top K Service** must aggregate these local lists (similar to "merging $K$ sorted lists") to determine the global top $K$.
*   **Replication & Snapshots:** To prevent data loss (since Kafka retention is limited), the system periodically **snapshots/checkpoints** the current counts to a database. New workers can load the latest snapshot and then replay Kafka messages from that specific offset.

#### **Implementing Custom Windows**
To implement a sliding window (e.g., "last hour") without Flink:
*   **Two-Pointer Approach:** Use two pointers in the Kafka stream.
*   **The Logic:** The **leading pointer** (current time) reads events and **increments** counts in the hashmap. The **trailing pointer** (offset by 1 hour) reads events and **decrements** those counts.
*   This effectively "removes" old data from the window as time passes.