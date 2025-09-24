;; TeachFi Teacher Rewards Contract
;; This contract manages reward distribution and teacher registration for educational performance incentives

;; Constants and Error Codes
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_AMOUNT (err u400))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))
(define-constant ERR_TEACHER_NOT_REGISTERED (err u403))
(define-constant ERR_INVALID_PERFORMANCE_SCORE (err u405))
(define-constant ERR_REWARD_ALREADY_CLAIMED (err u406))
(define-constant ERR_INVALID_REWARD_TIER (err u407))
(define-constant ERR_MINIMUM_PERFORMANCE_NOT_MET (err u408))

;; Reward tier thresholds and multipliers
(define-constant BRONZE_THRESHOLD u60) ;; 60% performance score
(define-constant SILVER_THRESHOLD u70) ;; 70% performance score
(define-constant GOLD_THRESHOLD u80) ;; 80% performance score
(define-constant PLATINUM_THRESHOLD u90) ;; 90% performance score
(define-constant DIAMOND_THRESHOLD u95) ;; 95% performance score

(define-constant BRONZE_MULTIPLIER u125) ;; 25% bonus (125/100)
(define-constant SILVER_MULTIPLIER u150) ;; 50% bonus (150/100)
(define-constant GOLD_MULTIPLIER u200) ;; 100% bonus (200/100)
(define-constant PLATINUM_MULTIPLIER u250) ;; 150% bonus (250/100)
(define-constant DIAMOND_MULTIPLIER u300) ;; 200% bonus (300/100)

(define-constant BASE_REWARD_AMOUNT u1000000) ;; 1 STX in microSTX
(define-constant MINIMUM_PERFORMANCE u50) ;; Minimum 50% to qualify for rewards

;; Data Variables
(define-data-var next-teacher-id uint u1)
(define-data-var total-registered-teachers uint u0)
(define-data-var total-rewards-distributed uint u0)
(define-data-var reward-pool-balance uint u0)
(define-data-var current-semester uint u1)
(define-data-var system-active bool true)

;; Teacher Registration and Profile
(define-map teachers
  { teacher-id: uint }
  {
    address: principal,
    name: (string-ascii 50),
    subject: (string-ascii 30),
    institution: (string-ascii 50),
    registration-block: uint,
    total-students: uint,
    performance-score: uint,
    total-rewards-earned: uint,
    tier-level: (string-ascii 10),
    is-active: bool,
    verification-status: bool
  }
)

;; Teacher Address to ID mapping
(define-map teacher-lookup
  { address: principal }
  { teacher-id: uint }
)

;; Reward Claims Tracking
(define-map reward-claims
  { teacher-id: uint, semester: uint }
  {
    claimed: bool,
    claim-block: uint,
    reward-amount: uint,
    performance-score: uint,
    tier-achieved: (string-ascii 10)
  }
)

;; Performance History
(define-map performance-history
  { teacher-id: uint, semester: uint }
  {
    student-count: uint,
    average-score: uint,
    improvement-rate: uint,
    completion-rate: uint,
    satisfaction-rating: uint,
    bonus-achievements: uint
  }
)

;; Reward Pool Contributors
(define-map pool-contributors
  { contributor: principal }
  {
    total-contributed: uint,
    contribution-blocks: (list 10 uint),
    is-institution: bool
  }
)

;; Institution Registry
(define-map institutions
  { institution-id: uint }
  {
    name: (string-ascii 50),
    admin: principal,
    teacher-count: uint,
    total-pool-contribution: uint,
    is-verified: bool
  }
)

;; Read-only functions for data retrieval
(define-read-only (get-teacher-info (teacher-id uint))
  (map-get? teachers { teacher-id: teacher-id })
)

(define-read-only (get-teacher-by-address (teacher-address principal))
  (match (map-get? teacher-lookup { address: teacher-address })
    lookup-result (map-get? teachers { teacher-id: (get teacher-id lookup-result) })
    none
  )
)

(define-read-only (get-reward-claim-status (teacher-id uint) (semester uint))
  (map-get? reward-claims { teacher-id: teacher-id, semester: semester })
)

