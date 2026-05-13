https://www.youtube.com/watch?v=7EnqCwQOddY

The following detailed notes are based on the system design for a **PCI-compliant payment gateway**, outlining its architecture, core components, and operational flow.

### **1. Key Definitions & Concepts**
*   **Payment Gateway:** An orchestration engine that collects, secures, and tokenizes payment details from users, acting as a "traffic controller" for payments.
*   **Payment Processor:** A financial network entity that moves money by communicating directly with banks and card networks to authorize and settle transactions.
*   **PCI DSS Compliance:** A global security standard for entities that store, process, or transmit cardholder data.

### **2. System Requirements**
#### **Functional Requirements**
*   **Payment Intent:** Clients must be able to initiate a payment intent.
*   **Temporary Session Page:** The system must provide a secure checkout page for users to enter card details.
*   **PCI Compliance:** All sensitive data must be handled according to global security standards.
*   **Transaction Status:** Clients should receive the status of their transactions.

#### **Non-Functional Requirements**
*   **Scale:** Designed to handle **10,000 transactions per second (TPS)**.
*   **Consistency:** Prioritized over availability in the CAP theorem due to the financial nature of the system.
*   **Latency:** Authorization should be completed within **200 milliseconds**.
*   **Security:** Must maintain a secure ecosystem (PCI DSS compliant) using encryption and hardware security.

### **3. Core Entities**
*   **Merchant/Client:** Businesses (e.g., Amazon, Flipkart) that integrate the gateway.
*   **Transaction:** The record of the actual payment event.
*   **Payment Method:** The specific type (e.g., Visa, Mastercard).
*   **User/Customer:** The individual providing payment details.
*   **Webhook:** Used to send success/failure notifications to the client.
*   **Payment Session:** A critical, short-lived environment for managing the transaction.

### **4. API Design and Flow**
The system follows a three-step process to initiate and complete a payment:
1.  **Payment Intent API:** Triggered when a user clicks "buy." The gateway stores metadata and returns a `payment_intent_id`.
2.  **Payment Session API:** The client requests a session using the intent ID. The gateway returns a **redirect URL** for a secure checkout page.
3.  **Pay Request API:** Triggered when the user submits card details on the secure page. The gateway tokenizes the data and contacts the processor.

### **5. System Architecture (Deep Dive)**
#### **A. Ingress & Session Management**
*   **API Gateway & Load Balancer:** Handles authentication, authorization, and uniform traffic routing.
*   **Payment Intent Service:** Uses **PostgreSQL** to capture metadata (amount, currency, merchant ID, etc.) for high consistency.
*   **Checkout Session Service:** Manages short-lived sessions (approx. 10 minutes) stored in a **Redis Cache** for low latency.

#### **B. The PCI Zone (Security)**
To remain compliant, sensitive data enters a secure "PCI Zone":
*   **Checkout Frontend Service:** A separate service that hosts the actual HTML page where users enter card details, ensuring the merchant never sees the sensitive data.
*   **Tokenization Service:** Validates the card and creates a **fingerprint** (hashing the BIN, last 4 digits, expiration date, and name).
*   **Hardware Security Module (HSM):** A hardware-based module used to encrypt the card data/fingerprint securely.
*   **TLS Connection:** All data transfer within this zone uses secure TLS connections rather than standard HTTP.

#### **C. Orchestration & Processing**
*   **Orchestrator Service:** Checks the **Merchant Preference DB** to decide which external processor (e.g., Razorpay, PayU) to use.
*   **Adapter Pattern:** Used to translate the gateway’s internal data into the specific formats required by different external processors.
*   **Payment Processor DB:** An RDBMS that tracks the lifecycle of the transaction (status marked as "sent," "done," "success," or "failed").

### **6. Post-Processing & Reconciliation**
*   **Callback Service:** Receives asynchronous acknowledgments from external processors.
*   **Event-Driven Communication:** Uses **Kafka** brokers to handle status updates. Topics include immediate callback status and delayed final confirmation status.
*   **Reconcile Service:** Performs a final tally of transaction requests against processor responses (often daily) to update the final **Ledger/Payment Table**.