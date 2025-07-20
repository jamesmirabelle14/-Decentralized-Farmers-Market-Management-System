;; Health Permit Contract
;; Ensures food safety compliance for prepared foods

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-PERMIT-NOT-FOUND (err u401))
(define-constant ERR-PERMIT-EXPIRED (err u402))
(define-constant ERR-INVALID-GRADE (err u403))
(define-constant ERR-ALREADY-HAS-PERMIT (err u404))
(define-constant ERR-INSPECTION-REQUIRED (err u405))

;; Data Variables
(define-data-var next-permit-id uint u1)
(define-data-var permit-fee uint u2000000) ;; 2 STX
(define-data-var permit-duration uint u26280) ;; ~6 months in blocks
(define-data-var next-inspection-id uint u1)

;; Data Maps
(define-map health-permits uint {
  vendor: principal,
  permit-type: (string-ascii 50),
  issue-date: uint,
  expiry-date: uint,
  status: (string-ascii 20),
  last-inspection: uint,
  grade: (string-ascii 2),
  inspector: principal,
  violations: uint
})

(define-map vendor-permits principal uint)
(define-map health-inspectors principal bool)

(define-map inspections uint {
  permit-id: uint,
  inspector: principal,
  inspection-date: uint,
  grade: (string-ascii 2),
  violations-found: uint,
  notes: (string-ascii 500),
  follow-up-required: bool
})

(define-map permit-inspections uint (list 20 uint))

;; Public Functions

;; Apply for health permit
(define-public (apply-for-permit (permit-type (string-ascii 50)))
  (let (
    (permit-id (var-get next-permit-id))
    (fee (var-get permit-fee))
  )
    ;; Check if vendor already has a permit
    (asserts! (is-none (map-get? vendor-permits tx-sender)) ERR-ALREADY-HAS-PERMIT)

    ;; Pay permit fee
    (try! (stx-transfer? fee tx-sender (as-contract tx-sender)))

    ;; Create permit record
    (map-set health-permits permit-id {
      vendor: tx-sender,
      permit-type: permit-type,
      issue-date: block-height,
      expiry-date: (+ block-height (var-get permit-duration)),
      status: "pending-inspection",
      last-inspection: u0,
      grade: "",
      inspector: tx-sender,
      violations: u0
    })

    ;; Map vendor to permit
    (map-set vendor-permits tx-sender permit-id)

    ;; Increment permit ID
    (var-set next-permit-id (+ permit-id u1))

    (ok permit-id)
  )
)

;; Conduct health inspection (inspector only)
(define-public (conduct-inspection (permit-id uint) (grade (string-ascii 2)) (violations uint) (notes (string-ascii 500)))
  (begin
    ;; Check if caller is authorized inspector
    (asserts! (default-to false (map-get? health-inspectors tx-sender)) ERR-NOT-AUTHORIZED)

    ;; Validate grade
    (asserts! (or (is-eq grade "A") (is-eq grade "B") (is-eq grade "C") (is-eq grade "F")) ERR-INVALID-GRADE)

    (let (
      (permit-data-opt (map-get? health-permits permit-id))
      (inspection-id (var-get next-inspection-id))
    )
      (asserts! (is-some permit-data-opt) ERR-PERMIT-NOT-FOUND)

      (let (
        (permit-data (unwrap-panic permit-data-opt))
        (new-status (if (or (is-eq grade "A") (is-eq grade "B")) "active" "suspended"))
      )
        ;; Create inspection record
        (map-set inspections inspection-id {
          permit-id: permit-id,
          inspector: tx-sender,
          inspection-date: block-height,
          grade: grade,
          violations-found: violations,
          notes: notes,
          follow-up-required: (> violations u0)
        })

        ;; Add inspection to permit's inspection list
        (let (
          (current-inspections (default-to (list) (map-get? permit-inspections permit-id)))
        )
          (map-set permit-inspections permit-id
            (unwrap-panic (as-max-len? (append current-inspections inspection-id) u20)))
        )

        ;; Update permit
        (map-set health-permits permit-id (merge permit-data {
          status: new-status,
          last-inspection: block-height,
          grade: grade,
          inspector: tx-sender,
          violations: violations
        }))

        ;; Increment inspection ID
        (var-set next-inspection-id (+ inspection-id u1))

        (ok inspection-id)
      )
    )
  )
)

