https://www.youtube.com/watch?v=I9-PUPYZyiw&list=PLrtCHHeadkHp92TyPt1Fj452_VGLipJnL&index=13

### **System Design Requirements**

*   **Functional Requirements:** The system must allow users to **create, view, and delete conversations**. Users interact with a bot by sending text-based messages and receiving answers. A feedback mechanism (thumbs up/down) is included to evaluate response quality and help train the underlying model.
*   **Non-Functional Requirements:**
    *   **Latency:** A response time of up to **5 seconds** is considered acceptable for the MVP due to the intensive processing required.
    *   **Scalability:** The architecture must support approximately **10 million daily users** sending an average of 20 messages (5 conversations with 4 questions each), totaling **200 million messages per day**.
    *   **Storage:** Based on the estimated message volume, the system needs to store roughly **7.3 TB of data per year**, or 73 TB over 10 years.
    *   **Security:** Standard login flows, **rate limiting** to prevent DOS attacks, and mechanisms to handle users sending excessive simultaneous messages are necessary.

### **High-Level Architecture**

*   **Experience Layer:** A layer used for **orchestration** to ensure a consistent user experience across multiple platforms, including iOS, Android, and web.
*   **Conversation Service:** This service manages the core CRUD (Create, Read, Update, Delete) operations for conversations and handles the logic for sending messages.
*   **Sanitization (Profanity API):** Before reaching the core model, inputs are passed through a **machine learning model (e.g., FastText)** to detect and filter out obscene text, insults, or threats.
*   **Chat GPT Service:** The central component that interacts with the core ML model to generate responses to user questions.
*   **Storage Strategy:** A **NoSQL database** (such as DynamoDB or Cassandra) is recommended to handle the massive scale and provide proper sharding capabilities.
*   **Feedback Loop:** Thumbs-down requests can be sent through a **Kafka queue** or background job for offline processing to refine the model without impacting real-time performance.
*   **Risk Model:** A separate ML model used to identify **malicious users** who may be attempting to sabotage the bot's performance through repetitive negative feedback.

### **API and Data Modeling**

*   **REST APIs:** The Conversation Service utilizes several endpoints:
    *   `POST /v1/conversation`: Creates a new conversation with a title.
    *   `GET /v1/conversation/{id}`: Retrieves an ordered list of messages for a specific conversation.
    *   `DELETE /v1/conversation/{id}`: Removes a specific conversation.
    *   `POST /v1/conversation/{id}/message`: Sends a message and returns a unique **Message ID (GUID)**.
*   **Data Structures:**
    *   **Conversation Table:** Maps User IDs to a list of Conversation IDs.
    *   **Message Table:** Stores individual messages with fields for **Message ID, Text, Author** (user or system), and potentially a **Parent ID** to track follow-up questions in a tree-like conversation structure.

### **The Machine Learning Model Architecture**

The core "meat" of the system is built using a multi-stage **Transformer model (GPT)** process:

1.  **Pre-training (Unsupervised):** The model is trained on massive datasets like **Common Crawler**, books, Wikipedia, and code. Rather than answering questions directly at this stage, it learns to **predict natural sequences of words**.
2.  **Selection Strategies:** To avoid repetitive or "greedy" responses, strategies like **Top-K, nucleus sampling, or temperature** are used to randomly pick from the most probable next words, explaining why the bot may give different answers to the same question.
3.  **Supervised Fine-Tuning (SFT):** The pre-trained model is further trained on a curated dataset of **question-and-answer pairs** to teach it how to respond to queries in a helpful format.
4.  **Reward Model:** Human annotators rate various model-generated answers on a **Likert scale (e.g., 1-7)**. This creates a scalar value representing the quality, tone, and appropriateness of a response.
5.  **Reinforcement Learning (PPO):** Using **Proximal Policy Optimization (PPO)**, the model continuously learns by taking a question, generating a response, and receiving a "reward" from the reward model. This iterative process allows the system to reach high accuracy even if the initial labeled dataset was limited.