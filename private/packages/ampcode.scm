(define-module (private packages ampcode)
  #:use-module (gnu packages base)
  #:use-module (gnu packages gcc)
  #:use-module (guix build-system copy)
  #:use-module (guix download)
  #:use-module (guix packages))

;; Get new version: curl -s https://static.ampcode.com/cli/cli-version.txt
(define ampcode-version
  "0.0.1786019606-geb05a8")

(define ampcode-platform
  "linux-arm64")

(define-public ampcode
  (package
    (name "ampcode")
    (version ampcode-version)
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://static.ampcode.com/cli/" ampcode-version
                           "/amp-" ampcode-platform))
       (file-name (string-append "ampcode-" ampcode-version "-" ampcode-platform))
       ;; Update version and hash together; never fetch a moving latest binary.
       ;; Get new hash: guix download https://static.ampcode.com/cli/$(curl -s https://static.ampcode.com/cli/cli-version.txt)/amp-linux-arm64
       (sha256
        (base32 "0dcyr243bvv2lh3kjkr2yhcgav6d5r10dznadcgihf7s0jwx9y54"))))
    (build-system copy-build-system)
    ;; This upstream binary is built for conventional Linux/FHS and is expected
    ;; to run through `guix shell --emulate-fhs`.
    (propagated-inputs
     (list glibc
           ;; Keep GCC runtime libraries in the FHS environment for the
           ;; prebuilt executable; they may look unused to the build phase.
	   ;; prebuilt executable; propagate so `guix shell ampcode` includes it.
           (list gcc "lib")))
    (arguments
     `(#:install-plan '((,(string-append "ampcode-" ampcode-version "-"
                                           ampcode-platform) "bin/amp"))
       ;; Runpath validation fails because Amp expects FHS loader/library paths.
       #:validate-runpath? #f
       ;; Do not strip: Bun standalone executables embed their JS payload in the
       ;; binary, and strip can remove it.
       #:strip-binaries? #f
       #:phases (modify-phases %standard-phases
                  (add-after 'install 'make-executable
                    (lambda* (#:key outputs #:allow-other-keys)
                      (chmod (string-append (assoc-ref outputs "out")
                                            "/bin/amp") #o755) #t)))))
    ;; The source artifact is amp-linux-arm64, not a portable release.
    (supported-systems (list "aarch64-linux"))
    (synopsis "Amp CLI - The frontier coding agent")
    (description
     "Amp is the frontier coding agent built for leading models, and what comes next.")
    (home-page "https://ampcode.com")
    ;; Upstream license/redistribution terms should be verified before wider use.
    (license #f)))
