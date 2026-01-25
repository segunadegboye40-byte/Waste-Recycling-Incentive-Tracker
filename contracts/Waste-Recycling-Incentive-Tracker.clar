(define-fungible-token waste-token)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-unauthorized (err u105))
(define-constant err-invalid-waste-type (err u106))
(define-constant err-streak-already-claimed (err u107))

(define-constant streak-window u144)
(define-constant streak-bonus-rate u5)

(define-data-var total-recycled uint u0)
(define-data-var reward-rate uint u10)
(define-data-var next-submission-id uint u1)

(define-map user-profiles
  { user: principal }
  {
    total-submissions: uint,
    total-tokens-earned: uint,
    registration-block: uint,
    is-verified: bool
  }
)

(define-map recycling-submissions
  { submission-id: uint }
  {
    user: principal,
    waste-type: (string-ascii 20),
    weight: uint,
    tokens-earned: uint,
    submission-block: uint,
    verified: bool,
    verifier: (optional principal)
  }
)

(define-map waste-type-rates
  { waste-type: (string-ascii 20) }
  { rate-per-kg: uint }
)

(define-map user-balances
  { user: principal }
  { balance: uint }
)

(define-map verifiers
  { verifier: principal }
  { authorized: bool }
)

(define-map user-streaks
  { user: principal }
  {
    current-streak: uint,
    last-activity-block: uint,
    longest-streak: uint,
    total-bonus-earned: uint
  }
)

(define-public (initialize-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set waste-type-rates { waste-type: "plastic" } { rate-per-kg: u15 })
    (map-set waste-type-rates { waste-type: "paper" } { rate-per-kg: u10 })
    (map-set waste-type-rates { waste-type: "glass" } { rate-per-kg: u20 })
    (map-set waste-type-rates { waste-type: "metal" } { rate-per-kg: u25 })
    (map-set waste-type-rates { waste-type: "organic" } { rate-per-kg: u5 })
    (ok true)
  )
)

(define-public (register-user)
  (let
    (
      (user tx-sender)
      (existing-profile (map-get? user-profiles { user: user }))
    )
    (asserts! (is-none existing-profile) err-already-exists)
    (map-set user-profiles
      { user: user }
      {
        total-submissions: u0,
        total-tokens-earned: u0,
        registration-block: stacks-block-height,
        is-verified: false
      }
    )
    (map-set user-balances { user: user } { balance: u0 })
    (ok true)
  )
)

(define-public (submit-recycling (waste-type (string-ascii 20)) (weight uint))
  (let
    (
      (user tx-sender)
      (submission-id (var-get next-submission-id))
      (user-profile (unwrap! (map-get? user-profiles { user: user }) err-not-found))
      (waste-rate (unwrap! (map-get? waste-type-rates { waste-type: waste-type }) err-invalid-waste-type))
      (tokens-to-earn (* weight (get rate-per-kg waste-rate)))
    )
    (asserts! (> weight u0) err-invalid-amount)
    (map-set recycling-submissions
      { submission-id: submission-id }
      {
        user: user,
        waste-type: waste-type,
        weight: weight,
        tokens-earned: tokens-to-earn,
        submission-block: stacks-block-height,
        verified: false,
        verifier: none
      }
    )
    (map-set user-profiles
      { user: user }
      (merge user-profile { total-submissions: (+ (get total-submissions user-profile) u1) })
    )
    (var-set next-submission-id (+ submission-id u1))
    (update-user-streak user)
    (ok submission-id)
  )
)

(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set verifiers { verifier: verifier } { authorized: true })
    (ok true)
  )
)

(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set verifiers { verifier: verifier } { authorized: false })
    (ok true)
  )
)

(define-public (verify-submission (submission-id uint))
  (let
    (
      (verifier tx-sender)
      (submission (unwrap! (map-get? recycling-submissions { submission-id: submission-id }) err-not-found))
      (is-authorized (default-to false (get authorized (map-get? verifiers { verifier: verifier }))))
      (user (get user submission))
      (tokens-earned (get tokens-earned submission))
      (user-profile (unwrap! (map-get? user-profiles { user: user }) err-not-found))
      (current-balance (default-to u0 (get balance (map-get? user-balances { user: user }))))
    )
    (asserts! (or is-authorized (is-eq verifier contract-owner)) err-unauthorized)
    (asserts! (not (get verified submission)) err-already-exists)
    (try! (ft-mint? waste-token tokens-earned user))
    (map-set recycling-submissions
      { submission-id: submission-id }
      (merge submission {
        verified: true,
        verifier: (some verifier)
      })
    )
    (map-set user-profiles
      { user: user }
      (merge user-profile {
        total-tokens-earned: (+ (get total-tokens-earned user-profile) tokens-earned),
        is-verified: true
      })
    )
    (map-set user-balances
      { user: user }
      { balance: (+ current-balance tokens-earned) }
    )
    (var-set total-recycled (+ (var-get total-recycled) (get weight submission)))
    (ok true)
  )
)

