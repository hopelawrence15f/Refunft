;; Emergency Alert System for Refugee Network
;; Enables broadcast of critical alerts to refugee populations

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u300))
(define-constant ERR_NOT_FOUND (err u301))
(define-constant ERR_INVALID_DATA (err u302))
(define-constant ERR_ALERT_EXPIRED (err u303))
(define-constant ERR_ALREADY_ACKNOWLEDGED (err u304))

;; Data variables
(define-data-var last-alert-id uint u0)
(define-data-var alert-retention-blocks uint u144000) ;; ~100 days

;; Emergency alert broadcasters (authorized organizations)
(define-map alert-broadcasters principal bool)

;; Core alert registry
(define-map emergency-alerts uint {
    alert-type: (string-ascii 30), ;; "disaster", "policy", "resources", "security"
    severity: (string-ascii 20), ;; "critical", "high", "medium", "info"
    title: (string-ascii 100),
    message: (string-ascii 500),
    location-filter: (optional (string-ascii 100)), ;; Target specific regions
    expires-at: uint,
    created-by: principal,
    created-at: uint,
    active: bool
})

;; Track which refugees have acknowledged alerts
(define-map alert-acknowledgments { alert-id: uint, token-id: uint } {
    acknowledged-at: uint,
    response-notes: (optional (string-ascii 200))
})

;; Alert statistics for monitoring reach
(define-map alert-statistics uint {
    total-eligible: uint,
    acknowledged-count: uint,
    broadcast-reach: uint,
    effectiveness-score: uint
})

;; User alert preferences and filters
(define-map user-alert-preferences uint {
    receive-disaster: bool,
    receive-policy: bool,
    receive-resources: bool,
    receive-security: bool,
    preferred-language: (string-ascii 10),
    max-severity-filter: (string-ascii 20)
})

;; Read-only functions
(define-read-only (get-emergency-alert (alert-id uint))
    (map-get? emergency-alerts alert-id)
)

(define-read-only (get-alert-acknowledgment (alert-id uint) (token-id uint))
    (map-get? alert-acknowledgments { alert-id: alert-id, token-id: token-id })
)

(define-read-only (get-alert-statistics (alert-id uint))
    (map-get? alert-statistics alert-id)
)

(define-read-only (get-user-preferences (token-id uint))
    (default-to 
        { receive-disaster: true, receive-policy: true, receive-resources: true, 
          receive-security: true, preferred-language: "en", max-severity-filter: "info" }
        (map-get? user-alert-preferences token-id)
    )
)

(define-read-only (is-alert-broadcaster (broadcaster principal))
    (default-to false (map-get? alert-broadcasters broadcaster))
)

;; Check if alert is still active and not expired
(define-read-only (is-alert-active (alert-id uint))
    (match (map-get? emergency-alerts alert-id)
        alert (and (get active alert) (> (get expires-at alert) stacks-block-height))
        false
    )
)

