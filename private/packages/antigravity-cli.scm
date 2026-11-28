(define-module (private packages antigravity-cli)
  #:use-module (gnu packages bash)
  #:use-module (guix build-system copy)
  #:use-module (guix download)
  #:use-module (guix packages))

;; Get the version and archive URL from Google's installer manifest:
;; curl -fsSL https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_arm64_musl.json

;; The musl build is static: it has no program interpreter and no dynamic
;; section, so it runs without FHS emulation or patchelf.  The glibc build
;; embeds a ripgrep that needs /usr/grte/v5/lib/ld-linux-aarch64.so.1.
(define-public antigravity-cli
  (package
    (name "antigravity-cli")
    (version "1.5.19")
    (source
     (origin
       (method url-fetch)
       (uri "https://storage.googleapis.com/antigravity-public/antigravity-cli/1.5.19-4821414830800896/linux-arm-musl/cli_linux_arm64_musl.tar.gz")
       (file-name (string-append name "-" version "-linux_arm64_musl.tar.gz"))
       ;; Update the version, archive URL, and hash together.  Use the manifest
       ;; only to look up releases, not as a build source.
       ;; Get new hash: guix download <the archive URL above>
       (sha256
        (base32 "1nrkn67n3xm8w7c51agmwi8snb7lf2j0pc8mskmi89rki45y9ss5"))))
    (build-system copy-build-system)
    (inputs (list bash-minimal))
    (arguments
     `(#:modules ((guix build copy-build-system)
                  (guix build utils)
                  (ice-9 popen)
                  (ice-9 textual-ports))
       ;; The upstream binary is already stripped.  Keep the store copy
       ;; identical to the upstream checksum.
       #:strip-binaries? #f
       #:phases
       (modify-phases %standard-phases
         (replace 'install
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin"))
                    (libexec (string-append out "/libexec/antigravity-cli"))
                    (real-agy (string-append libexec "/agy"))
                    (agy (string-append bin "/agy"))
                    (bash (search-input-file inputs "bin/bash")))
               (mkdir-p libexec)
               (copy-file "antigravity" real-agy)
               (chmod real-agy #o755)
               (mkdir-p bin)
               ;; The self-updater downloads an unpinned release and replaces
               ;; the running executable.  Guix must supply all updates.
               (call-with-output-file agy
                 (lambda (port)
                   (display (string-append "#!" bash "\n"
                                           "export AGY_CLI_DISABLE_AUTO_UPDATE=true\n"
                                           "exec \"" real-agy "\" \"$@\"\n")
                            port)))
               (chmod agy #o755))))
         (add-after 'install 'check-installed
           (lambda* (#:key outputs tests? #:allow-other-keys)
             (when tests?
               (let ((agy (string-append (assoc-ref outputs "out") "/bin/agy"))
                     (home (string-append (getcwd) "/test-home")))
                 (mkdir-p home)
                 (setenv "HOME" home)
                 (let* ((port (open-pipe* OPEN_READ agy "--version"))
                        (reported (string-trim-right (get-string-all port)))
                        (status (close-pipe port)))
                   (format #t "Antigravity CLI version: ~a~%" reported)
                   (unless (and (zero? status)
                                (string=? reported ,version))
                     (error "unexpected agy version" reported status)))
                 (invoke agy "--help"))))))))
    ;; The source artifact contains a static AArch64 musl executable.
    (supported-systems (list "aarch64-linux"))
    (synopsis "Terminal coding agent from Google Antigravity")
    (description
     "Antigravity CLI (@command{agy}) is a terminal interface to the Google
Antigravity agent.  It reads a codebase, edits files with permission, and runs
commands.  This package installs the static musl build from the upstream
release.  The self-updater is disabled.  The CLI uses its embedded ripgrep for
code search.")
    (home-page "https://antigravity.google/product/antigravity-cli")
    ;; Upstream publishes no license file; Google's terms of service apply.
    (license #f)))
