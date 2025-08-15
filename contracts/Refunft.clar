(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_DATA (err u103))
(define-constant ERR_NOT_OWNER (err u104))
(define-constant ERR_TRANSFER_DISABLED (err u105))
(define-constant ERR_SERVICE_NOT_FOUND (err u106))
(define-constant ERR_ACCESS_DENIED (err u107))
(define-constant ERR_SERVICE_ALREADY_EXISTS (err u108))
(define-constant ERR_INVALID_SERVICE_DATA (err u109))
(define-constant ERR_DOCUMENT_NOT_FOUND (err u110))
(define-constant ERR_DOCUMENT_EXPIRED (err u111))
(define-constant ERR_INVALID_DOCUMENT_DATA (err u112))

(define-non-fungible-token refugee-id uint)

(define-data-var last-token-id uint u0)
(define-data-var contract-paused bool false)
(define-data-var last-service-id uint u0)
(define-data-var last-access-id uint u0)
(define-data-var last-document-id uint u0)

(define-map refugee-profiles
  uint
  {
    name: (string-ascii 100),
    birth-year: uint,
    country-of-origin: (string-ascii 50),
    displacement-date: uint,
    verification-status: (string-ascii 20),
    issuing-authority: (string-ascii 100),
    emergency-contact: (string-ascii 200),
    medical-info: (string-ascii 500),
    created-at: uint
  }
)

(define-map authorized-issuers principal bool)

(define-map token-metadata
  uint
  {
    token-uri: (optional (string-utf8 256)),
    last-updated: uint
  }
)

(define-map profile-updates
  uint
  {
    update-count: uint,
    last-update-by: principal,
    last-update-at: uint
  }
)

(define-map service-registry
  uint
  {
    service-name: (string-ascii 100),
    service-type: (string-ascii 50),
    provider-name: (string-ascii 100),
    provider-contact: (string-ascii 200),
    service-description: (string-ascii 500),
    location: (string-ascii 100),
    is-active: bool,
    created-by: principal,
    created-at: uint,
    last-updated: uint
  }
)

(define-map service-access-records
  uint
  {
    token-id: uint,
    service-id: uint,
    access-type: (string-ascii 50),
    access-duration: uint,
    access-date: uint,
    notes: (string-ascii 500),
    verified-by: principal,
    access-location: (string-ascii 100),
    follow-up-required: bool,
    created-at: uint
  }
)

(define-map service-providers principal bool)

(define-map service-statistics
  uint
  {
    total-accesses: uint,
    unique-users: uint,
    last-access-date: uint,
    average-duration: uint,
    total-duration: uint
  }
)

(define-map user-service-history
  {token-id: uint, service-id: uint}
  {
    access-count: uint,
    first-access: uint,
    last-access: uint,
    total-duration: uint,
    last-notes: (string-ascii 500)
  }
)

;; Document attachment system
(define-map document-registry
  uint
  {
    token-id: uint,
    document-type: (string-ascii 50),
    document-name: (string-ascii 100),
    document-hash: (string-ascii 64),
    issuer-name: (string-ascii 100),
    issue-date: uint,
    expiry-date: (optional uint),
    verification-status: (string-ascii 20),
    verified-by: (optional principal),
    verified-at: (optional uint),
    is-sensitive: bool,
    notes: (string-ascii 300),
    uploaded-by: principal,
    created-at: uint
  }
)

(define-map document-verifiers principal bool)

(define-map token-documents
  uint
  {
    document-count: uint,
    verified-count: uint,
    expired-count: uint,
    last-document-added: uint
  }
)

(define-map document-access-log
  uint
  {
    document-id: uint,
    accessed-by: principal,
    access-purpose: (string-ascii 100),
    access-granted: bool,
    accessed-at: uint
  }
)

(define-public (add-authorized-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map-set authorized-issuers issuer true))
  )
)

(define-public (remove-authorized-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map-delete authorized-issuers issuer))
  )
)

