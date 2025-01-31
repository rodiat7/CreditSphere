;; CreditSphere: Social Credit Protocol
;; A decentralized lending platform based on social credit with community governance

;; Constants
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-VALUE (err u101))
(define-constant ERR-NO-FUNDS (err u102))
(define-constant ERR-INSUFFICIENT-CREDIT (err u103))
(define-constant ERR-EXISTING-LOAN (err u104))
(define-constant ERR-BAD-PROPOSAL (err u105))
(define-constant ERR-DUPLICATE-PROPOSAL (err u106))
(define-constant ERR-VOTE-PERIOD-ENDED (err u107))
(define-constant ERR-DUPLICATE-VOTE (err u108))
(define-constant ERR-INVALID-USER (err u109))
(define-constant ERR-INVALID-CREDIT-VALUE (err u110))
(define-constant ERR-EMPTY-JUSTIFICATION (err u111))
(define-constant ERR-INVALID-ACTIVITY (err u112))

(define-constant MIN-CREDIT-THRESHOLD u500) ;; Out of 1000
(define-constant CREDIT-DEDUCTION u100)
(define-constant LOAN-CAP u1000000) ;; In microSTX
(define-constant VOTE-DURATION u1440) ;; ~10 days with 10min blocks
(define-constant QUORUM-REQUIREMENT u10)
(define-constant GOVERNANCE-THRESHOLD u700) ;; Min credit for governance
(define-constant MAX-CREDIT u1000)
(define-constant MAX-ACTIVITY-SCORE u100)
(define-constant MAX-STAKE-SCORE u100)

;; Data Maps
(define-map member-credit 
    principal 
    {
        rating: uint,
        loans-completed: uint,
        community-activity: uint,
        stake-duration: uint
    }
)

(define-map current-loans
    principal
    {
        value: uint,
        expiry-block: uint,
        settled: bool
    }
)

(define-map token-holdings principal uint)

;; Governance Maps
(define-map credit-appeals
    uint
    {
        initiator: principal,
        subject: principal,
        proposed-rating: uint,
        justification: (string-ascii 256),
        support-count: uint,
        oppose-count: uint,
        deadline: uint,
        completed: bool
    }
)

(define-map appeal-votes
    {appeal-id: uint, participant: principal}
    bool
)

(define-data-var appeal-counter uint u0)

;; Validation Functions
(define-private (validate-credit-rating (rating uint))
    (and (>= rating u0) (<= rating MAX-CREDIT))
)

(define-private (validate-activity (score uint))
    (<= score MAX-ACTIVITY-SCORE)
)

(define-private (validate-subject (member principal))
    (is-some (get-credit member))
)

;; Governance Functions

(define-public (submit-appeal 
    (subject principal)
    (proposed-rating uint)
    (justification (string-ascii 256)))
    (let (
        (caller tx-sender)
        (appeal-id (var-get appeal-counter))
        (initiator-credit (unwrap! (get-credit caller) ERR-UNAUTHORIZED))
    )
        (asserts! (validate-subject subject) ERR-INVALID-USER)
        (asserts! (validate-credit-rating proposed-rating) ERR-INVALID-CREDIT-VALUE)
        (asserts! (not (is-eq justification "")) ERR-EMPTY-JUSTIFICATION)
        (asserts! (>= (get rating initiator-credit) GOVERNANCE-THRESHOLD) ERR-UNAUTHORIZED)
        
        (map-set credit-appeals appeal-id {
            initiator: caller,
            subject: subject,
            proposed-rating: proposed-rating,
            justification: justification,
            support-count: u0,
            oppose-count: u0,
            deadline: (+ block-height VOTE-DURATION),
            completed: false
        })
        
        (var-set appeal-counter (+ appeal-id u1))
        (ok appeal-id)
    )
)

(define-public (cast-vote (appeal-id uint) (support bool))
    (let (
        (caller tx-sender)
        (appeal (unwrap! (map-get? credit-appeals appeal-id) ERR-BAD-PROPOSAL))
        (voter-credit (unwrap! (get-credit caller) ERR-UNAUTHORIZED))
        (updated-appeal (merge appeal {
            support-count: (if support (+ (get support-count appeal) u1) (get support-count appeal)),
            oppose-count: (if support (get oppose-count appeal) (+ (get oppose-count appeal) u1))
        }))
    )
        (asserts! (>= (get rating voter-credit) GOVERNANCE-THRESHOLD) ERR-UNAUTHORIZED)
        (asserts! (< block-height (get deadline appeal)) ERR-VOTE-PERIOD-ENDED)
        (asserts! (is-none (map-get? appeal-votes {appeal-id: appeal-id, participant: caller})) ERR-DUPLICATE-VOTE)
        
        (map-set appeal-votes {appeal-id: appeal-id, participant: caller} support)
        
        (map-set credit-appeals appeal-id updated-appeal)
        
        (try! (update-credit-components caller u1 u0))
        (ok true)
    )
)

(define-public (finalize-appeal (appeal-id uint))
    (let (
        (appeal (unwrap! (map-get? credit-appeals appeal-id) ERR-BAD-PROPOSAL))
        (vote-sum (+ (get support-count appeal) (get oppose-count appeal)))
    )
        (asserts! (>= block-height (get deadline appeal)) ERR-UNAUTHORIZED)
        (asserts! (not (get completed appeal)) ERR-UNAUTHORIZED)
        (asserts! (>= vote-sum QUORUM-REQUIREMENT) ERR-UNAUTHORIZED)
        (asserts! (validate-credit-rating (get proposed-rating appeal)) ERR-INVALID-CREDIT-VALUE)
        
        (if (> (get support-count appeal) (get oppose-count appeal))
            (begin
                (try! (set-credit (get subject appeal) (get proposed-rating appeal)))
                (map-set credit-appeals appeal-id
                    (merge appeal {completed: true})
                )
                (ok true)
            )
            (ok false)
        )
    )
)

