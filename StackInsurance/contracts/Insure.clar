(define-data-var insured-party principal none)
(define-data-var insurer principal none)
(define-data-var policy-premium uint u0)
(define-data-var policy-coverage uint u0)
(define-data-var policy-expiration uint u0)
(define-data-var eligible-for-payout bool false)

(define-constant grace-period u1000) ;; Grace period for premium payments (in blocks)
(define-constant max-coverage u100000) ;; Maximum coverage amount in microSTX

(define-map insurance-policies
  { insured-party: principal }
  { policy-premium: uint, policy-coverage: uint, total-claims: uint, policy-expiration: uint, policy-active: bool })

(define-map insurance-claims
  { insured-party: principal }
  { claim-requested: uint, claim-approved: bool })

;; Create a new insurance policy
(define-public (initiate-policy (new-insurer principal) (new-insured-party principal) (premium-amount uint) (coverage-amount uint))
  (begin
    (if (> coverage-amount max-coverage)
        (err "Coverage exceeds maximum allowed")
        (if (is-eq (var-get insurer) none)
            (begin
              (map-set insurance-policies
                { insured-party: new-insured-party }
                { policy-premium: premium-amount, policy-coverage: coverage-amount, total-claims: u0, policy-expiration: u0, policy-active: false })
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
      (current-height block-height)
    )
    (if (is-some policy-data)
        (let ((active-policy (unwrap! policy-data (err "Policy unwrap failed"))))
          (if (or (not (get policy-active active-policy))
                  (<= (get policy-expiration active-policy) (+ current-height grace-period)))
              (begin
                ;; Payment logic: insured must send policy-premium amount in STX
                (try! (stx-transfer? (get policy-premium active-policy) tx-sender (var-get insurer)))
                ;; Renew policy for one year (in blocks)
                (map-set insurance-policies
                  { insured-party: insured }
                  { policy-premium: (get policy-premium active-policy),
                    policy-coverage: (get policy-coverage active-policy),
                    total-claims: (get total-claims active-policy),
                    policy-expiration: (+ current-height u52595), ;; 52595 blocks ~ 1 year
                    policy-active: true })
                ;; Logging event (using print)
                (print {event: "premium-paid", insured-party: insured, premium: (get policy-premium active-policy), expiration: (+ current-height u52595)})
                (ok "Premium submitted and policy renewed successfully"))
              (err "Policy is active and not due for renewal")))
        (err "Policy not found"))))

;; Submit a claim based on the insured policy
(define-public (submit-claim (insured principal) (claim-amount uint))
  (let (
      (policy-data (map-get? insurance-policies { insured-party: insured }))
    )
    (if (is-some policy-data)
        (let ((active-policy (unwrap! policy-data (err "Policy unwrap failed"))))
          ;; Check if policy is active and claim does not exceed coverage
          (if (and (get policy-active active-policy)
                   (<= (+ (get total-claims active-policy) claim-amount) (get policy-coverage active-policy)))
              (begin
                (map-set insurance-claims { insured-party: insured } { claim-requested: claim-amount, claim-approved: false })
                ;; Logging event (using print)
                (print {event: "claim-filed", insured-party: insured, claim-amount: claim-amount})
                (ok "Claim submitted successfully"))
              (err "Claim exceeds coverage or policy is inactive")))
        (err "Policy not found"))))

;; Approve a filed claim by the insurer
(define-public (approve-claim (insured principal))
  (let (
      (claim-data (map-get? insurance-claims { insured-party: insured }))
    )
    (if (is-some claim-data)
        (let ((filed-claim (unwrap! claim-data (err "Claim unwrap failed"))))
          (map-set insurance-claims { insured-party: insured } { claim-requested: (get claim-requested filed-claim), claim-approved: true })
          ;; Logging event (using print)
          (print {event: "claim-approved", insured-party: insured, claim-amount: (get claim-requested filed-claim)})
          (ok "Claim approved"))
        (err "Claim not found"))))

;; Release payout after claim approval
(define-public (release-payout (insured principal))
  (let (
      (claim-data (map-get? insurance-claims { insured-party: insured }))
      (policy-data (map-get? insurance-policies { insured-party: insured }))
    )
    (if (and (is-some claim-data) (is-some policy-data))
        (let (
            (approved-claim (unwrap! claim-data (err "Claim unwrap failed")))
            (policy (unwrap! policy-data (err "Policy unwrap failed")))
          )
          (if (is-eq (get claim-approved approved-claim) true)
              (let (
                  (new-total-claims (+ (get total-claims policy) (get claim-requested approved-claim)))
                )
                (if (<= new-total-claims (get policy-coverage policy))
                    (begin
                      ;; Update the policy's total claims
                      (map-set insurance-policies
                        { insured-party: insured }
                        { policy-premium: (get policy-premium policy),
                          policy-coverage: (get policy-coverage policy),
                          total-claims: new-total-claims,
                          policy-expiration: (get policy-expiration policy),
                          policy-active: (get policy-active policy) })
                      ;; Transfer STX to insured as payout
                      (try! (stx-transfer? (get claim-requested approved-claim) (var-get insurer) insured))
                      ;; Logging event (using print)
                      (print {event: "payout-released", insured-party: insured, payout-amount: (get claim-requested approved-claim)})
                      (ok "Payout released successfully"))
                    (err "Payout exceeds policy coverage")))
              (err "Claim not yet approved")))
        (err "Claim or Policy not found"))))
