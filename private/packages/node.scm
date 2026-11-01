(define-module (private packages node)
  #:use-module ((gnu packages node) #:prefix upstream:)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix utils))

;; Compatibility baseline: gnu/packages/node.scm, node-lts 24.22.1.
;; Guix commit: 2e29152dd9b31e606dbe008c779774ba052799a7
;; https://codeberg.org/guix/guix/src/commit/2e29152dd9b31e606dbe008c779774ba052799a7/gnu/packages/node.scm
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
       ;; Node 22 needs dependencies which node-lts 24.22.1 removes.
       (snippet
        '(begin
           (for-each delete-file-recursively
                     (find-files "deps/openssl"
                                 (lambda (file stat)
                                   (not (string-contains
                                         file "nodejs-openssl.cnf")))))
           (for-each delete-file-recursively
                     '("deps/brotli"
                       "deps/cares"
                       "deps/icu-small"
                       "deps/nghttp2"
                       "deps/ngtcp2"
                       "deps/llhttp"
                       "deps/uv"
                       "deps/zlib"
                       "deps/zstd"))))
       (sha256
        (base32 "02b9x7amig32k4jwxim94q4lwkd6jfk79hahi4rl74hy38z0k5xx"))))
    (arguments
     (substitute-keyword-arguments (package-arguments upstream:node-lts)
       ;; Node 22 configure does not accept the last four options.  Node 22
       ;; tests expect its bundled ada, not the newer shared one.
       ((#:configure-flags flags)
        #~(filter (lambda (flag)
                    (not (member flag '("--shared-ada"
                                        "--shared-gtest"
                                        "--shared-hdr-histogram"
                                        "--shared-merve"
                                        "--shared-nbytes"))))
                  #$flags))))))
