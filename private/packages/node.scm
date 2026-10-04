(define-module (private packages node)
  #:use-module ((gnu packages node) #:prefix upstream:)
  #:use-module (guix packages))

;; Compatibility baseline: gnu/packages/node.scm, node-lts 24.18.0.
;; Guix commit: 64d4de2a920445e5992f020e56490f5fcbdbba7c
;; https://codeberg.org/guix/guix/src/commit/64d4de2a920445e5992f020e56490f5fcbdbba7c/gnu/packages/node.scm
;; This record does not pin the inherited package.  Before updating it, compare
;; the new recipe, inherited phases, and dependencies, then validate the build.
(define-public node-22
  (package
    (inherit upstream:node-lts)
    (name "node")
    (version "22.23.3")
    (source
     (origin
       (inherit (package-source upstream:node-lts))
       (uri (string-append "https://nodejs.org/dist/v" version
                           "/node-v" version ".tar.xz"))
       ;; Retain upstream cleanup.  Its V8 template fix has no match in Node 22,
       ;; where Tuple calls in this header do not use explicit template arguments.
       (sha256
        (base32 "02b9x7amig32k4jwxim94q4lwkd6jfk79hahi4rl74hy38z0k5xx"))))))