(define-public (mint-refugee-id 
  (recipient principal)
  (name (string-ascii 100))
  (birth-year uint)
  (country-of-origin (string-ascii 50))
  (displacement-date uint)
  (issuing-authority (string-ascii 100))
  (emergency-contact (string-ascii 200))
  (medical-info (string-ascii 500))
  (token-uri (optional (string-utf8 256)))
)
  (let
    (
      (token-id (+ (var-get last-token-id) u1))
      (is-authorized (default-to false (map-get? authorized-issuers tx-sender)))
    )
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) is-authorized) ERR_NOT_AUTHORIZED)
    (asserts! (> (len name) u0) ERR_INVALID_DATA)
    (asserts! (> birth-year u1900) ERR_INVALID_DATA)
    (asserts! (> (len country-of-origin) u0) ERR_INVALID_DATA)
    
    (try! (nft-mint? refugee-id token-id recipient))
    
    (map-set refugee-profiles token-id {
      name: name,
      birth-year: birth-year,
      country-of-origin: country-of-origin,
      displacement-date: displacement-date,
      verification-status: "pending",
      issuing-authority: issuing-authority,
      emergency-contact: emergency-contact,
      medical-info: medical-info,
      created-at: stacks-block-height
    })
    
    (map-set token-metadata token-id {
      token-uri: token-uri,
      last-updated: stacks-block-height
    })
    
    (map-set profile-updates token-id {
      update-count: u0,
      last-update-by: tx-sender,
      last-update-at: stacks-block-height
    })
    
    (var-set last-token-id token-id)
    (ok token-id)
  )
)

(define-public (update-verification-status (token-id uint) (new-status (string-ascii 20)))
  (let
    (
      (profile (unwrap! (map-get? refugee-profiles token-id) ERR_NOT_FOUND))
      (is-authorized (default-to false (map-get? authorized-issuers tx-sender)))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) is-authorized) ERR_NOT_AUTHORIZED)
    (asserts! (> (len new-status) u0) ERR_INVALID_DATA)
    
    (map-set refugee-profiles token-id (merge profile { verification-status: new-status }))
    (ok true)
  )
)

(define-public (update-emergency-contact (token-id uint) (new-contact (string-ascii 200)))
  (let
    (
      (profile (unwrap! (map-get? refugee-profiles token-id) ERR_NOT_FOUND))
      (token-owner (unwrap! (nft-get-owner? refugee-id token-id) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender token-owner) ERR_NOT_OWNER)
    (asserts! (> (len new-contact) u0) ERR_INVALID_DATA)
    
    (map-set refugee-profiles token-id (merge profile { emergency-contact: new-contact }))
    (increment-update-counter token-id)
    (ok true)
  )
)

(define-public (update-medical-info (token-id uint) (new-medical-info (string-ascii 500)))
  (let
    (
      (profile (unwrap! (map-get? refugee-profiles token-id) ERR_NOT_FOUND))
      (token-owner (unwrap! (nft-get-owner? refugee-id token-id) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender token-owner) ERR_NOT_OWNER)
    
    (map-set refugee-profiles token-id (merge profile { medical-info: new-medical-info }))
    (increment-update-counter token-id)
    (ok true)
  )
)

(define-public (set-token-uri (token-id uint) (new-uri (string-utf8 256)))
  (let
    (
      (metadata (unwrap! (map-get? token-metadata token-id) ERR_NOT_FOUND))
      (token-owner (unwrap! (nft-get-owner? refugee-id token-id) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender token-owner) ERR_NOT_OWNER)
    
    (map-set token-metadata token-id (merge metadata { 
      token-uri: (some new-uri),
      last-updated: stacks-block-height 
    }))
    (ok true)
  )
)

(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set contract-paused true)
    (ok true)
  )
)

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set contract-paused false)
    (ok true)
  )
)

(define-public (add-service-provider (provider principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map-set service-providers provider true))
  )
)

(define-public (remove-service-provider (provider principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map-delete service-providers provider))
  )
)

(define-public (register-service
  (service-name (string-ascii 100))
  (service-type (string-ascii 50))
  (provider-name (string-ascii 100))
  (provider-contact (string-ascii 200))
  (service-description (string-ascii 500))
  (location (string-ascii 100))
)
  (let
    (
      (service-id (+ (var-get last-service-id) u1))
      (is-authorized-provider (default-to false (map-get? service-providers tx-sender)))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) is-authorized-provider) ERR_NOT_AUTHORIZED)
    (asserts! (> (len service-name) u0) ERR_INVALID_SERVICE_DATA)
    (asserts! (> (len service-type) u0) ERR_INVALID_SERVICE_DATA)
    (asserts! (> (len provider-name) u0) ERR_INVALID_SERVICE_DATA)
    
    (map-set service-registry service-id {
      service-name: service-name,
      service-type: service-type,
      provider-name: provider-name,
      provider-contact: provider-contact,
      service-description: service-description,
      location: location,
      is-active: true,
      created-by: tx-sender,
      created-at: stacks-block-height,
      last-updated: stacks-block-height
    })
    
    (map-set service-statistics service-id {
      total-accesses: u0,
      unique-users: u0,
      last-access-date: u0,
      average-duration: u0,
      total-duration: u0
    })
    
    (var-set last-service-id service-id)
    (ok service-id)
  )
)

