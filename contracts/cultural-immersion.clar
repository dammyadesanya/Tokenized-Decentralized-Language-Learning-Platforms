;; Cultural Immersion Contract
;; Provides authentic cultural context

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-MODULE-NOT-FOUND (err u301))
(define-constant ERR-ALREADY-COMPLETED (err u302))
(define-constant ERR-INVALID-DIFFICULTY (err u303))

;; Data Variables
(define-data-var module-counter uint u0)

;; Data Maps
(define-map cultural-modules
  { module-id: uint }
  {
    title: (string-ascii 50),
    language: (string-ascii 20),
    difficulty: uint,
    content-hash: (string-ascii 64),
    reward-tokens: uint,
    creator: principal,
    is-active: bool
  }
)

(define-map user-progress
  { user: principal, module-id: uint }
  {
    completed-at: uint,
    score: uint,
    tokens-earned: uint
  }
)

(define-map user-stats
  { user: principal, language: (string-ascii 20) }
  {
    modules-completed: uint,
    total-tokens: uint,
    cultural-score: uint
  }
)

;; Public Functions
(define-public (create-module (title (string-ascii 50)) (language (string-ascii 20)) (difficulty uint) (content-hash (string-ascii 64)) (reward-tokens uint))
  (let ((module-id (+ (var-get module-counter) u1)))
    (asserts! (and (>= difficulty u1) (<= difficulty u5)) ERR-INVALID-DIFFICULTY)

    (map-set cultural-modules
      { module-id: module-id }
      {
        title: title,
        language: language,
        difficulty: difficulty,
        content-hash: content-hash,
        reward-tokens: reward-tokens,
        creator: tx-sender,
        is-active: true
      }
    )

    (var-set module-counter module-id)
    (ok module-id)
  )
)

(define-public (complete-module (module-id uint) (score uint))
  (let
    (
      (module (unwrap! (map-get? cultural-modules { module-id: module-id }) ERR-MODULE-NOT-FOUND))
      (user tx-sender)
    )
    (asserts! (get is-active module) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? user-progress { user: user, module-id: module-id })) ERR-ALREADY-COMPLETED)
    (asserts! (<= score u100) ERR-INVALID-DIFFICULTY)

    (let ((tokens-earned (calculate-tokens score (get reward-tokens module))))
      (map-set user-progress
        { user: user, module-id: module-id }
        {
          completed-at: block-height,
          score: score,
          tokens-earned: tokens-earned
        }
      )

      (update-user-stats user (get language module) tokens-earned)
      (ok tokens-earned)
    )
  )
)

;; Private Functions
(define-private (update-user-stats (user principal) (language (string-ascii 20)) (tokens uint))
  (let
    (
      (current-stats (default-to
        { modules-completed: u0, total-tokens: u0, cultural-score: u0 }
        (map-get? user-stats { user: user, language: language })
      ))
    )
    (map-set user-stats
      { user: user, language: language }
      {
        modules-completed: (+ (get modules-completed current-stats) u1),
        total-tokens: (+ (get total-tokens current-stats) tokens),
        cultural-score: (calculate-cultural-score (+ (get modules-completed current-stats) u1))
      }
    )
  )
)

;; Read-only Functions
(define-read-only (get-module (module-id uint))
  (map-get? cultural-modules { module-id: module-id })
)

(define-read-only (get-user-progress (user principal) (module-id uint))
  (map-get? user-progress { user: user, module-id: module-id })
)

(define-read-only (get-user-stats (user principal) (language (string-ascii 20)))
  (map-get? user-stats { user: user, language: language })
)

(define-read-only (calculate-tokens (score uint) (base-reward uint))
  (/ (* score base-reward) u100)
)

(define-read-only (calculate-cultural-score (modules-completed uint))
  (if (<= modules-completed u5) (* modules-completed u10)
    (if (<= modules-completed u15) (+ u50 (* (- modules-completed u5) u5))
      (+ u100 (* (- modules-completed u15) u2))
    )
  )
)

(define-read-only (get-module-counter)
  (var-get module-counter)
)
