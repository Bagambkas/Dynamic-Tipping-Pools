;; title: Dynamic-Tipping-pools
;; version: 1.0.0
;; summary: Smart contract for performance-based tip distribution among kitchen staff
;; description: Manages tip pools and distributes rewards based on staff performance metrics

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-not-staff (err u105))
(define-constant err-invalid-metric (err u106))
(define-constant err-no-tips-available (err u107))
(define-constant err-badge-not-found (err u108))
(define-constant err-badge-already-earned (err u109))

(define-data-var contract-enabled bool true)
(define-data-var total-tip-pool uint u0)
(define-data-var distribution-period uint u144)
(define-data-var last-distribution-block uint u0)
(define-data-var staff-count uint u0)
(define-data-var badge-counter uint u0)

(define-map staff-members
  { staff-id: principal }
  {
    name: (string-ascii 50),
    role: (string-ascii 30),
    hire-block: uint,
    active: bool,
    total-earned: uint
  }
)

(define-map performance-metrics
  { staff-id: principal, period: uint }
  {
    orders-completed: uint,
    quality-score: uint,
    punctuality-score: uint,
    teamwork-score: uint,
    efficiency-score: uint,
    total-score: uint
  }
)

(define-map tip-distributions
  { period: uint }
  {
    total-amount: uint,
    staff-count: uint,
    distribution-block: uint,
    completed: bool
  }
)

(define-map staff-earnings
  { staff-id: principal, period: uint }
  {
    base-share: uint,
    performance-bonus: uint,
    total-earned: uint,
    claimed: bool
  }
)

(define-map performance-badges
  { badge-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 100),
    requirement-type: (string-ascii 20),
    threshold: uint,
    created-block: uint
  }
)

(define-map staff-badge-achievements
  { staff-id: principal, badge-id: uint }
  {
    earned-block: uint,
    performance-value: uint
  }
)

(define-public (toggle-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set contract-enabled (not (var-get contract-enabled))))
  )
)

(define-public (register-staff (staff-id principal) (name (string-ascii 50)) (role (string-ascii 30)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (var-get contract-enabled) err-owner-only)
    (asserts! (is-none (map-get? staff-members {staff-id: staff-id})) err-already-exists)
    (map-set staff-members
      {staff-id: staff-id}
      {
        name: name,
        role: role,
        hire-block: stacks-block-height,
        active: true,
        total-earned: u0
      }
    )
    (var-set staff-count (+ (var-get staff-count) u1))
    (ok true)
  )
)

(define-public (deactivate-staff (staff-id principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (let ((staff-data (unwrap! (map-get? staff-members {staff-id: staff-id}) err-not-found)))
      (map-set staff-members
        {staff-id: staff-id}
        (merge staff-data {active: false})
      )
      (var-set staff-count (- (var-get staff-count) u1))
      (ok true)
    )
  )
)

(define-public (add-tip (amount uint))
  (begin
    (asserts! (var-get contract-enabled) err-owner-only)
    (asserts! (> amount u0) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set total-tip-pool (+ (var-get total-tip-pool) amount))
    (ok true)
  )
)

(define-public (record-performance 
  (staff-id principal) 
  (orders-completed uint) 
  (quality-score uint) 
  (punctuality-score uint) 
  (teamwork-score uint) 
  (efficiency-score uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (var-get contract-enabled) err-owner-only)
    (let 
      (
        (staff-data (unwrap! (map-get? staff-members {staff-id: staff-id}) err-not-found))
        (current-period (get-current-period))
        (total-score (+ (+ quality-score punctuality-score) (+ teamwork-score efficiency-score)))
      )
      (asserts! (get active staff-data) err-not-staff)
      (asserts! (<= quality-score u100) err-invalid-metric)
      (asserts! (<= punctuality-score u100) err-invalid-metric)
      (asserts! (<= teamwork-score u100) err-invalid-metric)
      (asserts! (<= efficiency-score u100) err-invalid-metric)
      (map-set performance-metrics
        {staff-id: staff-id, period: current-period}
        {
          orders-completed: orders-completed,
          quality-score: quality-score,
          punctuality-score: punctuality-score,
          teamwork-score: teamwork-score,
          efficiency-score: efficiency-score,
          total-score: total-score
        }
      )
      (ok true)
    )
  )
)

(define-public (distribute-tips)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (var-get contract-enabled) err-owner-only)
    (let 
      (
        (current-period (get-current-period))
        (tip-amount (var-get total-tip-pool))
        (active-staff (var-get staff-count))
      )
      (asserts! (> tip-amount u0) err-no-tips-available)
      (asserts! (> active-staff u0) err-not-found)
      (asserts! (>= (- stacks-block-height (var-get last-distribution-block)) (var-get distribution-period)) err-owner-only)
      
      (map-set tip-distributions
        {period: current-period}
        {
          total-amount: tip-amount,
          staff-count: active-staff,
          distribution-block: stacks-block-height,
          completed: false
        }
      )
      
      (var-set last-distribution-block stacks-block-height)
      (var-set total-tip-pool u0)
      (ok current-period)
    )
  )
)