(define-public (update-service-status (service-id uint) (is-active bool))
  (let
    (
      (service (unwrap! (map-get? service-registry service-id) ERR_SERVICE_NOT_FOUND))
      (is-authorized-provider (default-to false (map-get? service-providers tx-sender)))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) 
                  (and is-authorized-provider (is-eq tx-sender (get created-by service))))
              ERR_NOT_AUTHORIZED)
    
    (map-set service-registry service-id (merge service { 
      is-active: is-active,
      last-updated: stacks-block-height 
    }))
    (ok true)
  )
)

(define-public (record-service-access
  (token-id uint)
  (service-id uint)
  (access-type (string-ascii 50))
  (access-duration uint)
  (notes (string-ascii 500))
  (access-location (string-ascii 100))
  (follow-up-required bool)
)
  (let
    (
      (access-id (+ (var-get last-access-id) u1))
      (token-owner (unwrap! (nft-get-owner? refugee-id token-id) ERR_NOT_FOUND))
      (service (unwrap! (map-get? service-registry service-id) ERR_SERVICE_NOT_FOUND))
      (is-authorized-provider (default-to false (map-get? service-providers tx-sender)))
      (current-stats (default-to 
        {total-accesses: u0, unique-users: u0, last-access-date: u0, average-duration: u0, total-duration: u0}
        (map-get? service-statistics service-id)))
      (user-history-key {token-id: token-id, service-id: service-id})
      (current-user-history (default-to 
        {access-count: u0, first-access: u0, last-access: u0, total-duration: u0, last-notes: ""}
        (map-get? user-service-history user-history-key)))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) is-authorized-provider) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active service) ERR_ACCESS_DENIED)
    (asserts! (> (len access-type) u0) ERR_INVALID_SERVICE_DATA)
    
    (map-set service-access-records access-id {
      token-id: token-id,
      service-id: service-id,
      access-type: access-type,
      access-duration: access-duration,
      access-date: stacks-block-height,
      notes: notes,
      verified-by: tx-sender,
      access-location: access-location,
      follow-up-required: follow-up-required,
      created-at: stacks-block-height
    })
    
    (let
      (
        (is-new-user (is-eq (get access-count current-user-history) u0))
        (new-total-duration (+ (get total-duration current-stats) access-duration))
        (new-total-accesses (+ (get total-accesses current-stats) u1))
        (new-unique-users (if is-new-user (+ (get unique-users current-stats) u1) (get unique-users current-stats)))
        (new-average-duration (if (> new-total-accesses u0) (/ new-total-duration new-total-accesses) u0))
      )
      (map-set service-statistics service-id {
        total-accesses: new-total-accesses,
        unique-users: new-unique-users,
        last-access-date: stacks-block-height,
        average-duration: new-average-duration,
        total-duration: new-total-duration
      })
    )
    
    (map-set user-service-history user-history-key {
      access-count: (+ (get access-count current-user-history) u1),
      first-access: (if (is-eq (get access-count current-user-history) u0) 
                        stacks-block-height 
                        (get first-access current-user-history)),
      last-access: stacks-block-height,
      total-duration: (+ (get total-duration current-user-history) access-duration),
      last-notes: notes
    })
    
    (var-set last-access-id access-id)
    (ok access-id)
  )
)

;; Document management functions
(define-public (add-document-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map-set document-verifiers verifier true))
  )
)

(define-public (remove-document-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map-delete document-verifiers verifier))
  )
)

