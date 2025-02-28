;; Gamified Citizen Science - DACR Project
;; This contract implements a system for crowdsourced ecosystem monitoring
;; where users earn tokens for validating sensor data with AI verification

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-registered (err u101))
(define-constant err-already-registered (err u102))
(define-constant err-invalid-observation (err u103))
(define-constant err-ai-verification-failed (err u104))

;; Define fungible token for rewards
(define-fungible-token citizen-science-token)

;; Define data variables
(define-data-var next-observation-id uint u0)

;; Define data maps
(define-map citizen-scientists
  principal
  { registered: bool, total-rewards: uint }
)

(define-map observations
  uint
  {
    observer: principal,
    biome-id: uint,
    observation-type: (string-ascii 64),
    data: (string-utf8 1024),
    timestamp: uint,
    validated: bool,
    rewards: uint
  }
)

;; Public functions

;; Register as a citizen scientist
(define-public (register-citizen-scientist)
  (let
    ((caller tx-sender))
    (asserts! (is-none (map-get? citizen-scientists caller)) err-already-registered)
    (ok (map-set citizen-scientists caller { registered: true, total-rewards: u0 }))
  )
)

;; Submit an ecosystem observation
(define-public (submit-observation (biome-id uint) (observation-type (string-ascii 64)) (data (string-utf8 1024)))
  (let
    (
      (caller tx-sender)
      (observation-id (var-get next-observation-id))
    )
    (asserts! (is-some (map-get? citizen-scientists caller)) err-not-registered)
    (asserts! (is-valid-observation observation-type data) err-invalid-observation)
    
    (map-set observations observation-id
      {
        observer: caller,
        biome-id: biome-id,
        observation-type: observation-type,
        data: data,
        timestamp: stacks-block-height,
        validated: false,
        rewards: u0
      }
    )
    
    (var-set next-observation-id (+ observation-id u1))
    (ok observation-id)
  )
)

;; Validate an observation (simulating AI verification)
(define-public (validate-observation (observation-id uint))
  (let
    ((observation (unwrap! (map-get? observations observation-id) err-invalid-observation)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (get validated observation)) err-invalid-observation)
    
    (if (ai-verify (get observation-type observation) (get data observation))
      (let
        (
          (reward-amount u10) ;; Arbitrary reward amount, adjust as needed
          (observer (get observer observation))
        )
        (try! (validate-and-reward observation-id reward-amount))
        (try! (ft-mint? citizen-science-token reward-amount observer))
        (ok true)
      )
      err-ai-verification-failed
    )
  )
)

;; Private functions

;; Validate observation and update rewards
(define-private (validate-and-reward (observation-id uint) (reward-amount uint))
  (match (map-get? observations observation-id)
    observation
      (let
        ((observer (get observer observation)))
        (map-set observations observation-id
          (merge observation { validated: true, rewards: reward-amount })
        )
        (match (map-get? citizen-scientists observer)
          scientist-data
            (ok (map-set citizen-scientists
              observer
              (merge scientist-data
                { total-rewards: (+ (get total-rewards scientist-data) reward-amount) }
              )
            ))
          err-not-registered
        )
      )
    err-invalid-observation
  )
)

;; Simulated AI verification function
;; In a real-world scenario, this would call an oracle or off-chain AI service
(define-private (ai-verify (observation-type (string-ascii 64)) (data (string-utf8 1024)))
  ;; Simulate AI verification with a simple check
  ;; In practice, this would be a much more sophisticated process
  (> (len data) u100) ;; Arbitrary condition for demonstration
)

;; Check if an observation is valid
(define-private (is-valid-observation (observation-type (string-ascii 64)) (data (string-utf8 1024)))
  (and
    (asserts! (< (len observation-type) u64) false)
    (asserts! (< (len data) u1024) false)
    true
  )
)

;; Read-only functions

;; Get citizen scientist data
(define-read-only (get-citizen-scientist (scientist principal))
  (map-get? citizen-scientists scientist)
)

;; Get observation data
(define-read-only (get-observation (observation-id uint))
  (map-get? observations observation-id)
)

;; Get total rewards for a citizen scientist
(define-read-only (get-total-rewards (scientist principal))
  (match (map-get? citizen-scientists scientist)
    scientist-data (ok (get total-rewards scientist-data))
    (err err-not-registered)
  )
)