;; Authorization functions
(define-public (add-alert-broadcaster (broadcaster principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (ok (map-set alert-broadcasters broadcaster true))
    )
)

(define-public (remove-alert-broadcaster (broadcaster principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (ok (map-delete alert-broadcasters broadcaster))
    )
)

;; Core alert broadcasting function
(define-public (broadcast-emergency-alert
    (alert-type (string-ascii 30))
    (severity (string-ascii 20))
    (title (string-ascii 100))
    (message (string-ascii 500))
    (location-filter (optional (string-ascii 100)))
    (duration-blocks uint)
)
    (let ((alert-id (+ (var-get last-alert-id) u1)))
        (asserts! (or (is-eq tx-sender CONTRACT_OWNER) 
                     (default-to false (map-get? alert-broadcasters tx-sender))) 
                 ERR_NOT_AUTHORIZED)
        (asserts! (> (len alert-type) u0) ERR_INVALID_DATA)
        (asserts! (> (len severity) u0) ERR_INVALID_DATA)
        (asserts! (> (len title) u0) ERR_INVALID_DATA)
        (asserts! (> (len message) u0) ERR_INVALID_DATA)
        (asserts! (> duration-blocks u0) ERR_INVALID_DATA)
        (asserts! (<= duration-blocks (var-get alert-retention-blocks)) ERR_INVALID_DATA)
        
        ;; Create the alert
        (map-set emergency-alerts alert-id {
            alert-type: alert-type,
            severity: severity,
            title: title,
            message: message,
            location-filter: location-filter,
            expires-at: (+ stacks-block-height duration-blocks),
            created-by: tx-sender,
            created-at: stacks-block-height,
            active: true
        })
        
        ;; Initialize statistics
        (map-set alert-statistics alert-id {
            total-eligible: u0,
            acknowledged-count: u0,
            broadcast-reach: u0,
            effectiveness-score: u0
        })
        
        (var-set last-alert-id alert-id)
        (ok alert-id)
    )
)

;; Refugee acknowledgment of alerts
(define-public (acknowledge-alert 
    (alert-id uint) 
    (token-id uint) 
    (response-notes (optional (string-ascii 200)))
)
    (let (
        (alert (unwrap! (map-get? emergency-alerts alert-id) ERR_NOT_FOUND))
        (existing-ack (map-get? alert-acknowledgments { alert-id: alert-id, token-id: token-id }))
        (current-stats (default-to 
            { total-eligible: u0, acknowledged-count: u0, broadcast-reach: u0, effectiveness-score: u0 }
            (map-get? alert-statistics alert-id)))
    )
        ;; Verify token exists
        (asserts! (is-some (unwrap! (contract-call? .Refunft get-owner token-id) ERR_NOT_FOUND)) ERR_NOT_FOUND)
        (asserts! (get active alert) ERR_ALERT_EXPIRED)
        (asserts! (> (get expires-at alert) stacks-block-height) ERR_ALERT_EXPIRED)
        (asserts! (is-none existing-ack) ERR_ALREADY_ACKNOWLEDGED)
        
        ;; Record acknowledgment
        (map-set alert-acknowledgments { alert-id: alert-id, token-id: token-id } {
            acknowledged-at: stacks-block-height,
            response-notes: response-notes
        })
        
        ;; Update statistics
        (map-set alert-statistics alert-id {
            total-eligible: (get total-eligible current-stats),
            acknowledged-count: (+ (get acknowledged-count current-stats) u1),
            broadcast-reach: (get broadcast-reach current-stats),
            effectiveness-score: (calculate-effectiveness-score alert-id (+ (get acknowledged-count current-stats) u1))
        })
        
        (ok true)
    )
)

;; Update user alert preferences
(define-public (update-alert-preferences
    (token-id uint)
    (disaster bool)
    (policy bool)
    (resources bool)
    (security bool)
    (language (string-ascii 10))
    (max-severity (string-ascii 20))
)
    (begin
        ;; Verify token exists
        (asserts! (is-some (unwrap! (contract-call? .Refunft get-owner token-id) ERR_NOT_FOUND)) ERR_NOT_FOUND)
        (asserts! (> (len language) u0) ERR_INVALID_DATA)
        (asserts! (> (len max-severity) u0) ERR_INVALID_DATA)
        
        (map-set user-alert-preferences token-id {
            receive-disaster: disaster,
            receive-policy: policy,
            receive-resources: resources,
            receive-security: security,
            preferred-language: language,
            max-severity-filter: max-severity
        })
        
        (ok true)
    )
)

;; Deactivate alert (for cancellation or correction)
(define-public (deactivate-alert (alert-id uint))
    (let ((alert (unwrap! (map-get? emergency-alerts alert-id) ERR_NOT_FOUND)))
        (asserts! (or (is-eq tx-sender CONTRACT_OWNER) 
                     (is-eq tx-sender (get created-by alert))) 
                 ERR_NOT_AUTHORIZED)
        
        (map-set emergency-alerts alert-id (merge alert { active: false }))
        (ok true)
    )
)

;; Helper function to calculate effectiveness score
(define-private (calculate-effectiveness-score (alert-id uint) (ack-count uint))
    (let (
        (stats (unwrap! (map-get? alert-statistics alert-id) u0))
        (eligible (get total-eligible stats))
    )
        (if (> eligible u0)
            (/ (* ack-count u100) eligible)
            u0
        )
    )
)

;; Get active alerts for a specific location
(define-read-only (get-active-alerts-for-location (location (string-ascii 100)))
    (let ((alert-id (var-get last-alert-id)))
        ;; Simplified - would iterate through alerts in full implementation
        (ok (list))
    )
)

;; Get alerts by type and severity
(define-read-only (get-alerts-by-criteria (alert-type (string-ascii 30)) (min-severity (string-ascii 20)))
    ;; Simplified - would filter alerts in full implementation
    (ok (list))
)

;; Get user's unacknowledged alerts count
(define-read-only (get-unacknowledged-count (token-id uint))
    ;; Simplified - would count unacknowledged alerts in full implementation
    (ok u0)
)

;; Emergency override to broadcast system-wide critical alerts
(define-public (broadcast-critical-system-alert 
    (title (string-ascii 100)) 
    (message (string-ascii 500))
    (duration-blocks uint)
)
    (let ((alert-id (+ (var-get last-alert-id) u1)))
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (> (len title) u0) ERR_INVALID_DATA)
        (asserts! (> (len message) u0) ERR_INVALID_DATA)
        
        (map-set emergency-alerts alert-id {
            alert-type: "system",
            severity: "critical",
            title: title,
            message: message,
            location-filter: none,
            expires-at: (+ stacks-block-height duration-blocks),
            created-by: tx-sender,
            created-at: stacks-block-height,
            active: true
        })
        
        (map-set alert-statistics alert-id {
            total-eligible: u999999, ;; System-wide
            acknowledged-count: u0,
            broadcast-reach: u999999,
            effectiveness-score: u0
        })
        
        (var-set last-alert-id alert-id)
        (ok alert-id)
    )
)

;; Get system status and alert overview
(define-read-only (get-alert-system-status)
    (ok {
        total-alerts: (var-get last-alert-id),
        retention-period: (var-get alert-retention-blocks),
        active-broadcasters: u0, ;; Would count in full implementation
        system-health: u100
    })
)

;; Initialize contract owner as broadcaster
(map-set alert-broadcasters CONTRACT_OWNER true)