(define-public (attach-document
  (token-id uint)
  (document-type (string-ascii 50))
  (document-name (string-ascii 100))
  (document-hash (string-ascii 64))
  (issuer-name (string-ascii 100))
  (issue-date uint)
  (expiry-date (optional uint))
  (is-sensitive bool)
  (notes (string-ascii 300))
)
  (let
    (
      (document-id (+ (var-get last-document-id) u1))
      (token-owner (unwrap! (nft-get-owner? refugee-id token-id) ERR_NOT_FOUND))
      (token-docs (default-to {document-count: u0, verified-count: u0, expired-count: u0, last-document-added: u0}
                               (map-get? token-documents token-id)))
    )
    (asserts! (is-eq tx-sender token-owner) ERR_NOT_OWNER)
    (asserts! (> (len document-type) u0) ERR_INVALID_DOCUMENT_DATA)
    (asserts! (> (len document-name) u0) ERR_INVALID_DOCUMENT_DATA)
    (asserts! (> (len document-hash) u0) ERR_INVALID_DOCUMENT_DATA)
    (asserts! (> (len issuer-name) u0) ERR_INVALID_DOCUMENT_DATA)
    (asserts! (> issue-date u0) ERR_INVALID_DOCUMENT_DATA)
    
    (map-set document-registry document-id {
      token-id: token-id,
      document-type: document-type,
      document-name: document-name,
      document-hash: document-hash,
      issuer-name: issuer-name,
      issue-date: issue-date,
      expiry-date: expiry-date,
      verification-status: "pending",
      verified-by: none,
      verified-at: none,
      is-sensitive: is-sensitive,
      notes: notes,
      uploaded-by: tx-sender,
      created-at: stacks-block-height
    })
    
    (map-set token-documents token-id {
      document-count: (+ (get document-count token-docs) u1),
      verified-count: (get verified-count token-docs),
      expired-count: (get expired-count token-docs),
      last-document-added: stacks-block-height
    })
    
    (var-set last-document-id document-id)
    (ok document-id)
  )
)

(define-public (verify-document (document-id uint) (verification-status (string-ascii 20)))
  (let
    (
      (document (unwrap! (map-get? document-registry document-id) ERR_DOCUMENT_NOT_FOUND))
      (is-authorized-verifier (default-to false (map-get? document-verifiers tx-sender)))
      (token-docs (default-to {document-count: u0, verified-count: u0, expired-count: u0, last-document-added: u0}
                               (map-get? token-documents (get token-id document))))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) is-authorized-verifier) ERR_NOT_AUTHORIZED)
    (asserts! (> (len verification-status) u0) ERR_INVALID_DOCUMENT_DATA)
    
    (map-set document-registry document-id (merge document {
      verification-status: verification-status,
      verified-by: (some tx-sender),
      verified-at: (some stacks-block-height)
    }))
    
    (if (is-eq verification-status "verified")
      (map-set token-documents (get token-id document) (merge token-docs {
        verified-count: (+ (get verified-count token-docs) u1)
      }))
      true
    )
    
    (ok true)
  )
)

(define-public (request-document-access 
  (document-id uint) 
  (access-purpose (string-ascii 100))
)
  (let
    (
      (document (unwrap! (map-get? document-registry document-id) ERR_DOCUMENT_NOT_FOUND))
      (token-owner (unwrap! (nft-get-owner? refugee-id (get token-id document)) ERR_NOT_FOUND))
      (is-authorized-verifier (default-to false (map-get? document-verifiers tx-sender)))
      (is-authorized-provider (default-to false (map-get? service-providers tx-sender)))
      (access-granted (or (is-eq tx-sender token-owner) 
                         (and (not (get is-sensitive document)) 
                              (or is-authorized-verifier is-authorized-provider))))
    )
    (asserts! (> (len access-purpose) u0) ERR_INVALID_DOCUMENT_DATA)
    
    (map-set document-access-log document-id {
      document-id: document-id,
      accessed-by: tx-sender,
      access-purpose: access-purpose,
      access-granted: access-granted,
      accessed-at: stacks-block-height
    })
    
    (if access-granted
      (ok document)
      ERR_ACCESS_DENIED
    )
  )
)

(define-public (update-document-expiry (document-id uint) (new-expiry-date (optional uint)))
  (let
    (
      (document (unwrap! (map-get? document-registry document-id) ERR_DOCUMENT_NOT_FOUND))
      (token-owner (unwrap! (nft-get-owner? refugee-id (get token-id document)) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender token-owner) ERR_NOT_OWNER)
    
    (map-set document-registry document-id (merge document {
      expiry-date: new-expiry-date
    }))
    
    (ok true)
  )
)

(define-public (mark-document-expired (document-id uint))
  (let
    (
      (document (unwrap! (map-get? document-registry document-id) ERR_DOCUMENT_NOT_FOUND))
      (is-authorized-verifier (default-to false (map-get? document-verifiers tx-sender)))
      (token-docs (default-to {document-count: u0, verified-count: u0, expired-count: u0, last-document-added: u0}
                               (map-get? token-documents (get token-id document))))
      (current-expiry (get expiry-date document))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) is-authorized-verifier) ERR_NOT_AUTHORIZED)
    (asserts! (is-some current-expiry) ERR_INVALID_DOCUMENT_DATA)
    (asserts! (<= (unwrap-panic current-expiry) stacks-block-height) ERR_INVALID_DOCUMENT_DATA)
    
    (map-set document-registry document-id (merge document {
      verification-status: "expired"
    }))
    
    (map-set token-documents (get token-id document) (merge token-docs {
      expired-count: (+ (get expired-count token-docs) u1)
    }))
    
    (ok true)
  )
)