(define-read-only (get-performance-history (teacher-id uint) (semester uint))
  (map-get? performance-history { teacher-id: teacher-id, semester: semester })
)

(define-read-only (get-system-stats)
  {
    total-teachers: (var-get total-registered-teachers),
    total-rewards: (var-get total-rewards-distributed),
    pool-balance: (var-get reward-pool-balance),
    current-semester: (var-get current-semester),
    system-active: (var-get system-active),
    next-teacher-id: (var-get next-teacher-id)
  }
)

(define-read-only (calculate-reward-amount (performance-score uint))
  (let (
    (multiplier (get-tier-multiplier performance-score))
  )
    (/ (* BASE_REWARD_AMOUNT multiplier) u100)
  )
)

(define-read-only (get-tier-multiplier (performance-score uint))
  (if (>= performance-score DIAMOND_THRESHOLD)
    DIAMOND_MULTIPLIER
    (if (>= performance-score PLATINUM_THRESHOLD)
      PLATINUM_MULTIPLIER
      (if (>= performance-score GOLD_THRESHOLD)
        GOLD_MULTIPLIER
        (if (>= performance-score SILVER_THRESHOLD)
          SILVER_MULTIPLIER
          (if (>= performance-score BRONZE_THRESHOLD)
            BRONZE_MULTIPLIER
            u100)))))
)

(define-read-only (get-tier-name (performance-score uint))
  (if (>= performance-score DIAMOND_THRESHOLD)
    "Diamond"
    (if (>= performance-score PLATINUM_THRESHOLD)
      "Platinum"
      (if (>= performance-score GOLD_THRESHOLD)
        "Gold"
        (if (>= performance-score SILVER_THRESHOLD)
          "Silver"
          (if (>= performance-score BRONZE_THRESHOLD)
            "Bronze"
            "None")))))
)

;; Administrative functions
(define-public (toggle-system-status)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (var-set system-active (not (var-get system-active))))
  )
)

(define-public (advance-semester)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set current-semester (+ (var-get current-semester) u1))
    (ok (var-get current-semester))
  )
)

;; Teacher registration
(define-public (register-teacher
    (name (string-ascii 50))
    (subject (string-ascii 30))
    (institution (string-ascii 50)))
  (let (
    (teacher-id (var-get next-teacher-id))
  )
    (asserts! (var-get system-active) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? teacher-lookup { address: tx-sender })) ERR_UNAUTHORIZED)
    (asserts! (> (len name) u0) ERR_INVALID_AMOUNT)
    
    ;; Register teacher
    (map-set teachers
      { teacher-id: teacher-id }
      {
        address: tx-sender,
        name: name,
        subject: subject,
        institution: institution,
        registration-block: stacks-block-height,
        total-students: u0,
        performance-score: u0,
        total-rewards-earned: u0,
        tier-level: "None",
        is-active: true,
        verification-status: false
      })
    
    ;; Create address lookup
    (map-set teacher-lookup
      { address: tx-sender }
      { teacher-id: teacher-id })
    
    ;; Update contract state
    (var-set next-teacher-id (+ teacher-id u1))
    (var-set total-registered-teachers (+ (var-get total-registered-teachers) u1))
    
    (ok teacher-id)
  )
)

;; Update teacher performance score
(define-public (update-performance-score
    (teacher-id uint)
    (performance-score uint)
    (student-count uint))
  (let (
    (teacher-info (unwrap! (map-get? teachers { teacher-id: teacher-id }) ERR_TEACHER_NOT_REGISTERED))
    (tier-name (get-tier-name performance-score))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (var-get system-active) ERR_UNAUTHORIZED)
    (asserts! (and (>= performance-score u0) (<= performance-score u100)) ERR_INVALID_PERFORMANCE_SCORE)
    (asserts! (get is-active teacher-info) ERR_TEACHER_NOT_REGISTERED)
    
    ;; Update teacher information
    (map-set teachers
      { teacher-id: teacher-id }
      (merge teacher-info {
        performance-score: performance-score,
        total-students: student-count,
        tier-level: tier-name
      }))
    
    ;; Record performance history
    (map-set performance-history
      { teacher-id: teacher-id, semester: (var-get current-semester) }
      {
        student-count: student-count,
        average-score: performance-score,
        improvement-rate: u0,
        completion-rate: u0,
        satisfaction-rating: u0,
        bonus-achievements: u0
      })
    
    (ok true)
  )
)

