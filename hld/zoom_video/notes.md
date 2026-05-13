https://www.youtube.com/watch?v=G32ThJakeHk

These detailed notes outline the architecture and design considerations for video conferencing and real-time streaming systems, such as Zoom, WhatsApp, or Facebook Video, based on the provided source.

### 1. System Requirements
The system must address both functional and non-functional requirements to ensure a seamless user experience.

*   **Functional Requirements:**
    *   **1-to-1 Calling:** Support for private audio and video calls between two users.
    *   **Group Calling:** Enabling multiple users to join a single session with audio, video, and screen-sharing capabilities.
    *   **Screen Sharing:** Fundamentally similar to video, where the input source is the user's screen recording instead of a camera.
    *   **Recording:** Option to record calls for later viewing, which can be done on the client side or via a dedicated recording service.
*   **Non-Functional Requirements:**
    *   **Low Latency:** This is the most critical requirement. Real-time interaction cannot tolerate the delays (buffering) acceptable in video platforms like YouTube.
    *   **Availability and Reliability:** While important, the system prioritizes **latency** over perfect data reliability. It is better to lose a few video frames than to have the call lag significantly.

### 2. Communication Protocols
Choosing the right protocol is vital for balancing speed and reliability.

*   **TCP (Transmission Control Protocol):** TCP is connection-oriented and ensures every packet is delivered in order. However, if a packet is lost, it stops and retransmits, causing "head-of-line blocking," which leads to unacceptable lag in video calls.
*   **UDP (User Datagram Protocol):** UDP is a "fire and forget" protocol. It does not guarantee delivery or order, but it has much lower overhead and latency. In video calling, losing a tiny fraction of data is preferred over waiting for retransmission.
*   **WebRTC (Web Real-Time Communication):** This is the industry standard for P2P (peer-to-peer) communication. It handles the complexities of audio/video synchronization and network traversal.
*   **WebSockets:** Typically used for signaling (initiating calls, notifying users) rather than the actual video data transfer.

### 3. Connectivity and Network Traversal
Establishing a direct connection between users is difficult because most devices sit behind **NAT (Network Address Translation)** and use private IP addresses.

*   **Public vs. Private IPs:** Your device has a private IP (e.g., 192.168.x.x) within your home network, but the internet sees a public IP assigned by your ISP.
*   **STUN (Session Traversal Utilities for NAT):** A STUN server helps a client discover its own public IP address and port, which it then shares with the other party to try and establish a direct connection.
*   **TURN (Traversal Using Relays around NAT):** If a direct P2P connection fails (e.g., due to strict firewalls), the system falls back to a TURN server. This server acts as an intermediate relay, receiving data from one user and sending it to the other. This is more expensive and adds latency but ensures the call connects.

### 4. Group Calling Architectures
Design changes as the number of participants grows.

*   **Mesh Architecture:** Every participant connects directly to every other participant.
    *   **Pros:** Low server cost.
    *   **Cons:** High bandwidth and CPU usage for clients. For example, in a 4-person call, you must upload your video 3 times and download 3 different streams. This usually fails for groups larger than 5 people.
*   **Media Server (SFU/MCU):** A central **Call Server** or **Media Server** acts as a bridge.
    *   **SFU (Selective Forwarding Unit):** You upload your stream once to the server, and the server forwards it to the others. This saves your upload bandwidth.
    *   **Transcoding:** The server can convert (transcode) a high-definition stream into lower resolutions for participants with poor internet connections.

### 5. High-Level System Components
*   **Signaling Service:** Manages the state of the call, who is in the meeting, and handles the initial "handshake" between users.
*   **User/Friend Service:** Manages user profiles and contact lists to determine who is online and available to be called.
*   **WebSocket Manager:** Maintains persistent connections to clients to push "incoming call" notifications instantly.
*   **Transcoder:** Converts video formats and resolutions in real-time to support various devices and network speeds.

### 6. Real-Time Live Streaming (Massive Scale)
When streaming to millions (e.g., a sports event), the architecture shifts toward distribution rather than bi-directional interaction.

*   **Ingestion:** The source (camera) sends a high-quality stream to a series of **Transporters/Transcoders**.
*   **CDNs (Content Delivery Networks):** To reach millions of users globally with low latency, the system uses CDNs. These are geographically distributed edge servers that cache the video data closer to the end-user.
*   **Adaptive Bitrate Streaming:** Protocols like HLS or DASH allow the player to switch between different quality levels (e.g., 1080p to 360p) automatically based on the user's current internet speed.
