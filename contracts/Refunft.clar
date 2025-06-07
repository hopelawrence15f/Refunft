(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_DATA (err u103))
(define-constant ERR_NOT_OWNER (err u104))
(define-constant ERR_TRANSFER_DISABLED (err u105))

(define-non-fungible-token refugee-id uint)

(define-data-var last-token-id uint u0)
(define-data-var contract-paused bool false)

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

(map-set authorized-issuers CONTRACT_OWNER true)