;; Conversation Practice Contract
;; Facilitates real-time speaking opportunities

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-SESSION-NOT-FOUND (err u501))
(define-constant ERR-SESSION-ENDED (err u502))
(define-constant ERR-INVALID-DURATION (err u503))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u504))

;; Data Variables
(define-data-var session-counter uint u0)

;; Data Maps
(define-map practice-sessions
  { session-id: uint }
  {
    participants: (list 2 principal),
    language: (string-ascii 20),
    topic: (string-ascii 100),
    duration: uint,
    start-time: uint,
    end-time: uint,
    session-fee: uint,
    is-active: bool,
    is-completed: bool
  }
)

(define-map session-ratings
  { session-id: uint, rater: principal }
  {
    rating: uint,
    feedback: (string-ascii 200),
    rated-at: uint
  }
)

(define-map user-session-stats
  { user: principal, language: (string-ascii 20) }
  {
    total-sessions: uint,
    total-minutes: uint,
    average-rating: uint,
    tokens-earned: uint
  }
)

;; Public Functions
(define-public (create-session (participant principal) (language (string-ascii 20)) (topic (string-ascii 100)) (duration uint) (session-fee uint))
  (let ((session-id (+ (var-get session-counter) u1)))
    (asserts! (> duration u0) ERR-INVALID-DURATION)

    (map-set practice-sessions
      { session-id: session-id }
      {
        participants: (list tx-sender participant),
        language: language,
        topic: topic,
        duration: duration,
        start-time: block-height,
        end-time: (+ block-height duration),
        session-fee: session-fee,
        is-active: true,
        is-completed: false
      }
    )

    (var-set session-counter session-id)
    (ok session-id)
  )
)

(define-public (end-session (session-id uint))
  (let
    (
      (session (unwrap! (map-get? practice-sessions { session-id: session-id }) ERR-SESSION-NOT-FOUND))
      (participants (get participants session))
    )
    (asserts! (or
      (is-eq tx-sender (unwrap-panic (element-at participants u0)))
      (is-eq tx-sender (unwrap-panic (element-at participants u1)))
    ) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active session) ERR-SESSION-ENDED)

    (map-set practice-sessions
      { session-id: session-id }
      (merge session { is-active: false, is-completed: true })
    )

    (update-session-stats (unwrap-panic (element-at participants u0)) (get language session) (get duration session))
    (update-session-stats (unwrap-panic (element-at participants u1)) (get language session) (get duration session))
    (ok true)
  )
)

(define-public (rate-session (session-id uint) (rating uint) (feedback (string-ascii 200)))
  (let
    (
      (session (unwrap! (map-get? practice-sessions { session-id: session-id }) ERR-SESSION-NOT-FOUND))
      (participants (get participants session))
    )
    (asserts! (or
      (is-eq tx-sender (unwrap-panic (element-at participants u0)))
      (is-eq tx-sender (unwrap-panic (element-at participants u1)))
    ) ERR-NOT-AUTHORIZED)
    (asserts! (get is-completed session) ERR-SESSION-ENDED)
    (asserts! (<= rating u5) ERR-INVALID-DURATION)

    (map-set session-ratings
      { session-id: session-id, rater: tx-sender }
      {
        rating: rating,
        feedback: feedback,
        rated-at: block-height
      }
    )
    (ok true)
  )
)

;; Private Functions
(define-private (update-session-stats (user principal) (language (string-ascii 20)) (duration uint))
  (let
    (
      (current-stats (default-to
        { total-sessions: u0, total-minutes: u0, average-rating: u0, tokens-earned: u0 }
        (map-get? user-session-stats { user: user, language: language })
      ))
      (tokens-earned (/ duration u10))
    )
    (map-set user-session-stats
      { user: user, language: language }
      {
        total-sessions: (+ (get total-sessions current-stats) u1),
        total-minutes: (+ (get total-minutes current-stats) duration),
        average-rating: (get average-rating current-stats),
        tokens-earned: (+ (get tokens-earned current-stats) tokens-earned)
      }
    )
  )
)

;; Read-only Functions
(define-read-only (get-session (session-id uint))
  (map-get? practice-sessions { session-id: session-id })
)

(define-read-only (get-session-rating (session-id uint) (rater principal))
  (map-get? session-ratings { session-id: session-id, rater: rater })
)

(define-read-only (get-user-stats (user principal) (language (string-ascii 20)))
  (map-get? user-session-stats { user: user, language: language })
)

(define-read-only (get-session-counter)
  (var-get session-counter)
)

(define-read-only (is-session-active (session-id uint))
  (match (map-get? practice-sessions { session-id: session-id })
    session (and (get is-active session) (< block-height (get end-time session)))
    false
  )
)
