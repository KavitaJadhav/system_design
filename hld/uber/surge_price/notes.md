https://www.linkedin.com/posts/puneet-patwari_im-a-principal-engineer-with-over-12-years-activity-7441807783886336000-DIKk?utm_source=share&utm_medium=member_desktop&rcm=ACoAABUjotEB4-ipAmiNVL8fO6n9eAJ77R-tgqM

https://medium.com/@kanishks772/the-secret-sauce-behind-ubers-surge-pricing-5-architecture-lessons-you-can-steal-194d795eae83

https://programmingappliedai.substack.com/p/designing-a-surge-pricing-system



### System Overview and Requirements
Designing a surge pricing system requires a real-time streaming engine capable of balancing supply and demand across specific geographic areas.

**Functional Requirements (FR)**
*   **Geospatial Tracking:** The system must continuously track ride requests and driver availability within specific zones. Users are typically grouped by **geohash** (6-7 characters) to achieve a resolution of roughly **1 km²**.
*   **Real-time Metrics:** Request counts are maintained using **sliding windows** of 1–5 minutes. Driver availability is monitored by detecting status updates (free or busy) via a continuous stream.
*   **Surge Logic:** The system calculates a **demand/supply ratio** for each zone. Surge pricing is triggered when this ratio exceeds a predefined threshold, such as **2:1**.
*   **Dynamic Adjustments:** Zones can be adjusted dynamically based on city activity or density. Additionally, the system must ensure surge pricing **decays smoothly** rather than dropping sharply when demand falls.
*   **Downstream Communication:** Surge updates are emitted as events to downstream pricing engines and user applications.

**Non-Functional Requirements (NFR)**
*   **Low Latency:** Surge multiplier updates must be calculated and visible to users within **less than 1-2 seconds**.
*   **High Availability:** The system requires **99.99% uptime** because pricing is critical to both revenue and user experience.
*   **Scalability:** The architecture must **scale horizontally** to support millions of drivers and users concurrently.

### Technical Architecture and Data Storage
The system utilizes a multi-tier storage strategy to balance speed and durability.

*   **In-Memory Storage (Redis or RocksDB):** Used for **fast access** to real-time surge states. It stores key-value pairs—such as `surge:zone:{zone_id}`—containing current multipliers, demand/supply counts, and timestamps.
*   **Durable Storage (Cassandra or PostgreSQL):** This layer is dedicated to **surge history and auditing**, allowing for long-term data retention and analysis.
*   **Configuration Store (MySQL or PostgreSQL):** A relational database is used to store **administrative thresholds** and system metadata.
* 