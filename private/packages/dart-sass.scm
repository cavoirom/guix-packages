(define-module (private packages dart-sass)
  #:use-module (gnu packages base)
  #:use-module ((gnu packages bootstrap)
                #:select (glibc-dynamic-linker))
  #:use-module (gnu packages elf)
  #:use-module (guix build-system copy)
  #:use-module (guix download)
  #:use-module ((guix licenses)
                #:prefix license:)
  #:use-module (guix packages))

(define dart-sass-version
  "1.100.0")

(define dart-sass-platform
  "linux-arm64")

(define-public dart-sass
  (package
    (name "dart-sass")
    (version dart-sass-version)
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/sass/dart-sass/releases/download/"
             dart-sass-version
             "/dart-sass-"
             dart-sass-version
             "-"
             dart-sass-platform
             ".tar.gz"))
       (file-name (string-append "dart-sass-" dart-sass-version "-"
                                 dart-sass-platform ".tar.gz"))
       ;; Update version and hash together; never fetch a moving latest archive.
       (sha256
        (base32 "188fd99mirg9g82vs8xh2y997rhy67w1wccvq3vm27r0ixfgxw2j"))))
    (build-system copy-build-system)
    ;; The upstream release bundles a shell wrapper, Dart runtime, and Sass snapshot.
    (native-inputs (list patchelf))
    (inputs (list glibc))
    (arguments
     `(#:phases (modify-phases %standard-phases
                  ;; Patch the bundled Dart runtime so it resolves glibc through
                  ;; Guix store paths while preserving Sass's wrapper/snapshot layout.
                  (add-after 'unpack 'patch-elf
                    (lambda* (#:key inputs #:allow-other-keys)
                      (let ((ld-so (search-input-file inputs
                                                      ,(glibc-dynamic-linker)))
                            (glibc-lib (dirname (search-input-file inputs
                                                 "lib/libc.so.6"))))
                        (invoke "patchelf"
                                "--set-interpreter"
                                ld-so
                                "--set-rpath"
                                glibc-lib
                                "src/dart"))))
                  (replace 'install
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (libexec (string-append out "/libexec/dart-sass"))
                             (bin (string-append out "/bin")))
                        (mkdir-p libexec)
                        (copy-recursively "." libexec)
                        (mkdir-p bin)
                        (call-with-output-file (string-append bin "/sass")
                          (lambda (port)
                            (display (string-append "#!"
                                      (which "sh")
                                      "\n"
                                      "exec \""
                                      libexec
                                      "/src/dart\" "
                                      "\""
                                      libexec
                                      "/src/sass.snapshot\" \"$@\"\n") port)))
                        (chmod (string-append bin "/sass") #o755)
                        #t))))))
    ;; The source artifact is dart-sass-linux-arm64, not a portable release.
    (supported-systems (list "aarch64-linux"))
    (synopsis "Sass compiler written in Dart")
    (description
     "Dart Sass is the primary implementation of Sass.  This package installs
the upstream standalone Dart Sass release, including its bundled Dart runtime
and Sass snapshot.")
    (home-page "https://sass-lang.com/dart-sass")
    (license (list license:expat license:bsd-3))))