(define-public (redeem-tokens (amount uint) (recipient principal))
  (let
    (
      (user tx-sender)
      (current-balance (default-to u0 (get balance (map-get? user-balances { user: user }))))
    )
    (asserts! (>= current-balance amount) err-insufficient-balance)
    (asserts! (> amount u0) err-invalid-amount)
    (try! (ft-transfer? waste-token amount user recipient))
    (map-set user-balances
      { user: user }
      { balance: (- current-balance amount) }
    )
    (ok true)
  )
)

(define-public (transfer-tokens (amount uint) (recipient principal))
  (let
    (
      (sender tx-sender)
      (sender-balance (default-to u0 (get balance (map-get? user-balances { user: sender }))))
      (recipient-balance (default-to u0 (get balance (map-get? user-balances { user: recipient }))))
    )
    (asserts! (>= sender-balance amount) err-insufficient-balance)
    (asserts! (> amount u0) err-invalid-amount)
    (try! (ft-transfer? waste-token amount sender recipient))
    (map-set user-balances { user: sender } { balance: (- sender-balance amount) })
    (map-set user-balances { user: recipient } { balance: (+ recipient-balance amount) })
    (ok true)
  )
)

(define-public (update-waste-type-rate (waste-type (string-ascii 20)) (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set waste-type-rates { waste-type: waste-type } { rate-per-kg: new-rate })
    (ok true)
  )
)

(define-public (update-reward-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set reward-rate new-rate)
    (ok true)
  )
)

(define-read-only (get-user-profile (user principal))
  (map-get? user-profiles { user: user })
)

(define-read-only (get-user-balance (user principal))
  (default-to u0 (get balance (map-get? user-balances { user: user })))
)

(define-read-only (get-submission (submission-id uint))
  (map-get? recycling-submissions { submission-id: submission-id })
)

(define-read-only (get-waste-type-rate (waste-type (string-ascii 20)))
  (map-get? waste-type-rates { waste-type: waste-type })
)

(define-read-only (get-total-recycled)
  (var-get total-recycled)
)

(define-read-only (get-reward-rate)
  (var-get reward-rate)
)

(define-read-only (get-next-submission-id)
  (var-get next-submission-id)
)

(define-read-only (is-verifier (verifier principal))
  (default-to false (get authorized (map-get? verifiers { verifier: verifier })))
)

(define-read-only (get-token-balance (user principal))
  (ft-get-balance waste-token user)
)

(define-read-only (get-total-supply)
  (ft-get-supply waste-token)
)

(define-read-only (get-user-streak (user principal))
  (map-get? user-streaks { user: user })
)

(define-read-only (calculate-streak-bonus (streak-count uint))
  (* streak-count streak-bonus-rate)
)

(define-private (update-user-streak (user principal))
  (let
    (
      (current-block stacks-block-height)
      (existing-streak (map-get? user-streaks { user: user }))
    )
    (match existing-streak
      streak-data
      (let
        (
          (last-block (get last-activity-block streak-data))
          (blocks-since-last (- current-block last-block))
          (is-within-window (<= blocks-since-last streak-window))
          (new-streak (if is-within-window
                        (+ (get current-streak streak-data) u1)
                        u1))
          (new-longest (if (> new-streak (get longest-streak streak-data))
                         new-streak
                         (get longest-streak streak-data)))
        )
        (map-set user-streaks
          { user: user }
          {
            current-streak: new-streak,
            last-activity-block: current-block,
            longest-streak: new-longest,
            total-bonus-earned: (get total-bonus-earned streak-data)
          }
        )
        new-streak
      )
      (begin
        (map-set user-streaks
          { user: user }
          {
            current-streak: u1,
            last-activity-block: current-block,
            longest-streak: u1,
            total-bonus-earned: u0
          }
        )
        u1
      )
    )
  )
)

(define-public (claim-streak-bonus)
  (let
    (
      (user tx-sender)
      (user-profile (unwrap! (map-get? user-profiles { user: user }) err-not-found))
      (streak-data (unwrap! (map-get? user-streaks { user: user }) err-not-found))
      (current-streak (get current-streak streak-data))
      (bonus-amount (calculate-streak-bonus current-streak))
      (current-balance (default-to u0 (get balance (map-get? user-balances { user: user }))))
    )
    (asserts! (>= current-streak u3) err-invalid-amount)
    (try! (ft-mint? waste-token bonus-amount user))
    (map-set user-streaks
      { user: user }
      (merge streak-data {
        current-streak: u0,
        total-bonus-earned: (+ (get total-bonus-earned streak-data) bonus-amount)
      })
    )
    (map-set user-balances
      { user: user }
      { balance: (+ current-balance bonus-amount) }
    )
    (map-set user-profiles
      { user: user }
      (merge user-profile {
        total-tokens-earned: (+ (get total-tokens-earned user-profile) bonus-amount)
      })
    )
    (ok bonus-amount)
  )
)
