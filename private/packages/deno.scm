(define-module (private packages deno)
  #:use-module (gnu packages base)
  #:use-module ((gnu packages bootstrap) #:select (glibc-dynamic-linker))
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages gcc)
  #:use-module (guix build-system copy)
  #:use-module (guix download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages))

(define deno-version
  "2.8.1")

(define deno-platform
  "aarch64-unknown-linux-gnu")

(define-public deno
  (package
    (name "deno")
    (version deno-version)
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/denoland/deno/releases/download/v"
             deno-version "/deno-" deno-platform ".zip"))
       (file-name (string-append "deno-" deno-version "-" deno-platform ".zip"))
       ;; Update version and hash together; never fetch a moving latest archive.
       (sha256
        (base32 "1mhg1l3xcrb0p0xkqb3fjpv7zsh960z1f97r1mqazl0ghy8xzsb7"))))
    (build-system copy-build-system)
    ;; The upstream release is a zip archive containing the prebuilt Rust binary.
    (native-inputs (list patchelf unzip))
    (inputs
     (list (list "glibc" glibc)
           ;; Rust binaries can depend on libgcc_s for unwinding.
           (list "gcc:lib" gcc "lib")))
    (arguments
     `(#:install-plan '(("deno" "bin/deno"))
       #:phases (modify-phases %standard-phases
                  ;; Patch the conventional Linux ELF metadata so Deno can run
                  ;; without FHS emulation and still pass Guix runpath checks.
                  (add-after 'unpack 'patch-elf
                    (lambda* (#:key inputs #:allow-other-keys)
                      (let ((ld-so (search-input-file
                                    inputs ,(glibc-dynamic-linker)))
                            (glibc-lib (dirname
                                        (search-input-file inputs
                                                           "lib/libc.so.6")))
                            (gcc-lib (dirname
                                      (search-input-file inputs
                                                         "lib/libgcc_s.so.1"))))
                        (invoke "patchelf"
                                "--set-interpreter" ld-so
                                "--set-rpath" (string-join
                                                (list glibc-lib gcc-lib) ":")
                                "deno"))))
                  (add-after 'install 'make-executable
                    (lambda* (#:key outputs #:allow-other-keys)
                      (chmod (string-append (assoc-ref outputs "out")
                                            "/bin/deno") #o755) #t)))))
    ;; The source artifact is aarch64-unknown-linux-gnu, not a portable release.
    (supported-systems (list "aarch64-linux"))
    (synopsis "Modern runtime for JavaScript and TypeScript")
    (description
     "Deno is a simple, modern, and secure runtime for JavaScript and TypeScript.")
    (home-page "https://deno.com")
    (license license:expat)))
