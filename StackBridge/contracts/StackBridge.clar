;; StacksBridge DEX - Decentralized Exchange for Bitcoin Layer 2 and Stacks Assets
;; Core AMM functionality with liquidity pools and cross-layer trading

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-INSUFFICIENT-LIQUIDITY (err u102))
(define-constant ERR-SLIPPAGE-EXCEEDED (err u103))
(define-constant ERR-POOL-NOT-FOUND (err u104))
(define-constant ERR-INSUFFICIENT-BALANCE (err u105))
(define-constant ERR-ZERO-AMOUNT (err u106))
(define-constant ERR-INVALID-TOKEN (err u107))

;; Scaling factor for precision (10^6)
(define-constant PRECISION u1000000)
(define-constant FEE-RATE u300) ;; 0.3% fee (300/1000000)

;; Data structures
(define-map pools 
  { token-a: principal, token-b: principal }
  { 
    reserve-a: uint,
    reserve-b: uint,
    total-supply: uint,
    fee-to: (optional principal)
  }
)

(define-map user-liquidity
  { user: principal, token-a: principal, token-b: principal }
  { liquidity-tokens: uint }
)

(define-map supported-tokens
  principal
  { 
    name: (string-ascii 32),
    symbol: (string-ascii 8),
    decimals: uint,
    is-layer2: bool
  }
)

;; Events
(define-data-var swap-events (list 100 {
  user: principal,
  token-in: principal,
  token-out: principal,
  amount-in: uint,
  amount-out: uint,
  fee: uint
}) (list))

