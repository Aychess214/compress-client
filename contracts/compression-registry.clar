;; compression-registry.clar
;; Decentralized Client Compression Coordination Registry
;; This contract manages client compression resources, enabling efficient
;; decentralized resource allocation and utilization tracking.

;; ========== Error Constants ==========
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-CLIENT-ALREADY-REGISTERED (err u201))
(define-constant ERR-CLIENT-NOT-REGISTERED (err u202))
(define-constant ERR-INVALID-ALLOCATION (err u203))
(define-constant ERR-INSUFFICIENT-CAPACITY (err u204))
(define-constant ERR-ALREADY-ALLOCATED (err u205))

;; ========== Data Space Definitions ==========
;; Contract governance
(define-data-var contract-admin principal tx-sender)

;; Client registry with compression capabilities
(define-map client-registry
  {
    client-id: principal,
  }
  {
    max-compression-capacity: uint,
    current-allocation: uint,
    registered-at: uint,
    active: bool,
  }
)

;; Compression session tracking
(define-map compression-sessions
  {
    session-id: uint,
  }
  {
    client: principal,
    start-time: uint,
    allocated-capacity: uint,
    status: (string-ascii 20), ;; e.g., "PENDING", "ACTIVE", "COMPLETED"
  }
)

;; Tracking total system metrics
(define-data-var total-registered-clients uint u0)
(define-data-var total-compression-sessions uint u0)
(define-data-var cumulative-compressed-data uint u0)

;; ========== Private Functions ==========
(define-private (is-contract-admin)
  (is-eq tx-sender (var-get contract-admin))
)

(define-private (validate-client-allocation 
    (current-allocation uint)
    (requested-allocation uint)
    (max-capacity uint)
  )
  (and 
    (<= (+ current-allocation requested-allocation) max-capacity)
    (> requested-allocation u0)
  )
)

;; ========== Read-Only Functions ==========
(define-read-only (get-client-details (client principal))
  (map-get? client-registry { client-id: client })
)

(define-read-only (get-session-details (session-id uint))
  (map-get? compression-sessions { session-id: session-id })
)

(define-read-only (get-system-metrics)
  {
    total-clients: (var-get total-registered-clients),
    total-sessions: (var-get total-compression-sessions),
    total-compressed-data: (var-get cumulative-compressed-data),
  }
)

;; ========== Public Functions ==========
;; Administrative Functions
(define-public (transfer-admin-rights (new-admin principal))
  (begin
    (asserts! (is-contract-admin) ERR-NOT-AUTHORIZED)
    (var-set contract-admin new-admin)
    (ok true)
  )
)

;; Client Registration
(define-public (register-compression-client 
    (client principal)
    (max-compression-capacity uint)
  )
  (begin
    (asserts! (is-contract-admin) ERR-NOT-AUTHORIZED)
    (asserts! 
      (is-none (map-get? client-registry { client-id: client }))
      ERR-CLIENT-ALREADY-REGISTERED
    )
    (map-set client-registry 
      { client-id: client }
      {
        max-compression-capacity: max-compression-capacity,
        current-allocation: u0,
        registered-at: block-height,
        active: true,
      }
    )
    (var-set total-registered-clients 
      (+ (var-get total-registered-clients) u1)
    )
    (ok true)
  )
)

;; Allocate Compression Resources
(define-public (allocate-compression-session
    (client principal)
    (requested-allocation uint)
  )
  (let (
    (client-data (unwrap! 
      (map-get? client-registry { client-id: client })
      ERR-CLIENT-NOT-REGISTERED
    ))
    (session-id (var-get total-compression-sessions))
  )
    (asserts! (get active client-data) ERR-CLIENT-NOT-REGISTERED)
    (asserts! 
      (validate-client-allocation 
        (get current-allocation client-data)
        requested-allocation
        (get max-compression-capacity client-data)
      )
      ERR-INSUFFICIENT-CAPACITY
    )
    
    ;; Update client registry
    (map-set client-registry 
      { client-id: client }
      (merge client-data {
        current-allocation: (+ 
          (get current-allocation client-data) 
          requested-allocation
        )
      })
    )
    
    ;; Create compression session
    (map-set compression-sessions 
      { session-id: session-id }
      {
        client: client,
        start-time: block-height,
        allocated-capacity: requested-allocation,
        status: "ACTIVE",
      }
    )
    
    ;; Update system metrics
    (var-set total-compression-sessions 
      (+ session-id u1)
    )
    
    (ok session-id)
  )
)

;; Complete Compression Session
(define-public (complete-compression-session
    (session-id uint)
    (compressed-data-size uint)
  )
  (let (
    (session-data (unwrap! 
      (map-get? compression-sessions { session-id: session-id })
      ERR-CLIENT-NOT-REGISTERED
    ))
    (client-data (unwrap! 
      (map-get? client-registry { client-id: (get client session-data) })
      ERR-CLIENT-NOT-REGISTERED
    ))
  )
    (asserts! 
      (is-eq (get status session-data) "ACTIVE")
      ERR-INVALID-ALLOCATION
    )
    
    ;; Update compression session
    (map-set compression-sessions 
      { session-id: session-id }
      (merge session-data {
        status: "COMPLETED"
      })
    )
    
    ;; Update client registry
    (map-set client-registry 
      { client-id: (get client session-data) }
      (merge client-data {
        current-allocation: (- 
          (get current-allocation client-data) 
          (get allocated-capacity session-data)
        )
      })
    )
    
    ;; Update system metrics
    (var-set cumulative-compressed-data 
      (+ (var-get cumulative-compressed-data) compressed-data-size)
    )
    
    (ok true)
  )
)