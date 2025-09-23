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
(define-constant err-shift-not-found (err u110))
(define-constant err-shift-already-active (err u111))
(define-constant err-shift-not-started (err u112))
(define-constant err-invalid-shift-time (err u113))
(define-constant err-attendance-already-marked (err u114))

(define-data-var contract-enabled bool true)
(define-data-var total-tip-pool uint u0)
(define-data-var distribution-period uint u144)
(define-data-var last-distribution-block uint u0)
(define-data-var staff-count uint u0)
(define-data-var badge-counter uint u0)
(define-data-var shift-counter uint u0)
(define-data-var peak-multiplier uint u150)
(define-data-var weekend-multiplier uint u125)
(define-data-var holiday-multiplier uint u200)
(define-data-var consistency-bonus uint u500)

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

(define-map shifts
  { shift-id: uint }
  {
    shift-type: (string-ascii 20),
    start-block: uint,
    end-block: uint,
    is-peak: bool,
    is-weekend: bool,
    is-holiday: bool,
    base-multiplier: uint,
    total-staff: uint,
    active: bool
  }
)

(define-map shift-attendance
  { shift-id: uint, staff-id: principal }
  {
    clock-in: uint,
    clock-out: (optional uint),
    hours-worked: uint,
    performance-score: uint,
    tips-earned: uint
  }
)

(define-map staff-shift-stats
  { staff-id: principal }
  {
    total-shifts: uint,
    peak-shifts: uint,
    weekend-shifts: uint,
    holiday-shifts: uint,
    consistency-streak: uint,
    last-shift-block: uint,
    total-bonus-earned: uint
  }
)

