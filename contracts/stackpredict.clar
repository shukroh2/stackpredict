;; stackpredict.clar
;; A decentralized prediction market for Stacks

;; --------------------------------
;; ERRORS
;; --------------------------------
(define-constant ERR_NOT_OWNER u100)
(define-constant ERR_NOT_FOUND u101)
(define-constant ERR_EVENT_CLOSED u102)
(define-constant ERR_EVENT_OPEN u103)
(define-constant ERR_INVALID_SIDE u104)
(define-constant ERR_ALREADY_VOTED u105)
(define-constant ERR_NO_BALANCE u106)

;; --------------------------------
;; DATA VARIABLES
;; --------------------------------
(define-data-var owner principal tx-sender)
(define-data-var next-event-id uint u0)
(define-data-var fee-rate uint u2) ;; 2% platform fee

;; --------------------------------
;; MAPS
;; --------------------------------
(define-map events
  uint
  (tuple
    (creator principal)
    (question (string-ascii 128))
    (yes-pool uint)
    (no-pool uint)
    (open bool)
    (winning-side (optional bool)) ;; none = undecided
  )
)

(define-map bets
  (tuple (event-id uint) (user principal))
  (tuple
    (side bool)
    (amount uint)
    (claimed bool)
  )
)

(define-data-var total-fees uint u0)

;; --------------------------------
;; PRIVATE HELPERS
;; --------------------------------
(define-private (only-owner)
  (if (is-eq tx-sender (var-get owner))
      (ok true)
      (err ERR_NOT_OWNER))
)

;; --------------------------------
;; PUBLIC FUNCTIONS
;; --------------------------------

;; Create new prediction event
(define-public (create-event (question (string-ascii 128)))
  (let ((id (+ (var-get next-event-id) u1)))
    (map-set events id
      (tuple
        (creator tx-sender)
        (question question)
        (yes-pool u0)
        (no-pool u0)
        (open true)
        (winning-side none)))
    (var-set next-event-id id)
    (ok (tuple (event-id id) (question question))))
)

;; Place bet (side = true for YES, false for NO)
(define-public (place-bet (event-id uint) (side bool) (amount uint))
  (let ((ev (map-get? events event-id)))
    (match ev
      e
        (if (get open e)
            (if (> amount u0)
                (if (is-some (map-get? bets (tuple (event-id event-id) (user tx-sender))))
                    (err ERR_ALREADY_VOTED)
                    (begin
                      (try! (stx-transfer? amount tx-sender tx-sender))
                      (map-set bets (tuple (event-id event-id) (user tx-sender))
                        (tuple (side side) (amount amount) (claimed false)))
                      (if side
                          (map-set events event-id
                            (tuple
                              (creator (get creator e))
                              (question (get question e))
                              (yes-pool (+ (get yes-pool e) amount))
                              (no-pool (get no-pool e))
                              (open (get open e))
                              (winning-side (get winning-side e))))
                          (map-set events event-id
                            (tuple
                              (creator (get creator e))
                              (question (get question e))
                              (yes-pool (get yes-pool e))
                              (no-pool (+ (get no-pool e) amount))
                              (open (get open e))
                              (winning-side (get winning-side e)))))
                      (ok "Bet placed")))
                (err ERR_INVALID_SIDE))
            (err ERR_EVENT_CLOSED))
      (err ERR_NOT_FOUND)))
)

;; Close event (admin declares winning side)
(define-public (close-event (event-id uint) (winning-side bool))
  (let ((check (only-owner)))
    (if (is-ok check)
      (let ((ev (map-get? events event-id)))
        (match ev
          e
            (if (get open e)
                (begin
                  (map-set events event-id
                    (tuple
                      (creator (get creator e))
                      (question (get question e))
                      (yes-pool (get yes-pool e))
                      (no-pool (get no-pool e))
                      (open false)
                      (winning-side (some winning-side))))
                  (ok "Event closed"))
                (err ERR_EVENT_CLOSED))
          (err ERR_NOT_FOUND)))
      (err ERR_NOT_OWNER)))
)

;; Claim reward after event is closed
(define-public (claim-reward (event-id uint))
  (let ((ev (map-get? events event-id))
        (user-bet (map-get? bets (tuple (event-id event-id) (user tx-sender)))))
    (match ev
      e
        (if (not (get open e))
            (match user-bet
              ub
                (if (and (not (get claimed ub))
                         (is-some (get winning-side e))
                         (is-eq (some (get side ub)) (get winning-side e)))
                    (begin
                      (let (
                        (total-pool (+ (get yes-pool e) (get no-pool e)))
                        (win-pool (if (get side ub) (get yes-pool e) (get no-pool e)))
                        (user-share (/ (* (get amount ub) total-pool) win-pool))
                        (fee (/ (* user-share (var-get fee-rate)) u100))
                        (reward (- user-share fee))
                      )
                        (try! (stx-transfer? reward tx-sender tx-sender))
                        (var-set total-fees (+ (var-get total-fees) fee))
                        (map-set bets (tuple (event-id event-id) (user tx-sender))
                          (tuple
                            (side (get side ub))
                            (amount (get amount ub))
                            (claimed true)))
                        (ok (tuple (reward reward)))))
                    (err ERR_NO_BALANCE))
              (err ERR_NO_BALANCE))
            (err ERR_EVENT_OPEN))
      (err ERR_NOT_FOUND)))
)

;; Admin withdraw platform fees
(define-public (withdraw-fees (to principal))
  (let ((check (only-owner)))
    (if (is-ok check)
      (let ((f (var-get total-fees)))
        (if (> f u0)
            (begin
              (try! (stx-transfer? f tx-sender to))
              (var-set total-fees u0)
              (ok (tuple (withdrawn f))))
            (err ERR_NO_BALANCE)))
      (err ERR_NOT_OWNER)))
)

;; --------------------------------
;; READ-ONLY FUNCTIONS
;; --------------------------------
(define-read-only (get-event (id uint))
  (map-get? events id)
)

(define-read-only (get-bet (event-id uint) (user principal))
  (map-get? bets (tuple (event-id event-id) (user user)))
)

(define-read-only (get-fee-rate)
  (var-get fee-rate)
)
