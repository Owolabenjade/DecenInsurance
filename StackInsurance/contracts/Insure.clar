(define-data-var insured-party principal none)
(define-data-var insurer principal none)
(define-data-var policy-premium uint 0)
(define-data-var policy-coverage uint 0)
(define-data-var policy-expiration uint 0)
(define-data-var eligible-for-payout bool false)

(define-constant grace-period 1000) ;; Grace period for premium payments (in blocks)
(define-constant max-coverage 100000) ;; Maximum coverage amount in microSTX

(define-map insurance-policies
  { insured-party: principal }
  { policy-premium: uint, policy-coverage: uint, total-claims: uint, policy-expiration: uint, policy-active: bool })

(define-map insurance-claims
  { insured-party: principal }
  { claim-requested: uint, claim-approved: bool })

;; Helper function: Get the current block height
(define-read-only (get-block-height) (ok (as-max-len u100000)))

;; Create a new insurance policy
(define-public (initiate-policy (new-insurer principal) (new-insured-party principal) (premium-amount uint) (coverage-amount uint))
  (begin
    (if (> coverage-amount max-coverage)
      (err "Coverage exceeds maximum allowed")
      (if (is-eq (var-get insurer) none)
        (begin
          (map-set insurance-policies
            { insured-party: new-insured-party }
            { policy-premium: premium-amount, policy-coverage: coverage-amount, total-claims: u0, policy-expiration: 0, policy-active: false })
          (var-set insurer new-insurer)
          (var-set insured-party new-insured-party)
          ;; Logging event (using print)
          (print {event: "insurance-policy-created", insured-party: new-insured-party, premium: premium-amount, coverage: coverage-amount})
          (ok (some "Policy initiated successfully")))
        (err "An active policy already exists for this insured party")))))

;; Pay the premium to activate/renew the policy
(define-public (submit-premium (insured principal))
  (let (
      (policy-data (map-get? insurance-policies { insured-party: insured }))
      (current-height (get-block-height))
    )
    (match policy-data
      (some active-policy)
        (begin
          (if (and (is-eq (get policy-active active-policy) true)
                   (<= (get policy-expiration active-policy) (+ current-height grace-period)))
            (begin
              ;; Payment logic: insured must send policy-premium amount in STX
              (stx-transfer? (get policy-premium active-policy) tx-sender (var-get insurer))
              ;; Renew policy for one year (in blocks)
              (map-set insurance-policies
                { insured-party: insured }
                { policy-premium: (get policy-premium active-policy),
                  policy-coverage: (get policy-coverage active-policy),
                  total-claims: (get total-claims active-policy),
                  policy-expiration: (+ current-height 52595), ;; 52595 blocks ~ 1 year
                  policy-active: true })
              ;; Logging event (using print)
              (print {event: "premium-paid", insured-party: insured, premium: (get policy-premium active-policy), expiration: (+ current-height 52595)})
              (ok "Premium submitted and policy renewed successfully"))
            (err "Policy is expired and cannot be renewed"))
        )
      (none (err "Policy not found")))))

;; Submit a claim based on the insured policy
(define-public (submit-claim (insured principal) (claim-amount uint))
  (let (
      (policy-data (map-get? insurance-policies { insured-party: insured }))
    )
    (match policy-data
      (some active-policy)
        (begin
          ;; Check if policy is active and claim does not exceed coverage
          (if (and (is-eq (get policy-active active-policy) true)
                   (>= (get policy-coverage active-policy) (+ (get total-claims active-policy) claim-amount)))
            (begin
              (map-set insurance-claims { insured-party: insured } { claim-requested: claim-amount, claim-approved: false })
              ;; Logging event (using print)
              (print {event: "claim-filed", insured-party: insured, claim-amount: claim-amount})
              (ok "Claim submitted successfully"))
            (err "Claim exceeds coverage or policy is inactive"))
        )
      (none (err "Policy not found")))))

;; Approve a filed claim by the insurer
(define-public (approve-claim (insured principal))
  (let (
      (claim-data (map-get? insurance-claims { insured-party: insured }))
    )
    (match claim-data
      (some filed-claim)
        (begin
          (map-set insurance-claims { insured-party: insured } { claim-requested: (get claim-requested filed-claim), claim-approved: true })
          ;; Logging event (using print)
          (print {event: "claim-approved", insured-party: insured, claim-amount: (get claim-requested filed-claim)})
          (ok "Claim approved"))
      (none (err "Claim not found")))))

;; Release payout after claim approval
(define-public (release-payout (insured principal))
  (let (
      (claim-data (map-get? insurance-claims { insured-party: insured }))
      (policy-data (map-get? insurance-policies { insured-party: insured }))
    )
    (match claim-data
      (some approved-claim)
        (begin
          (if (is-eq (get claim-approved approved-claim) true)
            (begin
              ;; Ensure payout does not exceed policy coverage
              (map-set insurance-policies
                { insured-party: insured }
                { policy-premium: (get policy-premium policy-data),
                  policy-coverage: (get policy-coverage policy-data),
                  total-claims: (+ (get total-claims policy-data) (get claim-requested approved-claim)),
                  policy-expiration: (get policy-expiration policy-data),
                  policy-active: (get policy-active policy-data) })
              ;; Transfer STX to insured as payout
              (stx-transfer? (get claim-requested approved-claim) (var-get insurer) insured)
              ;; Logging event (using print)
              (print {event: "payout-released", insured-party: insured, payout-amount: (get claim-requested approved-claim)})
              (ok "Payout released successfully"))
            (err "Claim not yet approved"))
        )
      (none (err "Claim not found")))))
