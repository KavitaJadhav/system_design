https://www.youtube.com/watch?v=cr6p0n0N-VA&list=PL5q3E8eRUieWtYLmRU3z94-vGRcwKr9tM&index=7

These detailed notes summarize the system design for a WhatsApp-like messaging application, following the structured "delivery framework" used for software engineering interviews.

### 1. Requirements Gathering
To design a messaging system effectively, one must establish clear functional and non-functional requirements within the first few minutes.

*   **Functional Requirements:**
    *   **Chat Creation:** Users must be able to start one-to-one and group chats.
    *   **Messaging:** Users must be able to send and receive messages within those chats.
    *   **Media Attachments:** The system must support sending audio, video, and images.
    *   **Offline Access:** Messages must be accessible even after a device has been offline; the system should deliver missed messages once the device reconnects.
*   **Non-Functional Requirements:**
    *   **Low Latency:** Delivery should feel instantaneous, ideally within **500 milliseconds**.
    *   **Guaranteed Delivery:** The system must ensure that sent messages eventually reach the recipient.
    *   **High Scale:** The architecture must handle billions of users and high throughput.
    *   **Minimal Retention:** To protect privacy and reduce liability, messages should not be stored on the server longer than necessary.
    *   **Fault Tolerance:** The system should remain operational even if individual components fail.

### 2. Core Entities
Defining the "nouns" of the system helps structure the data model and API.
*   **Users/Actors:** All users are peers in the network; there are no privileged roles like "driver" or "viewer".
*   **Chat:** Metadata for a conversation (ID, name, etc.).
*   **Message:** The content, sender ID, and timestamp.
*   **Client/Device:** Crucial for tracking message delivery since a user might have multiple devices (e.g., phone and laptop).
*   **Chat Participant:** A mapping of which users belong to which chats.

### 3. Connectivity and API
*   **Technology:** The system should use **Websockets** for persistent, bidirectional communication between the client and server. This is necessary because RESTful APIs do not allow the server to "push" messages to the client.
*   **Client-to-Server Commands:** `createChat`, `sendMessage`, `createAttachment`, and `modifyParticipants`.
*   **Server-to-Client Commands:** `newMessage` notifications and `chatUpdate` (for changes in participants or new chats).

### 4. High-Level Design (HLD)
The initial design uses a simple setup that is progressively evolved to handle scale.
*   **Database:** **DynamoDB** (or a similar Key-Value store) is recommended for its scalability.
    *   **ChatParticipant Table:** Uses a **Composite Primary Key** (Chat ID) for finding participants in a chat, and a **Global Secondary Index (GSI)** (Participant ID) to find all chats a user belongs to.
*   **Media Handling:** Do not pass large binary blobs (videos/photos) through the chat server. Instead, use **S3** with **pre-signed URLs**. The client requests an upload URL from the server, uploads directly to S3, and then sends the URL as a message.

### 5. Managing Offline Delivery & Durability
To guarantee delivery even if a user is offline:
1.  **Storage:** Messages are stored in a `Messages` table.
2.  **Inbox Pattern:** An `Inbox` table tracks undelivered messages per recipient.
3.  **Flow:** When a message is sent, the server writes it to the database and creates an entry in the `Inbox` for every participant.
4.  **Acknowledgement (ACK):** When a client receives a message, it sends an "ACK" back to the server, which then deletes that message from the `Inbox`.
5.  **Syncing:** When a client reconnects after being offline, the server queries the `Inbox` to deliver all missed messages.

### 6. Scaling to Billions of Users
A single chat server cannot handle billions of users; the system must scale horizontally.
*   **Load Balancing:** Use a **Layer 4 (L4) load balancer** with a **"least connections"** strategy to manage persistent TCP/Websocket connections.
*   **Routing Problem:** If User A is on Server 1 and User B is on Server 2, they cannot communicate directly.
*   **Pub/Sub Solution:** Use **Redis Pub/Sub** as a lightweight notification layer.
    *   Each chat server subscribes to the user IDs of its currently connected clients in Redis.
    *   When a message arrives for a user, the receiving server publishes a notification to that user's topic in Redis, which then routes it to the correct chat server.
*   **Consistency:** While Redis Pub/Sub provides "at-most-once" delivery, the database and `Inbox` pattern serve as the reliable fallback for guaranteed delivery.

### 7. Data Privacy and Storage
*   **Cleanup Service:** A background process should delete messages from the database after 30 days or once they have been delivered to all recipients.
*   **Storage Estimate:** For 1 billion users sending 100 messages a day, the system would process roughly **100 terabytes of data daily**.

### 8. Feature Extensions
*   **Multi-Device Support:** The system must be updated to key the `Inbox` and Pub/Sub topics by `ClientID` rather than `UserID` so that messages are delivered to every registered device.
*   **Presence Indicators:** To show if a user is online, the chat server can update an `Available` status table whenever a websocket connection is established or terminated.

### 9. Interview Expectations by Level
*   **Mid-Level:** Focus on basic Websocket management, database design, and calling out scaling challenges.
*   **Senior:** Expected to understand Layer 4 load balancing, consistent hashing, and how to scale stateful services.
*   **Staff:** Must zoom in on the "hard parts," such as the statefulness of servers and optimizing the data model for extreme throughput.