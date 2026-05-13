https://www.youtube.com/watch?v=0LTXCcVRQi0

https://www.youtube.com/watch?v=krsuaUp__pM

https://www.youtube.com/watch?v=TByRaraQqW4

The following detailed notes synthesize information from the sources regarding the architecture and design of a large-scale search engine like Google, covering crawling, indexing, and autocomplete (type-ahead) systems.

### **I. Web Crawling & Data Acquisition**
The foundation of a search engine is the ability to discover and download the billions of pages on the internet.

*   **Recursive Process:** Crawlers start with a set of "seed URLs". They download the HTML, extract text, and find new URLs within that HTML to add back to the "Frontier" for future crawling.
*   **The URL Frontier:** This component manages the list of URLs yet to be crawled. It must handle two critical constraints:
    *   **Priority:** High-traffic sites like news outlets (e.g., CNN) need to be crawled daily, while personal homepages might only need updates monthly.
    *   **Politeness:** To avoid overwhelming (DDoS) a website's server, the system should only crawl one host at a time from any given worker and respect the site's `robots.txt` file. A good rule of thumb is to wait 10 times the page load time before the next request.
*   **Architecture & Fault Tolerance:**
    *   **Pipeline Separation:** It is more robust to split the crawler into two phases: **Phase 1: Fetching HTML** and **Phase 2: Parsing HTML**. This allows the system to isolate the error-prone process of network fetching from the computational process of parsing.
    *   **Retries:** Use message queues like **Amazon SQS** to handle failures with **exponential backoff**. If a crawl fails five times, the URL is moved to a "dead letter queue".
*   **Scale:** Handling 100 billion pages may require 10,000+ nodes and nearly 2 terabits per second of bandwidth.

### **II. Storage & Indexing**
Storing and searching massive amounts of data requires a distributed approach to manage storage efficiency and query speed.

*   **Hybrid Storage Strategy:**
    *   **Blob Store (e.g., Amazon S3):** Stores raw page content (hundreds of petabytes), which is too large for traditional databases.
    *   **Metadata Database:** Stores smaller site details like URLs, titles, descriptions, and hashes (approx. 30 terabytes). This database should be **sharded** by URL to distribute the load across multiple nodes.
*   **De-duplication:** Because many pages on the internet are duplicates, the system uses **hashing** or "shingles" (for close duplicates) to ensure unique records are only stored once.
*   **Global Indices:**
    *   **Hash Index:** Maps a content hash to a URL to find duplicates quickly.
    *   **Text/Word Index:** This is a sharded database where the "word" is the shard key. It stores which URLs contain a specific word and the frequency of that word, allowing the API to return the most relevant sites for a query.

### **III. Autocomplete (Type-Ahead) System**
The autocomplete system provides the Top 10 search suggestions based on the user's prefix and search frequency.

*   **Core Requirements:**
    *   **Functional:** Show results after 3 characters are typed; results must be ranked by search frequency.
    *   **Non-Functional:** Availability is prioritized over strong consistency (it is okay if frequency counts take time to update); latency must feel instantaneous (<10ms).
*   **Data Structures:**
    *   **Tries (Prefix Trees):** Ideal for prefix searches but difficult to shard and lack stable persistent database implementations for massive scales.
    *   **Hashmap Strategy:** Use two hashmaps—one to map a **prefix to Top K results**, and another to map the **full search string to its total count**.
    *   **Redis Sorted Sets:** Highly effective for maintaining leaderboards of top search terms by frequency, offering low-latency in-memory performance.
*   **Optimization Strategies:**
    *   **Debouncing:** The client-side delays API calls until the user pauses typing (e.g., 30ms to 1s) to prevent a flood of requests on every keystroke.
    *   **Sampling:** For massive data, the system can use **uniform random sampling** (e.g., only recording 1% of searches) to capture the same trends while significantly reducing CPU and memory consumption.
    *   **Batching:** Instead of updating the autocomplete structure for every search, updates can be batched or triggered only after a search term's count crosses a threshold (e.g., every 100 increments).

### **IV. High-Level API Design**
*   **Search Engine API:** A single `GET` endpoint that accepts a query and returns titles, descriptions, and URLs, utilizing a **load balancer** to route traffic across horizontally scaled API nodes.
*   **Autocomplete API:** A `GET /autocomplete` request that returns a JSON list of suggestions.
*   **Increment Search API:** A `PUT /increment_search` request (internal only to avoid bot attacks) used to update the frequency of a query asynchronously via a message queue like Kafka or SQS.