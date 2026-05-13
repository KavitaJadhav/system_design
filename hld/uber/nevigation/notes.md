https://www.youtube.com/watch?v=HC-3J8ycXFs

These notes synthesize the system design for a ride-sharing application like Uber, primarily based on the breakdown by a former Meta Staff Engineer, supplemented with comparative insights on proximity search and architecture from other sources.

### **I. System Requirements**

#### **Functional Requirements (Core Features)**
*   **Rider Actions:** Input start/destination to get a **fair estimate** and ETA; request a ride based on that estimate.
*   **Driver Actions:** Accept or deny requests; navigate to pickup and drop-off points.
*   **Tracking & Payment:** Real-time tracking for both parties, ratings, and payment processing at trip completion.

#### **Non-Functional Requirements (Qualities)**
*   **Low Latency Matching:** The system should match a driver within **less than one minute** or return a failure.
*   **Strong Consistency for Matching:** Crucial to ensure a **one-to-one mapping** where a ride is only matched to one driver and a driver is not assigned multiple simultaneous rides.
*   **High Availability:** General services (searching, history) must remain available even if the matching component is under heavy load.
*   **High Throughput:** Must handle **massive surges** (e.g., concerts or New Year's Eve) with hundreds of thousands of requests per region.

---

### **II. Core Entities and API Design**

#### **Core Entities**
*   **Ride:** Contains ID, rider ID, fair, ETA, source/destination, and status (e.g., matched, picked up).
*   **Driver/Rider:** Basic metadata (ID, car info, rating) and **status** (available, in-ride, offline).
*   **Location:** Persists the most recent latitude/longitude for active drivers.

#### **Primary APIs**
*   **`POST /fair-estimate`**: Takes source/destination; returns an ID, fair, and ETA.
*   **`PATCH /request-ride`**: Asynchronous call using a `rideID` to trigger matching.
*   **`PATCH /driver-accept`**: Driver accepts or denies a specific `rideID`.
*   **`WEBSOCKET /location-update`**: Continuous stream of GPS coordinates from drivers.
    *   *Security Note:* Use **JWT or Session tokens** in headers rather than passing `userID` in the request body to prevent unauthorized requests.

---

### **III. High-Level Architecture**

*   **API Gateway:** Handles routing, authentication, rate limiting, and SSL termination.
*   **Ride Service:** Calculates fairs by calling **third-party mapping APIs** (Google/Apple Maps) for distance and traffic data.
*   **Driver Matching Service:** The "brain" that identifies nearby available drivers and manages the matching lifecycle.
*   **Location Service:** A dedicated **WebSocket server** to handle the high frequency of driver GPS updates (e.g., every 5 seconds).
*   **Notification Service:** Uses push notifications (FCM for Android, APNs for iOS) to alert drivers of new requests.

---

### **IV. Technical Deep Dives**

#### **1. Proximity Search: Geohashing vs. Quad Trees**
To find drivers near a rider, the system must query a spatial database efficiently.
*   **Quad Trees:** Recursively split the map into quadrants. They are effective for uneven data density but **expensive to reindex** for moving objects.
*   **Geohashing (Recommended):** Encodes a 2D location into a base-32 string. Nearby locations share prefixes.
*   **Storage:** Using **Redis with Geohashing** is optimal because it supports high TPS (up to 600k/sec) and simple string-based updates without complex tree maintenance.

#### **2. Solving the "Double Match" Problem (Consistency)**
To prevent multiple drivers from accepting the same ride, a **Distributed Lock** is required.
*   **Redis/DynamoDB Lock:** Set a key for the `driverID` with a short **Time-to-Live (TTL)** (e.g., 5-10 seconds). This ensures the driver is "locked" while they decide to accept the request.
*   **Zookeeper:** Alternatively, use **ephemeral nodes**. If a matching service tries to create a node for a driver that already exists, it receives an exception, preventing a second request to that driver.

#### **3. Handling Surges and Scalability**
*   **Ride Request Queue:** Introduce a **partitioned Kafka queue** to buffer incoming requests during peak surges. This prevents system crashes and allows the matching service to process requests at its own pace.
*   **Dynamic Updates:** To reduce server load, the client can use **Adaptive Location Updates**. If a driver is stationary or offline, the update frequency decreases from every 5 seconds to much longer intervals.
*   **Regional Sharding:** Deploy the entire stack across different data centers (e.g., US-East, US-West) to increase availability and reduce cross-region latency.