(define-public (calculate-staff-share (staff-id principal) (period uint))
  (begin
    (asserts! (var-get contract-enabled) err-owner-only)
    (let 
      (
        (staff-data (unwrap! (map-get? staff-members {staff-id: staff-id}) err-not-found))
        (performance-data (unwrap! (map-get? performance-metrics {staff-id: staff-id, period: period}) err-not-found))
        (distribution-data (unwrap! (map-get? tip-distributions {period: period}) err-not-found))
        (base-share (/ (get total-amount distribution-data) (get staff-count distribution-data)))
        (performance-multiplier (calculate-performance-multiplier (get total-score performance-data)))
        (performance-bonus (/ (* base-share performance-multiplier) u100))
        (total-earned (+ base-share performance-bonus))
      )
      (asserts! (get active staff-data) err-not-staff)
      (map-set staff-earnings
        {staff-id: staff-id, period: period}
        {
          base-share: base-share,
          performance-bonus: performance-bonus,
          total-earned: total-earned,
          claimed: false
        }
      )
      (ok total-earned)
    )
  )
)

(define-public (claim-earnings (period uint))
  (begin
    (asserts! (var-get contract-enabled) err-owner-only)
    (let 
      (
        (staff-data (unwrap! (map-get? staff-members {staff-id: tx-sender}) err-not-found))
        (earnings-data (unwrap! (map-get? staff-earnings {staff-id: tx-sender, period: period}) err-not-found))
      )
      (asserts! (get active staff-data) err-not-staff)
      (asserts! (not (get claimed earnings-data)) err-already-exists)
      (asserts! (> (get total-earned earnings-data) u0) err-invalid-amount)
      
      (try! (as-contract (stx-transfer? (get total-earned earnings-data) tx-sender tx-sender)))
      
      (map-set staff-earnings
        {staff-id: tx-sender, period: period}
        (merge earnings-data {claimed: true})
      )
      
      (map-set staff-members
        {staff-id: tx-sender}
        (merge staff-data {total-earned: (+ (get total-earned staff-data) (get total-earned earnings-data))})
      )
      
      (ok (get total-earned earnings-data))
    )
  )
)

(define-public (set-distribution-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-period u0) err-invalid-amount)
    (ok (var-set distribution-period new-period))
  )
)

(define-read-only (get-staff-info (staff-id principal))
  (map-get? staff-members {staff-id: staff-id})
)

(define-read-only (get-performance-metrics (staff-id principal) (period uint))
  (map-get? performance-metrics {staff-id: staff-id, period: period})
)

(define-read-only (get-staff-earnings (staff-id principal) (period uint))
  (map-get? staff-earnings {staff-id: staff-id, period: period})
)

(define-read-only (get-distribution-info (period uint))
  (map-get? tip-distributions {period: period})
)