;; Private function to set credit directly
(define-private (set-credit (member principal) (new-rating uint))
    (let (
        (current-credit (unwrap! (get-credit member) ERR-UNAUTHORIZED))
    )
        (asserts! (validate-credit-rating new-rating) ERR-INVALID-CREDIT-VALUE)
        (ok (map-set member-credit member
            (merge current-credit {rating: new-rating})
        ))
    )
)

;; Core Lending Functions

(define-public (create-credit-profile (member principal))
    (let ((existing-profile (get-credit member)))
        (if (is-none existing-profile)
            (ok (map-set member-credit member {
                rating: u500,
                loans-completed: u0,
                community-activity: u0,
                stake-duration: u0
            }))
            ERR-UNAUTHORIZED
        )
    )
)

(define-private (compute-credit-score 
    (completed-loans uint) 
    (activity-score uint)
    (stake-score uint))
    (let (
        (loan-points (* completed-loans u100))
        (activity-bonus (* activity-score u50))
        (stake-bonus (* stake-score u50))
        (total-rating (+ (+ loan-points activity-bonus) stake-bonus))
    )
        (if (> total-rating MAX-CREDIT)
            MAX-CREDIT
            total-rating
        )
    )
)

(define-public (update-credit-components
    (member principal)
    (activity-points uint)
    (stake-points uint))
    (let (
        (current-credit (unwrap! (get-credit member) ERR-UNAUTHORIZED))
    )
        (asserts! (validate-subject member) ERR-INVALID-USER)
        (asserts! (validate-activity activity-points) ERR-INVALID-ACTIVITY)
        (asserts! (validate-activity stake-points) ERR-INVALID-ACTIVITY)
        
        (asserts! (validate-activity (get community-activity current-credit)) ERR-INVALID-ACTIVITY)
        (asserts! (validate-activity (get stake-duration current-credit)) ERR-INVALID-ACTIVITY)
        
        (let (
            (new-activity (+ (get community-activity current-credit) activity-points))
            (new-stake (+ (get stake-duration current-credit) stake-points))
            (current-completed (get loans-completed current-credit))
        )
            (asserts! (validate-activity new-activity) ERR-INVALID-ACTIVITY)
            (asserts! (validate-activity new-stake) ERR-INVALID-ACTIVITY)
            
            (let (
                (new-rating (compute-credit-score 
                    current-completed
                    new-activity
                    new-stake))
            )
                (asserts! (validate-credit-rating new-rating) ERR-INVALID-CREDIT-VALUE)
                (ok (map-set member-credit member
                    {
                        rating: new-rating,
                        loans-completed: current-completed,
                        community-activity: new-activity,
                        stake-duration: new-stake
                    }
                ))
            )
        )
    )
)

(define-public (borrow (value uint))
    (let (
        (caller tx-sender)
        (credit (unwrap! (get-credit caller) ERR-UNAUTHORIZED))
        (existing-loan (get-active-loan caller))
    )
        (asserts! (<= value LOAN-CAP) ERR-INVALID-VALUE)
        (asserts! (>= (get rating credit) MIN-CREDIT-THRESHOLD) ERR-INSUFFICIENT-CREDIT)
        (asserts! (is-none existing-loan) ERR-EXISTING-LOAN)
        
        (map-set current-loans caller {
            value: value,
            expiry-block: (+ block-height u1440),
            settled: false
        })
        
        (ok (as-contract (stx-transfer? value (as-contract tx-sender) caller)))
    )
)

(define-public (settle-loan)
    (let (
        (caller tx-sender)
        (loan (unwrap! (get-active-loan caller) ERR-UNAUTHORIZED))
        (credit (unwrap! (get-credit caller) ERR-UNAUTHORIZED))
    )
        (asserts! (not (get settled loan)) ERR-UNAUTHORIZED)
        (try! (stx-transfer? (get value loan) caller (as-contract tx-sender)))
        
        (map-set current-loans caller {
            value: (get value loan),
            expiry-block: (get expiry-block loan),
            settled: true
        })
        
        (ok (map-set member-credit caller {
            rating: (+ (get rating credit) u50),
            loans-completed: (+ (get loans-completed credit) u1),
            community-activity: (get community-activity credit),
            stake-duration: (get stake-duration credit)
        }))
    )
)

(define-public (verify-loan (member principal))
    (let (
        (loan (unwrap! (get-active-loan member) ERR-UNAUTHORIZED))
        (credit (unwrap! (get-credit member) ERR-UNAUTHORIZED))
    )
        (if (and 
            (> block-height (get expiry-block loan))
            (not (get settled loan))
        )
            (ok (map-set member-credit member {
                rating: (- (get rating credit) CREDIT-DEDUCTION),
                loans-completed: (get loans-completed credit),
                community-activity: (get community-activity credit),
                stake-duration: (get stake-duration credit)
            }))
            (ok true)
        )
    )
)

;; Getter Functions

(define-read-only (get-credit (member principal))
    (map-get? member-credit member)
)

(define-read-only (get-active-loan (member principal))
    (map-get? current-loans member)
)

(define-read-only (get-tokens (member principal))
    (default-to u0 (map-get? token-holdings member))
)

(define-read-only (get-appeal (appeal-id uint))
    (map-get? credit-appeals appeal-id)
)

(define-read-only (get-appeal-vote (appeal-id uint) (participant principal))
    (map-get? appeal-votes {appeal-id: appeal-id, participant: participant})
)