;; Contribute to reward pool
(define-public (contribute-to-pool (amount uint))
  (let (
    (current-contribution (default-to 
      { total-contributed: u0, contribution-blocks: (list), is-institution: false }
      (map-get? pool-contributors { contributor: tx-sender })))
  )
    (asserts! (var-get system-active) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update pool balance
    (var-set reward-pool-balance (+ (var-get reward-pool-balance) amount))
    
    ;; Track contributor
    (map-set pool-contributors
      { contributor: tx-sender }
      {
        total-contributed: (+ (get total-contributed current-contribution) amount),
        contribution-blocks: (unwrap-panic (as-max-len? 
          (append (get contribution-blocks current-contribution) stacks-block-height) u10)),
        is-institution: (get is-institution current-contribution)
      })
    
    (ok amount)
  )
)

;; Claim rewards for performance
(define-public (claim-reward (teacher-id uint))
  (let (
    (teacher-info (unwrap! (map-get? teachers { teacher-id: teacher-id }) ERR_TEACHER_NOT_REGISTERED))
    (current-semester-val (var-get current-semester))
    (existing-claim (map-get? reward-claims { teacher-id: teacher-id, semester: current-semester-val }))
    (performance-score (get performance-score teacher-info))
    (reward-amount (calculate-reward-amount performance-score))
    (tier-name (get-tier-name performance-score))
  )
    (asserts! (var-get system-active) ERR_UNAUTHORIZED)
    (asserts! (is-eq tx-sender (get address teacher-info)) ERR_UNAUTHORIZED)
    (asserts! (get is-active teacher-info) ERR_TEACHER_NOT_REGISTERED)
    (asserts! (>= performance-score MINIMUM_PERFORMANCE) ERR_MINIMUM_PERFORMANCE_NOT_MET)
    (asserts! (is-none existing-claim) ERR_REWARD_ALREADY_CLAIMED)
    (asserts! (>= (var-get reward-pool-balance) reward-amount) ERR_INSUFFICIENT_FUNDS)
    
    ;; Transfer reward to teacher
    (try! (as-contract (stx-transfer? reward-amount tx-sender (get address teacher-info))))
    
    ;; Update balances and tracking
    (var-set reward-pool-balance (- (var-get reward-pool-balance) reward-amount))
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) reward-amount))
    
    ;; Record claim
    (map-set reward-claims
      { teacher-id: teacher-id, semester: current-semester-val }
      {
        claimed: true,
        claim-block: stacks-block-height,
        reward-amount: reward-amount,
        performance-score: performance-score,
        tier-achieved: tier-name
      })
    
    ;; Update teacher's total rewards
    (map-set teachers
      { teacher-id: teacher-id }
      (merge teacher-info {
        total-rewards-earned: (+ (get total-rewards-earned teacher-info) reward-amount)
      }))
    
    (ok reward-amount)
  )
)

;; Verify teacher credentials
(define-public (verify-teacher (teacher-id uint))
  (let (
    (teacher-info (unwrap! (map-get? teachers { teacher-id: teacher-id }) ERR_TEACHER_NOT_REGISTERED))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (map-set teachers
      { teacher-id: teacher-id }
      (merge teacher-info { verification-status: true }))
    
    (ok true)
  )
)

;; Deactivate teacher account
(define-public (deactivate-teacher (teacher-id uint))
  (let (
    (teacher-info (unwrap! (map-get? teachers { teacher-id: teacher-id }) ERR_TEACHER_NOT_REGISTERED))
  )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-eq tx-sender (get address teacher-info))) ERR_UNAUTHORIZED)
    
    (map-set teachers
      { teacher-id: teacher-id }
      (merge teacher-info { is-active: false }))
    
    (ok true)
  )
)