(define-map shift-performance
  { shift-id: uint }
  {
    total-tips: uint,
    avg-performance: uint,
    staff-count: uint,
    distributed: bool
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

(define-public (create-shift 
  (shift-type (string-ascii 20))
  (duration uint)
  (is-peak bool)
  (is-weekend bool)
  (is-holiday bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (var-get contract-enabled) err-owner-only)
    (asserts! (> duration u0) err-invalid-shift-time)
    (let 
      (
        (shift-id (+ (var-get shift-counter) u1))
        (base-mult (calculate-shift-multiplier is-peak is-weekend is-holiday))
      )
      (map-set shifts
        {shift-id: shift-id}
        {
          shift-type: shift-type,
          start-block: stacks-block-height,
          end-block: (+ stacks-block-height duration),
          is-peak: is-peak,
          is-weekend: is-weekend,
          is-holiday: is-holiday,
          base-multiplier: base-mult,
          total-staff: u0,
          active: true
        }
      )
      (map-set shift-performance
        {shift-id: shift-id}
        {
          total-tips: u0,
          avg-performance: u0,
          staff-count: u0,
          distributed: false
        }
      )
      (var-set shift-counter shift-id)
      (ok shift-id)
    )
  )
)

(define-public (clock-in (shift-id uint))
  (begin
    (asserts! (var-get contract-enabled) err-owner-only)
    (let 
      (
        (shift-data (unwrap! (map-get? shifts {shift-id: shift-id}) err-shift-not-found))
        (staff-data (unwrap! (map-get? staff-members {staff-id: tx-sender}) err-not-found))
        (attendance-key {shift-id: shift-id, staff-id: tx-sender})
      )
      (asserts! (get active staff-data) err-not-staff)
      (asserts! (get active shift-data) err-shift-not-found)
      (asserts! (is-none (map-get? shift-attendance attendance-key)) err-attendance-already-marked)
      (asserts! (<= stacks-block-height (get end-block shift-data)) err-invalid-shift-time)
      
      (map-set shift-attendance
        attendance-key
        {
          clock-in: stacks-block-height,
          clock-out: none,
          hours-worked: u0,
          performance-score: u0,
          tips-earned: u0
        }
      )
      
      (map-set shifts
        {shift-id: shift-id}
        (merge shift-data {total-staff: (+ (get total-staff shift-data) u1)})
      )
      
      (update-staff-shift-stats tx-sender shift-data)
      (ok true)
    )
  )
)

(define-public (clock-out (shift-id uint) (performance-score uint))
  (begin
    (asserts! (var-get contract-enabled) err-owner-only)
    (let 
      (
        (shift-data (unwrap! (map-get? shifts {shift-id: shift-id}) err-shift-not-found))
        (attendance-key {shift-id: shift-id, staff-id: tx-sender})
        (attendance-data (unwrap! (map-get? shift-attendance attendance-key) err-shift-not-started))
      )
      (asserts! (is-none (get clock-out attendance-data)) err-already-exists)
      (asserts! (<= performance-score u100) err-invalid-metric)
      
      (let 
        (
          (hours-worked (- stacks-block-height (get clock-in attendance-data)))
          (shift-perf (unwrap! (map-get? shift-performance {shift-id: shift-id}) err-shift-not-found))
        )
        (map-set shift-attendance
          attendance-key
          (merge attendance-data {
            clock-out: (some stacks-block-height),
            hours-worked: hours-worked,
            performance-score: performance-score
          })
        )
        
        (map-set shift-performance
          {shift-id: shift-id}
          (merge shift-perf {
            avg-performance: (/ (+ (* (get avg-performance shift-perf) (get staff-count shift-perf)) performance-score) 
                               (+ (get staff-count shift-perf) u1)),
            staff-count: (+ (get staff-count shift-perf) u1)
          })
        )
        (ok hours-worked)
      )
    )
  )
)

(define-public (distribute-shift-tips (shift-id uint) (tip-amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (var-get contract-enabled) err-owner-only)
    (asserts! (> tip-amount u0) err-invalid-amount)
    
    (let 
      (
        (shift-data (unwrap! (map-get? shifts {shift-id: shift-id}) err-shift-not-found))
        (shift-perf (unwrap! (map-get? shift-performance {shift-id: shift-id}) err-shift-not-found))
      )
      (asserts! (not (get distributed shift-perf)) err-already-exists)
      (asserts! (> (get staff-count shift-perf) u0) err-not-found)
      
      (try! (stx-transfer? tip-amount tx-sender (as-contract tx-sender)))
      
      (map-set shift-performance
        {shift-id: shift-id}
        (merge shift-perf {
          total-tips: tip-amount,
          distributed: true
        })
      )
      
      (ok tip-amount)
    )
  )
)

(define-public (claim-shift-earnings (shift-id uint))
  (begin
    (asserts! (var-get contract-enabled) err-owner-only)
    (let 
      (
        (attendance-key {shift-id: shift-id, staff-id: tx-sender})
        (attendance-data (unwrap! (map-get? shift-attendance attendance-key) err-shift-not-started))
        (shift-data (unwrap! (map-get? shifts {shift-id: shift-id}) err-shift-not-found))
        (shift-perf (unwrap! (map-get? shift-performance {shift-id: shift-id}) err-shift-not-found))
      )
      (asserts! (get distributed shift-perf) err-no-tips-available)
      (asserts! (is-some (get clock-out attendance-data)) err-shift-not-started)
      (asserts! (is-eq (get tips-earned attendance-data) u0) err-already-exists)
      
      (let 
        (
          (base-share (/ (get total-tips shift-perf) (get staff-count shift-perf)))
          (performance-mult (/ (* (get performance-score attendance-data) u100) u100))
          (shift-mult (get base-multiplier shift-data))
          (total-mult (/ (* performance-mult shift-mult) u100))
          (final-amount (/ (* base-share total-mult) u100))
          (consistency-bonus-amount (calculate-consistency-bonus tx-sender))
          (total-earnings (+ final-amount consistency-bonus-amount))
        )
        (try! (as-contract (stx-transfer? total-earnings tx-sender tx-sender)))
        
        (map-set shift-attendance
          attendance-key
          (merge attendance-data {tips-earned: total-earnings})
        )
        
        (update-earnings-stats tx-sender total-earnings consistency-bonus-amount)
        
        (ok total-earnings)
      )
    )
  )
)

(define-private (calculate-shift-multiplier (is-peak bool) (is-weekend bool) (is-holiday bool))
  (let 
    (
      (peak-mult (if is-peak (var-get peak-multiplier) u100))
      (weekend-mult (if is-weekend (var-get weekend-multiplier) u100))
      (holiday-mult (if is-holiday (var-get holiday-multiplier) u100))
    )
    (/ (* (* peak-mult weekend-mult) holiday-mult) u10000)
  )
)

(define-private (update-staff-shift-stats (staff-id principal) (shift-data {shift-type: (string-ascii 20), start-block: uint, end-block: uint, is-peak: bool, is-weekend: bool, is-holiday: bool, base-multiplier: uint, total-staff: uint, active: bool}))
  (let 
    (
      (current-stats (default-to 
        {
          total-shifts: u0,
          peak-shifts: u0,
          weekend-shifts: u0,
          holiday-shifts: u0,
          consistency-streak: u0,
          last-shift-block: u0,
          total-bonus-earned: u0
        }
        (map-get? staff-shift-stats {staff-id: staff-id})))
      (blocks-since-last (- stacks-block-height (get last-shift-block current-stats)))
      (new-streak (if (<= blocks-since-last u288) 
                     (+ (get consistency-streak current-stats) u1)
                     u1))
    )
    (map-set staff-shift-stats
      {staff-id: staff-id}
      {
        total-shifts: (+ (get total-shifts current-stats) u1),
        peak-shifts: (if (get is-peak shift-data) 
                       (+ (get peak-shifts current-stats) u1)
                       (get peak-shifts current-stats)),
        weekend-shifts: (if (get is-weekend shift-data)
                         (+ (get weekend-shifts current-stats) u1)
                         (get weekend-shifts current-stats)),
        holiday-shifts: (if (get is-holiday shift-data)
                         (+ (get holiday-shifts current-stats) u1)
                         (get holiday-shifts current-stats)),
        consistency-streak: new-streak,
        last-shift-block: stacks-block-height,
        total-bonus-earned: (get total-bonus-earned current-stats)
      }
    )
  )
)

(define-private (calculate-consistency-bonus (staff-id principal))
  (let 
    (
      (stats (default-to 
        {
          total-shifts: u0,
          peak-shifts: u0,
          weekend-shifts: u0,
          holiday-shifts: u0,
          consistency-streak: u0,
          last-shift-block: u0,
          total-bonus-earned: u0
        }
        (map-get? staff-shift-stats {staff-id: staff-id})))
    )
    (if (>= (get consistency-streak stats) u5)
      (var-get consistency-bonus)
      u0)
  )
)

(define-private (update-earnings-stats (staff-id principal) (earnings uint) (bonus uint))
  (let 
    (
      (stats (unwrap-panic (map-get? staff-shift-stats {staff-id: staff-id})))
      (staff-data (unwrap-panic (map-get? staff-members {staff-id: staff-id})))
    )
    (map-set staff-shift-stats
      {staff-id: staff-id}
      (merge stats {total-bonus-earned: (+ (get total-bonus-earned stats) bonus)})
    )
    (map-set staff-members
      {staff-id: staff-id}
      (merge staff-data {total-earned: (+ (get total-earned staff-data) earnings)})
    )
  )
)

(define-public (set-shift-multipliers 
  (peak uint)
  (weekend uint) 
  (holiday uint)
  (consistency uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (and (>= peak u100) (<= peak u300)) err-invalid-amount)
    (asserts! (and (>= weekend u100) (<= weekend u200)) err-invalid-amount)
    (asserts! (and (>= holiday u100) (<= holiday u400)) err-invalid-amount)
    (asserts! (> consistency u0) err-invalid-amount)
    
    (var-set peak-multiplier peak)
    (var-set weekend-multiplier weekend)
    (var-set holiday-multiplier holiday)
    (var-set consistency-bonus consistency)
    (ok true)
  )
)

(define-read-only (get-shift-info (shift-id uint))
  (map-get? shifts {shift-id: shift-id})
)

(define-read-only (get-shift-attendance (shift-id uint) (staff-id principal))
  (map-get? shift-attendance {shift-id: shift-id, staff-id: staff-id})
)

(define-read-only (get-staff-shift-stats (staff-id principal))
  (map-get? staff-shift-stats {staff-id: staff-id})
)

(define-read-only (get-shift-performance (shift-id uint))
  (map-get? shift-performance {shift-id: shift-id})
)

(define-read-only (get-shift-multipliers)
  {
    peak: (var-get peak-multiplier),
    weekend: (var-get weekend-multiplier),
    holiday: (var-get holiday-multiplier),
    consistency-bonus: (var-get consistency-bonus)
  }
)

(define-read-only (get-active-shift)
  (let ((latest-shift-id (var-get shift-counter)))
    (if (> latest-shift-id u0)
      (let ((shift-data (map-get? shifts {shift-id: latest-shift-id})))
        (match shift-data
          shift (if (and (get active shift) 
                        (>= stacks-block-height (get start-block shift))
                        (<= stacks-block-height (get end-block shift)))
                  (some latest-shift-id)
                  none)
          none))
      none))
)
