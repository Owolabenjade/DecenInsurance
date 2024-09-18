;; Decentralized Insurance Smart Contract in Clarity

;; Constants
(define-constant grace-period u1000)        ;; Grace period for premium payments (in blocks)
(define-constant max-coverage u1000000)     ;; Maximum coverage amount in microSTX (1 STX = 1,000,000 microSTX)

;; Data Maps
(define-map insurance-policies
  { insured-party: principal }
  { insurer: principal,
    policy-premium: uint,
    policy-coverage: uint,
    total-claims: uint,
    policy-expiration: uint,
    policy-active: bool })

(define-map insurance-claims
  { insured-party: principal }
  { claim-requested: uint,
    claim-approved: bool })

;; Public Functions

;; 1. Initiate a New Insurance Policy
(define-public (initiate-policy (new-insurer principal) (new-insured-party principal) (premium-amount uint) (coverage-amount uint))
  (begin
    ;; Check if coverage exceeds maximum allowed
    (if (> coverage-amount max-coverage)
        (err "Coverage exceeds maximum allowed")
        ;; Check if a policy already exists for the insured party
        (if (is-some (map-get? insurance-policies { insured-party: new-insured-party }))
            (err "An active policy already exists for this insured party")
            (begin
              ;; Store the new policy
              (map-set insurance-policies
                { insured-party: new-insured-party }
                { insurer: new-insurer,
                  policy-premium: premium-amount,
                  policy-coverage: coverage-amount,
                  total-claims: u0,
                  policy-expiration: u0,
                  policy-active: false })
              ;; Log the event
              (print {event: "insurance-policy-created",
                      insured-party: new-insured-party,
                      insurer: new-insurer,
                      premium: premium-amount,
                      coverage: coverage-amount})
              (ok "Policy initiated successfully"))))))

;; 2. Submit Premium to Activate/Renew Policy
(define-public (submit-premium (insured principal))
  (let ((policy-data (map-get? insurance-policies { insured-party: insured }))
        (current-height block-height))
    (if (is-some policy-data)
        (let ((active-policy (unwrap! policy-data (err "Policy unwrap failed"))))
          ;; Check if policy is inactive or due for renewal
          (if (or (not (get policy-active active-policy))
                  (<= (get policy-expiration active-policy) (+ current-height grace-period)))
              (begin
                ;; Transfer premium amount to the insurer
                (unwrap! (stx-transfer? (get policy-premium active-policy) tx-sender (get insurer active-policy)) "Transfer failed")
                ;; Update the policy to active and set new expiration
                (map-set insurance-policies
                  { insured-party: insured }
                  (merge active-policy
                         { policy-expiration: (+ current-height u52595),  ;; Approximately one year
                           policy-active: true }))
                ;; Log the event
                (print {event: "premium-paid",
                        insured-party: insured,
                        premium: (get policy-premium active-policy),
                        expiration: (+ current-height u52595)})
                (ok "Premium submitted and policy renewed successfully"))
              (err "Policy is active and not due for renewal")))
        (err "Policy not found"))))

;; 3. Submit an Insurance Claim
(define-public (submit-claim (insured principal) (claim-amount uint))
  (let ((policy-data (map-get? insurance-policies { insured-party: insured })))
    (if (is-some policy-data)
        (let ((active-policy (unwrap! policy-data (err "Policy unwrap failed"))))
          ;; Check if policy is active and claim does not exceed coverage
          (if (and (get policy-active active-policy)
                   (<= (+ (get total-claims active-policy) claim-amount)
                       (get policy-coverage active-policy)))
              (begin
                ;; Store the claim
                (map-set insurance-claims
                  { insured-party: insured }
                  { claim-requested: claim-amount,
                    claim-approved: false })
                ;; Log the event
                (print {event: "claim-filed",
                        insured-party: insured,
                        claim-amount: claim-amount})
                (ok "Claim submitted successfully"))
              (err "Claim exceeds coverage or policy is inactive")))
        (err "Policy not found"))))

;; 4. Approve a Submitted Claim
(define-public (approve-claim (insured principal))
  (let ((claim-data (map-get? insurance-claims { insured-party: insured })))
    (if (is-some claim-data)
        (let ((filed-claim (unwrap! claim-data (err "Claim unwrap failed"))))
          ;; Approve the claim
          (map-set insurance-claims
            { insured-party: insured }
            { claim-requested: (get claim-requested filed-claim),
              claim-approved: true })
          ;; Log the event
          (print {event: "claim-approved",
                  insured-party: insured,
                  claim-amount: (get claim-requested filed-claim)})
          (ok "Claim approved"))
        (err "Claim not found"))))

;; 5. Release Payout After Claim Approval
(define-public (release-payout (insured principal))
  (let ((claim-data (map-get? insurance-claims { insured-party: insured }))
        (policy-data (map-get? insurance-policies { insured-party: insured })))
    (if (and (is-some claim-data) (is-some policy-data))
        (let ((approved-claim (unwrap! claim-data (err "Claim unwrap failed")))
              (policy (unwrap! policy-data (err "Policy unwrap failed"))))
          ;; Check if the claim is approved
          (if (is-eq (get claim-approved approved-claim) true)
              (let ((new-total-claims (+ (get total-claims policy) (get claim-requested approved-claim))))
                ;; Ensure total claims do not exceed coverage
                (if (<= new-total-claims (get policy-coverage policy))
                    (begin
                      ;; Update the policy's total claims
                      (map-set insurance-policies
                        { insured-party: insured }
                        (merge policy { total-claims: new-total-claims }))
                      ;; Transfer payout amount to the insured
                      (unwrap! (stx-transfer? (get claim-requested approved-claim) (get insurer policy) insured) "Transfer failed")
                      ;; Log the event
                      (print {event: "payout-released",
                              insured-party: insured,
                              payout-amount: (get claim-requested approved-claim)})
                      (ok "Payout released successfully"))
                    (err "Payout exceeds policy coverage")))
              (err "Claim not yet approved")))
        (err "Claim or Policy not found"))))