;; (define-public (transfer (token-id uint) (sender principal) (recipient principal))
;;   (begin
;;     (asserts! false ERR_TRANSFER_DISABLED)
;;   )
;; )

(define-private (increment-update-counter (token-id uint))
  (let
    (
      (current-updates (default-to { update-count: u0, last-update-by: tx-sender, last-update-at: u0 } 
                                  (map-get? profile-updates token-id)))
    )
    (map-set profile-updates token-id {
      update-count: (+ (get update-count current-updates) u1),
      last-update-by: tx-sender,
      last-update-at: stacks-block-height
    })
  )
)

(define-read-only (get-refugee-profile (token-id uint))
  (map-get? refugee-profiles token-id)
)

(define-read-only (get-token-metadata (token-id uint))
  (map-get? token-metadata token-id)
)

(define-read-only (get-profile-updates (token-id uint))
  (map-get? profile-updates token-id)
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? refugee-id token-id))
)

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (is-authorized-issuer (issuer principal))
  (default-to false (map-get? authorized-issuers issuer))
)

(define-read-only (is-contract-paused)
  (var-get contract-paused)
)

(define-read-only (get-token-uri (token-id uint))
  (ok (get token-uri (map-get? token-metadata token-id)))
)

(define-read-only (get-service-info (service-id uint))
  (map-get? service-registry service-id)
)

(define-read-only (get-service-statistics (service-id uint))
  (map-get? service-statistics service-id)
)

(define-read-only (get-service-access-record (access-id uint))
  (map-get? service-access-records access-id)
)

(define-read-only (get-user-service-history (token-id uint) (service-id uint))
  (map-get? user-service-history {token-id: token-id, service-id: service-id})
)

(define-read-only (is-service-provider (provider principal))
  (default-to false (map-get? service-providers provider))
)

(define-read-only (get-last-service-id)
  (ok (var-get last-service-id))
)

(define-read-only (get-last-access-id)
  (ok (var-get last-access-id))
)

(define-read-only (get-service-report (service-id uint))
  (let
    (
      (service (map-get? service-registry service-id))
      (stats (map-get? service-statistics service-id))
    )
    (ok {
      service-info: service,
      statistics: stats
    })
  )
)

(define-read-only (get-user-access-summary (token-id uint))
  (let
    (
      (profile (map-get? refugee-profiles token-id))
      (total-services u0)
    )
    (ok {
      profile: profile,
      total-services-accessed: total-services
    })
  )
)

;; Document read-only functions
(define-read-only (get-document (document-id uint))
  (map-get? document-registry document-id)
)

(define-read-only (get-token-documents-summary (token-id uint))
  (map-get? token-documents token-id)
)

(define-read-only (is-document-verifier (verifier principal))
  (default-to false (map-get? document-verifiers verifier))
)

(define-read-only (get-document-access-log (document-id uint))
  (map-get? document-access-log document-id)
)

(define-read-only (get-last-document-id)
  (ok (var-get last-document-id))
)

(define-read-only (check-document-validity (document-id uint))
  (let
    (
      (document (map-get? document-registry document-id))
    )
    (match document
      doc-data (let
        (
          (expiry (get expiry-date doc-data))
          (is-verified (is-eq (get verification-status doc-data) "verified"))
          (is-expired (match expiry
                        exp-date (<= exp-date stacks-block-height)
                        false))
        )
        (ok {
          exists: true,
          verified: is-verified,
          expired: is-expired,
          status: (get verification-status doc-data)
        })
      )
      (ok {
        exists: false,
        verified: false,
        expired: false,
        status: "not-found"
      })
    )
  )
)

(map-set authorized-issuers CONTRACT_OWNER true)