;; Initialize supported tokens
(define-public (add-supported-token (token principal) (name (string-ascii 32)) (symbol (string-ascii 8)) (decimals uint) (is-layer2 bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (ok (map-set supported-tokens token {
      name: name,
      symbol: symbol,
      decimals: decimals,
      is-layer2: is-layer2
    }))
  )
)

;; Helper functions
(define-private (get-pool-key (token-a principal) (token-b principal))
  (if (< (get-token-id token-a) (get-token-id token-b))
    { token-a: token-a, token-b: token-b }
    { token-a: token-b, token-b: token-a }
  )
)

(define-private (get-token-id (token principal))
  (let ((token-parts (unwrap-panic (principal-destruct? token))))
    (+ (len (get hash-bytes token-parts)) 
       (len (default-to "" (get name token-parts))))
  )
)

(define-private (sqrt (x uint))
  (if (is-eq x u0)
    u0
    (if (<= x u1)
      u1
      (if (<= x u4)
        u2
        (if (<= x u9)
          u3
          (if (<= x u16)
            u4
            (if (<= x u25)
              u5
              (if (<= x u36)
                u6
                (if (<= x u49)
                  u7
                  (if (<= x u64)
                    u8
                    (if (<= x u81)
                      u9
                      (if (<= x u100)
                        u10
                        ;; For larger numbers, use approximation
                        (let ((approx (/ x u10)))
                          (if (<= (* approx approx) x)
                            approx
                            (- approx u1)
                          )
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)

;; Create liquidity pool
(define-public (create-pool (token-a principal) (token-b principal) (amount-a uint) (amount-b uint))
  (let (
    (pool-key (get-pool-key token-a token-b))
    (sorted-token-a (get token-a pool-key))
    (sorted-token-b (get token-b pool-key))
    (sorted-amount-a (if (is-eq token-a sorted-token-a) amount-a amount-b))
    (sorted-amount-b (if (is-eq token-a sorted-token-a) amount-b amount-a))
    (liquidity (sqrt (* sorted-amount-a sorted-amount-b)))
  )
    (asserts! (> amount-a u0) ERR-ZERO-AMOUNT)
    (asserts! (> amount-b u0) ERR-ZERO-AMOUNT)
    (asserts! (is-none (map-get? pools pool-key)) ERR-POOL-NOT-FOUND)
    (asserts! (is-some (map-get? supported-tokens token-a)) ERR-INVALID-TOKEN)
    (asserts! (is-some (map-get? supported-tokens token-b)) ERR-INVALID-TOKEN)
    
    ;; Note: In production, implement proper SIP-010 token transfers
    ;; For now, we'll simulate the transfers with print statements
    (print { action: "transfer", token: sorted-token-a, amount: sorted-amount-a, from: tx-sender, to: (as-contract tx-sender) })
    (print { action: "transfer", token: sorted-token-b, amount: sorted-amount-b, from: tx-sender, to: (as-contract tx-sender) })
    
    ;; Create pool
    (map-set pools pool-key {
      reserve-a: sorted-amount-a,
      reserve-b: sorted-amount-b,
      total-supply: liquidity,
      fee-to: none
    })
    
    ;; Mint liquidity tokens to user
    (map-set user-liquidity 
      { user: tx-sender, token-a: sorted-token-a, token-b: sorted-token-b }
      { liquidity-tokens: liquidity }
    )
    
    (ok liquidity)
  )
)

;; Add liquidity to existing pool
(define-public (add-liquidity (token-a principal) (token-b principal) (amount-a uint) (amount-b uint) (min-liquidity uint))
  (let (
    (pool-key (get-pool-key token-a token-b))
    (sorted-token-a (get token-a pool-key))
    (sorted-token-b (get token-b pool-key))
    (pool-data (unwrap! (map-get? pools pool-key) ERR-POOL-NOT-FOUND))
    (reserve-a (get reserve-a pool-data))
    (reserve-b (get reserve-b pool-data))
    (total-supply (get total-supply pool-data))
    (sorted-amount-a (if (is-eq token-a sorted-token-a) amount-a amount-b))
    (sorted-amount-b (if (is-eq token-a sorted-token-a) amount-b amount-a))
    (liquidity-a (/ (* sorted-amount-a total-supply) reserve-a))
    (liquidity-b (/ (* sorted-amount-b total-supply) reserve-b))
    (liquidity (if (< liquidity-a liquidity-b) liquidity-a liquidity-b))
    (current-liquidity (default-to u0 (get liquidity-tokens (map-get? user-liquidity { user: tx-sender, token-a: sorted-token-a, token-b: sorted-token-b }))))
  )
    (asserts! (> sorted-amount-a u0) ERR-ZERO-AMOUNT)
    (asserts! (> sorted-amount-b u0) ERR-ZERO-AMOUNT)
    (asserts! (>= liquidity min-liquidity) ERR-SLIPPAGE-EXCEEDED)
    
    ;; Simulate token transfers
    (print { action: "transfer", token: sorted-token-a, amount: sorted-amount-a, from: tx-sender, to: (as-contract tx-sender) })
    (print { action: "transfer", token: sorted-token-b, amount: sorted-amount-b, from: tx-sender, to: (as-contract tx-sender) })
    
    ;; Update pool reserves
    (map-set pools pool-key {
      reserve-a: (+ reserve-a sorted-amount-a),
      reserve-b: (+ reserve-b sorted-amount-b),
      total-supply: (+ total-supply liquidity),
      fee-to: (get fee-to pool-data)
    })
    
    ;; Update user liquidity
    (map-set user-liquidity 
      { user: tx-sender, token-a: sorted-token-a, token-b: sorted-token-b }
      { liquidity-tokens: (+ current-liquidity liquidity) }
    )
    
    (ok liquidity)
  )
)

;; Remove liquidity from pool
(define-public (remove-liquidity (token-a principal) (token-b principal) (liquidity uint) (min-amount-a uint) (min-amount-b uint))
  (let (
    (pool-key (get-pool-key token-a token-b))
    (sorted-token-a (get token-a pool-key))
    (sorted-token-b (get token-b pool-key))
    (pool-data (unwrap! (map-get? pools pool-key) ERR-POOL-NOT-FOUND))
    (user-liq-data (unwrap! (map-get? user-liquidity { user: tx-sender, token-a: sorted-token-a, token-b: sorted-token-b }) ERR-INSUFFICIENT-LIQUIDITY))
    (user-liquidity-tokens (get liquidity-tokens user-liq-data))
    (reserve-a (get reserve-a pool-data))
    (reserve-b (get reserve-b pool-data))
    (total-supply (get total-supply pool-data))
    (amount-a-out (/ (* liquidity reserve-a) total-supply))
    (amount-b-out (/ (* liquidity reserve-b) total-supply))
    (final-amount-a (if (is-eq token-a sorted-token-a) amount-a-out amount-b-out))
    (final-amount-b (if (is-eq token-a sorted-token-a) amount-b-out amount-a-out))
  )
    (asserts! (> liquidity u0) ERR-ZERO-AMOUNT)
    (asserts! (>= user-liquidity-tokens liquidity) ERR-INSUFFICIENT-LIQUIDITY)
    (asserts! (>= final-amount-a min-amount-a) ERR-SLIPPAGE-EXCEEDED)
    (asserts! (>= final-amount-b min-amount-b) ERR-SLIPPAGE-EXCEEDED)
    
    ;; Simulate token transfers to user
    (print { action: "transfer", token: sorted-token-a, amount: amount-a-out, from: (as-contract tx-sender), to: tx-sender })
    (print { action: "transfer", token: sorted-token-b, amount: amount-b-out, from: (as-contract tx-sender), to: tx-sender })
    
    ;; Update pool reserves
    (map-set pools pool-key {
      reserve-a: (- reserve-a amount-a-out),
      reserve-b: (- reserve-b amount-b-out),
      total-supply: (- total-supply liquidity),
      fee-to: (get fee-to pool-data)
    })
    
    ;; Update user liquidity
    (map-set user-liquidity 
      { user: tx-sender, token-a: sorted-token-a, token-b: sorted-token-b }
      { liquidity-tokens: (- user-liquidity-tokens liquidity) }
    )
    
    (ok { amount-a: final-amount-a, amount-b: final-amount-b })
  )
)

;; Calculate swap output amount
(define-read-only (get-amount-out (amount-in uint) (reserve-in uint) (reserve-out uint))
  (let (
    (amount-in-with-fee (- (* amount-in (- PRECISION FEE-RATE)) (/ (* amount-in FEE-RATE) PRECISION)))
    (numerator (* amount-in-with-fee reserve-out))
    (denominator (+ (* reserve-in PRECISION) amount-in-with-fee))
  )
    (/ numerator denominator)
  )
)

;; Swap tokens
(define-public (swap-tokens (token-in principal) (token-out principal) (amount-in uint) (min-amount-out uint))
  (let (
    (pool-key (get-pool-key token-in token-out))
    (sorted-token-a (get token-a pool-key))
    (sorted-token-b (get token-b pool-key))
    (pool-data (unwrap! (map-get? pools pool-key) ERR-POOL-NOT-FOUND))
    (reserve-a (get reserve-a pool-data))
    (reserve-b (get reserve-b pool-data))
    (is-token-a-in (is-eq token-in sorted-token-a))
    (reserve-in (if is-token-a-in reserve-a reserve-b))
    (reserve-out (if is-token-a-in reserve-b reserve-a))
    (amount-out (get-amount-out amount-in reserve-in reserve-out))
    (fee-amount (/ (* amount-in FEE-RATE) PRECISION))
  )
    (asserts! (> amount-in u0) ERR-ZERO-AMOUNT)
    (asserts! (>= amount-out min-amount-out) ERR-SLIPPAGE-EXCEEDED)
    (asserts! (< amount-out reserve-out) ERR-INSUFFICIENT-LIQUIDITY)
    
    ;; Simulate token transfers
    (print { action: "transfer", token: token-in, amount: amount-in, from: tx-sender, to: (as-contract tx-sender) })
    (print { action: "transfer", token: token-out, amount: amount-out, from: (as-contract tx-sender), to: tx-sender })
    
    ;; Update pool reserves
    (map-set pools pool-key {
      reserve-a: (if is-token-a-in (+ reserve-a amount-in) (- reserve-a amount-out)),
      reserve-b: (if is-token-a-in (- reserve-b amount-out) (+ reserve-b amount-in)),
      total-supply: (get total-supply pool-data),
      fee-to: (get fee-to pool-data)
    })
    
    (ok { amount-out: amount-out, fee: fee-amount })
  )
)

;; Read-only functions
(define-read-only (get-pool-info (token-a principal) (token-b principal))
  (let ((pool-key (get-pool-key token-a token-b)))
    (map-get? pools pool-key)
  )
)

(define-read-only (get-user-liquidity (user principal) (token-a principal) (token-b principal))
  (let ((pool-key (get-pool-key token-a token-b)))
    (map-get? user-liquidity { user: user, token-a: (get token-a pool-key), token-b: (get token-b pool-key) })
  )
)

(define-read-only (get-supported-token (token principal))
  (map-get? supported-tokens token)
)

(define-read-only (calculate-swap-output (token-in principal) (token-out principal) (amount-in uint))
  (let (
    (pool-key (get-pool-key token-in token-out))
    (pool-data (unwrap! (map-get? pools pool-key) ERR-POOL-NOT-FOUND))
    (reserve-a (get reserve-a pool-data))
    (reserve-b (get reserve-b pool-data))
    (is-token-a-in (is-eq token-in (get token-a pool-key)))
    (reserve-in (if is-token-a-in reserve-a reserve-b))
    (reserve-out (if is-token-a-in reserve-b reserve-a))
  )
    (ok (get-amount-out amount-in reserve-in reserve-out))
  )
)

;; Cross-layer bridge functions (placeholder for L2 integration)
(define-public (initiate-l2-bridge (token principal) (amount uint) (l2-address (buff 32)))
  (begin
    (asserts! (is-some (map-get? supported-tokens token)) ERR-INVALID-TOKEN)
    (asserts! (get is-layer2 (unwrap-panic (map-get? supported-tokens token))) ERR-INVALID-TOKEN)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    
    ;; Simulate locking tokens in contract for L2 bridge
    (print { action: "lock-for-bridge", token: token, amount: amount, from: tx-sender, to: (as-contract tx-sender) })
    
    ;; Emit bridge event (in real implementation, this would trigger L2 mint)
    (print { event: "l2-bridge-initiated", token: token, amount: amount, l2-address: l2-address, user: tx-sender })
    
    (ok amount)
  )
)

;; Admin functions
(define-public (set-fee-recipient (token-a principal) (token-b principal) (recipient principal))
  (let ((pool-key (get-pool-key token-a token-b)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (match (map-get? pools pool-key)
      pool-data (ok (map-set pools pool-key (merge pool-data { fee-to: (some recipient) })))
      ERR-POOL-NOT-FOUND
    )
  )
)