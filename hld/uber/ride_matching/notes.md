https://www.youtube.com/watch?v=twUz_hWw2T8

https://www.youtube.com/watch?v=6K6ihHNkO_0

https://www.youtube.com/watch?v=lsKU38RKQSo

These notes synthesize the system design for a ride-sharing application like Uber or Lyft, focusing on scalability, proximity search, and consistency, based on the provided sources.

### **I. System Requirements**

#### **Functional Requirements (Core Features)**
*   **Rider Actions:** Input start and destination locations to receive **estimated fairs** and ETAs. Request a ride based on those estimates.
*   **Driver Actions:** Accept or deny ride requests in real-time. Update status and navigate to pickup/drop-off points.
*   **Shared Features:** Real-time tracking of both parties during a trip. Providing ratings and processing payments at the end of a ride.

#### **Non-Functional Requirements (System Qualities)**
*   **Scalability:** Must handle millions of users and drivers, especially during high-throughput surges (e.g., post-concerts or New Year's Eve).
*   **Low Latency:** Matching must occur quickly, ideally in **less than one minute**.
*   **Consistency vs. Availability:**
    *   **High Availability** is required for the general user experience (searching for rides).
    *   **Strong Consistency** is critical for **matching** to ensure a driver is not assigned multiple rides simultaneously and a ride is not assigned to multiple drivers.

---

### **II. Core Entities and API Design**

#### **Core Entities**
*   **Ride:** Contains ID, rider ID, fair, ETA, source, destination, and status (e.g., requested, matched, in-ride).
*   **Driver:** Includes ID, metadata (car, license plate), rating, and status (available, offline, in-ride).
*   **Location:** Persists the most recent latitude and longitude for active drivers.

#### **Primary APIs**
*   **`POST /fair-estimate`**: Takes source/destination; returns an estimate ID, price, and ETA.
*   **`PATCH /request-ride`**: Takes a ride/estimate ID; triggers the asynchronous matching process.
*   **`PATCH /driver-accept`**: Allows a driver to accept or deny a ride request based on a request ID.
*   **`WEBSOCKET /location-update`**: Periodically sends a driver's current coordinates to the server.

---

### **III. High-Level Architecture**

The system employs a **microservices architecture** to allow independent scaling:
*   **API Gateway/Load Balancer:** Handles authentication (JWT/Session tokens), rate limiting, and routes traffic to specific services.
*   **Ride Service:** Manages fair calculations by calling third-party mapping APIs (Google/Apple Maps) for distance and ETA data.
*   **Driver Matching Service:** The core "brain" that identifies nearby available drivers using proximity search.
*   **Location Update Service:** A WebSocket server designed to handle the high-frequency stream of GPS updates from millions of drivers.
*   **Notification Service:** Uses Push Notifications (FCM for Android, APNs for iOS) to alert drivers of new requests.

---

### **IV. Proximity Search Strategies**

The most critical technical challenge is identifying drivers near a rider efficiently. The sources compare four main approaches:

| Strategy | Mechanism | Pros/Cons | Best For |
| :--- | :--- | :--- | :--- |
| **Quad Tree** | Recursively splits a 2D map into four quadrants. | Good for uneven density (Yelp); **expensive reindexing** makes it bad for high-frequency updates. | Static locations (restaurants). |
| **Geohashing** | Encodes a grid cell into a base-32 string; nearby locations share string prefixes. | **Fast updates** (simple string change); supports high TPS; no complex tree maintenance. | **Ride-sharing** (moving drivers). |
| **PostGIS (SQL)** | A Postgres extension for spatial queries. | Easy to implement; lacks the throughput (TPS) needed for massive scale. | Smaller scale applications. |
| **Elasticsearch** | Built-in geospatial indexing. | Powerful for combined text/location searches; might be overkill for simple proximity. | Search with filters (e.g., "Sushi" + Location). |

**Recommendation:** For a system like Uber, use **Redis with Geohashing**. Redis can handle the massive throughput (600k+ updates per second), and geohashing allows for rapid proximity queries without heavy reindexing.

---

### **V. Critical Deep Dives**

#### **1. Achieving Consistent Matching (The "Double Match" Problem)**
To prevent multiple drivers from being pinged for the same ride or vice versa, the system must use a **Distributed Lock**:
*   **Zookeeper Approach:** Create an **ephemeral node** with the driver ID. If another service tries to create the same node, it receives a "node exists" exception. If the service crashes, the ephemeral node is deleted automatically, releasing the lock.
*   **Redis Approach:** Set a key for the driver ID with a short **Time-to-Live (TTL)** (e.g., 5-10 seconds). This ensures the driver is only "locked" for the duration they have to respond to the notification.

#### **2. Handling High Throughput and Surges**
*   **Request Queuing:** Introduce a **Ride Request Queue** (e.g., Kafka) to buffer incoming requests during surges. This prevents the matching service from being overwhelmed and ensures requests are eventually processed.
*   **Dynamic Location Updates:** To reduce server load, clients can adaptively send updates. For example, if a driver is stationary or offline, the update frequency can drop from every 5 seconds to every 30+ seconds.

#### **3. Surge Pricing Logic**
Surge pricing is handled by a **Surge Calculator Service** that monitors a **Ride Request DB**. By analyzing the density of requests vs. available drivers in a specific geohash area, the service calculates a multiplier (1.5x, 2x) applied to the base fair.