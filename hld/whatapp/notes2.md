https://www.youtube.com/watch?v=3HXFy_7M12E
- Recap starets at 1:12:00


This system design for a chat application like **WhatsApp** or **Facebook Messenger** focuses on supporting real-time communication at a massive scale.

### **1. Requirements Gathering**
The design is built around specific functional and non-functional goals:
*   **Functional Requirements:**
    *   User registration and sign-in (via phone number or email).
    *   Support for **one-to-one** and **group messaging**.
    *   Ability to view **chat history**.
    *   Provision for sending/receiving **media files** (images, videos).
    *   Message status indicators: **Sent, Delivered, and Read receipts**.
*   **Non-Functional Requirements:**
    *   **High Availability:** The system must have negligible downtime, prioritizing availability over high consistency (Eventual Consistency) as per the CAP theorem.
    *   **Low Latency:** Messages should ideally be delivered within **300 milliseconds**.
    *   **High Reliability:** The system must ensure **zero message loss**.
    *   **Scale:** Designed for **1 billion users** sending **100 billion messages per day**, resulting in approximately **1 TB of data daily**.

---

### **2. API Design**
The application uses a mix of **REST endpoints** for management and **WebSockets** for real-time communication:
*   **User Management:** `POST /register` to onboard users with metadata like name and phone number.
*   **Group Management:** Endpoints to create groups, add members, or remove members.
*   **Chat History:** `GET /messages` using **lazy loading/pagination** to fetch previous conversations.
*   **Real-time Messaging:** Handled via **WebSockets (WS)** rather than HTTP to support full-duplex, near-instantaneous communication.

---

### **3. Communication Protocol: Why WebSockets?**
The source compares several protocols before selecting WebSockets for the chat service:
*   **HTTP:** Inefficient for real-time chat because it is unidirectional and requires repeated "get" calls to check for new messages.
*   **Long Polling:** Holds a connection open for a period, but multiple requests are still needed, which is not sustainable for billions of users.
*   **Server-Sent Events (SSE):** Unidirectional (server to client only); would still require separate HTTP calls to send messages.
*   **WebSockets:** Chosen because they are **full duplex**, meaning the server and client can send/receive data simultaneously over a single persistent connection.

---

### **4. High-Level Architecture & Core Entities**
*   **Load Balancer/Gateway:** Distributes traffic and handles authentication, rate limiting, and routing.
*   **User Service:** Manages user profiles and status in a relational database like **PostgreSQL**.
*   **Group Service:** Manages group memberships and metadata using a relational database with a mapping table for users and groups.
*   **Chat Service:** The core service managing message flow, connected to a write-optimized **NoSQL database (Cassandra or DynamoDB)** to handle trillions of messages.
*   **Media Storage:** Images and videos are stored in **S3/Blob storage**, with a **CDN** used to reduce latency for geographically distant users.

---

### **5. Deep Dive: Real-time Message Flow**
The system uses several specialized components to ensure messages reach their destination:
*   **WebSocket Registry:** A **Redis cache** that maps active User IDs to their specific WebSocket server connection. This is essential for routing messages to the correct "sticky" connection.
*   **Redis Streams:** Acts as an event-driven streaming platform. It is preferred over Kafka for this use case because it is more lightweight and offers lower latency for real-time chat.
*   **Message Service:** Consumes messages from the Redis stream and persists them into the **Chat DB**.

#### **Group Messaging Logic**
When a user sends a message to a group, the Chat Service queries the **Group Service** for a list of all member IDs. The system then treats the broadcast as a series of individual messages. It checks the **WebSocket Registry** for each member; online members receive the message via their WebSocket, while offline members' messages are stored in the DB and triggered via a **Notification Service** (FCM for Android, APN for iOS).

---

### **6. Specialized Features**
*   **Offline Support:** When a user comes online, a specialized **Message Service** fetches all "unsend" messages from the Chat DB and delivers them via the new WebSocket connection.
*   **User Status (Online/Last Seen):** Presence is tracked via the WebSocket Registry. If a connection times out (TTL expires), the **User Management Service** updates the user's "last seen" status in the relational DB via a **CDC pipeline**.
*   **Search Functionality:** An **ElasticSearch** instance indexes messages from the Chat DB, allowing users to search history by keyword.
*   **Media Handling:** Instead of sending raw files through WebSockets, the client uploads media via a REST API to S3. The service returns a **URL**, which is then sent as a standard text message through the WebSocket.
* 