(define-read-only (get-contract-stats)
  {
    enabled: (var-get contract-enabled),
    total-tip-pool: (var-get total-tip-pool),
    staff-count: (var-get staff-count),
    distribution-period: (var-get distribution-period),
    last-distribution: (var-get last-distribution-block),
    current-period: (get-current-period)
  }
)

(define-read-only (get-current-period)
  (/ stacks-block-height (var-get distribution-period))
)

(define-private (calculate-performance-multiplier (total-score uint))
  (if (>= total-score u350)
    u50
    (if (>= total-score u300)
      u30
      (if (>= total-score u250)
        u20
        (if (>= total-score u200)
          u10
          u0
        )
      )
    )
  )
)

(define-public (create-badge 
  (name (string-ascii 50)) 
  (description (string-ascii 100)) 
  (requirement-type (string-ascii 20)) 
  (threshold uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (var-get contract-enabled) err-owner-only)
    (asserts! (> threshold u0) err-invalid-amount)
    (let ((badge-id (+ (var-get badge-counter) u1)))
      (map-set performance-badges
        {badge-id: badge-id}
        {
          name: name,
          description: description,
          requirement-type: requirement-type,
          threshold: threshold,
          created-block: stacks-block-height
        }
      )
      (var-set badge-counter badge-id)
      (ok badge-id)
    )
  )
)

(define-public (check-and-award-badges (staff-id principal))
  (begin
    (asserts! (var-get contract-enabled) err-owner-only)
    (let 
      (
        (staff-data (unwrap! (map-get? staff-members {staff-id: staff-id}) err-not-found))
        (current-period (get-current-period))
        (performance-data (map-get? performance-metrics {staff-id: staff-id, period: current-period}))
      )
      (asserts! (get active staff-data) err-not-staff)
      (match performance-data
        some-performance
        (let 
          (
            (badge-1 (check-badge-achievement staff-id u1 "total-score" (get total-score some-performance)))
            (badge-2 (check-badge-achievement staff-id u2 "quality-score" (get quality-score some-performance)))
            (badge-3 (check-badge-achievement staff-id u3 "orders-completed" (get orders-completed some-performance)))
          )
          (ok true)
        )
        (ok false)
      )
    )
  )
)

(define-private (check-badge-achievement (staff-id principal) (badge-id uint) (metric-type (string-ascii 20)) (metric-value uint))
  (let 
    (
      (badge-data (map-get? performance-badges {badge-id: badge-id}))
      (existing-achievement (map-get? staff-badge-achievements {staff-id: staff-id, badge-id: badge-id}))
    )
    (match badge-data
      some-badge
      (if (and 
            (is-eq (get requirement-type some-badge) metric-type)
            (>= metric-value (get threshold some-badge))
            (is-none existing-achievement))
        (begin
          (map-set staff-badge-achievements
            {staff-id: staff-id, badge-id: badge-id}
            {
              earned-block: stacks-block-height,
              performance-value: metric-value
            }
          )
          (ok true)
        )
        (ok false)
      )
      (ok false)
    )
  )
)

(define-read-only (get-staff-badges (staff-id principal))
  (let ((achievement-1 (map-get? staff-badge-achievements {staff-id: staff-id, badge-id: u1}))
        (achievement-2 (map-get? staff-badge-achievements {staff-id: staff-id, badge-id: u2}))
        (achievement-3 (map-get? staff-badge-achievements {staff-id: staff-id, badge-id: u3})))
    (list 
      {badge-id: u1, achievement: achievement-1}
      {badge-id: u2, achievement: achievement-2}  
      {badge-id: u3, achievement: achievement-3}
    )
  )
)

(define-read-only (get-badge-info (badge-id uint))
  (map-get? performance-badges {badge-id: badge-id})
)

(define-read-only (get-all-badges)
  (list 
    {badge-id: u1, badge-info: (map-get? performance-badges {badge-id: u1})}
    {badge-id: u2, badge-info: (map-get? performance-badges {badge-id: u2})}
    {badge-id: u3, badge-info: (map-get? performance-badges {badge-id: u3})}
  )
)