;; Renew health permit
(define-public (renew-permit)
  (let (
    (permit-id-opt (map-get? vendor-permits tx-sender))
    (fee (var-get permit-fee))
  )
    (asserts! (is-some permit-id-opt) ERR-PERMIT-NOT-FOUND)

    (let (
      (permit-id (unwrap-panic permit-id-opt))
      (permit-data (unwrap-panic (map-get? health-permits permit-id)))
    )
      ;; Pay renewal fee
      (try! (stx-transfer? fee tx-sender (as-contract tx-sender)))

      ;; Update permit expiry and status
      (map-set health-permits permit-id (merge permit-data {
        expiry-date: (+ block-height (var-get permit-duration)),
        status: "pending-inspection"
      }))

      (ok true)
    )
  )
)

;; Report violation (inspector only)
(define-public (report-violation (permit-id uint) (violation-details (string-ascii 500)))
  (begin
    (asserts! (default-to false (map-get? health-inspectors tx-sender)) ERR-NOT-AUTHORIZED)

    (let (
      (permit-data-opt (map-get? health-permits permit-id))
    )
      (asserts! (is-some permit-data-opt) ERR-PERMIT-NOT-FOUND)

      (let (
        (permit-data (unwrap-panic permit-data-opt))
        (new-violations (+ (get violations permit-data) u1))
      )
        ;; Update permit with new violation count
        (map-set health-permits permit-id (merge permit-data {
          violations: new-violations,
          status: (if (> new-violations u3) "suspended" (get status permit-data))
        }))

        (ok true)
      )
    )
  )
)

;; Read-only Functions

;; Get permit details
(define-read-only (get-permit (permit-id uint))
  (map-get? health-permits permit-id)
)

;; Get vendor's permit
(define-read-only (get-vendor-permit (vendor principal))
  (let (
    (permit-id-opt (map-get? vendor-permits vendor))
  )
    (if (is-some permit-id-opt)
      (map-get? health-permits (unwrap-panic permit-id-opt))
      none
    )
  )
)

;; Check if permit is valid
(define-read-only (is-permit-valid (permit-id uint))
  (let (
    (permit-data-opt (map-get? health-permits permit-id))
  )
    (if (is-some permit-data-opt)
      (let (
        (permit-data (unwrap-panic permit-data-opt))
      )
        (and
          (is-eq (get status permit-data) "active")
          (> (get expiry-date permit-data) block-height)
        )
      )
      false
    )
  )
)

;; Get inspection details
(define-read-only (get-inspection (inspection-id uint))
  (map-get? inspections inspection-id)
)

;; Get permit inspections
(define-read-only (get-permit-inspections (permit-id uint))
  (map-get? permit-inspections permit-id)
)

;; Check if user is health inspector
(define-read-only (is-health-inspector (user principal))
  (default-to false (map-get? health-inspectors user))
)

;; Get permit fee
(define-read-only (get-permit-fee)
  (var-get permit-fee)
)

;; Admin Functions

;; Add health inspector (owner only)
(define-public (add-health-inspector (inspector principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set health-inspectors inspector true)
    (ok true)
  )
)

;; Remove health inspector (owner only)
(define-public (remove-health-inspector (inspector principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-delete health-inspectors inspector)
    (ok true)
  )
)

;; Update permit fee (owner only)
(define-public (set-permit-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set permit-fee new-fee)
    (ok true)
  )
)

;; Update permit duration (owner only)
(define-public (set-permit-duration (new-duration uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set permit-duration new-duration)
    (ok true)
  )
)

;; Suspend permit (owner only)
(define-public (suspend-permit (permit-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (let (
      (permit-data-opt (map-get? health-permits permit-id))
    )
      (asserts! (is-some permit-data-opt) ERR-PERMIT-NOT-FOUND)

      (let (
        (permit-data (unwrap-panic permit-data-opt))
      )
        (map-set health-permits permit-id (merge permit-data {
          status: "suspended"
        }))

        (ok true)
      )
    )
  )
)
