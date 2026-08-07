(define-module (private packages unison-lang)
  #:use-module (gnu packages bash)
  #:use-module ((gnu packages bootstrap)
                #:select (glibc-dynamic-linker))
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages less)
  #:use-module (gnu packages multiprecision)
  #:use-module (gnu packages ncurses)
  #:use-module (guix build-system copy)
  #:use-module (guix download)
  #:use-module ((guix licenses)
                #:prefix license:)
  #:use-module (guix packages))

(define unison-lang-version
  "1.3.0")

(define unison-lang-platform
  "linux-arm64")

(define-public unison-lang
  (package
    (name "unison-lang")
    (version unison-lang-version)
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/unisonweb/unison/releases/download/release/"
             unison-lang-version "/ucm-" unison-lang-platform ".tar.gz"))
       (file-name (string-append "unison-lang-" unison-lang-version "-"
                                 unison-lang-platform ".tar.gz"))
       ;; The outer release archive pins both UCM and its bundled web UI.
       (sha256
        (base32 "1jhwp0mdifblhypk85yrb1hsmykjpnywbzah31jicimhhgq6nx79"))))
    (build-system copy-build-system)
    (native-inputs (list patchelf))
    (inputs (list bash-minimal
                  gmp
                  less
                  ncurses
                  zlib))
    (arguments
     `(#:phases (modify-phases %standard-phases
                  (delete 'make-dynamic-linker-cache)
                  ;; The release archive has several top-level entries.  Avoid
                  ;; the generic unpack phase changing into one of them.
                  (replace 'unpack
                    (lambda* (#:key source #:allow-other-keys)
                      (invoke "tar" "-xzf" source)))
                  ;; Patch the conventional Linux executable to use Guix's dynamic
                  ;; linker and store paths.
                  (add-after 'unpack 'patch-elf
                    (lambda* (#:key inputs #:allow-other-keys)
                      (let* ((ld-so (search-input-file inputs
                                                       ,(glibc-dynamic-linker)))
                             (rpath (string-join
                                     (cons (dirname ld-so)
                                           (map (lambda (file)
                                                  (dirname (search-input-file
                                                            inputs file)))
                                                '("lib/libgmp.so.10"
                                                  "lib/libncursesw.so.6"
                                                  "lib/libz.so.1")))
                                     ":")))
                        (invoke "patchelf"
                                "--set-interpreter"
                                ld-so
                                "--set-rpath"
                                rpath
                                "unison/unison"))))
                  (replace 'install
                    (lambda* (#:key inputs outputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (bin (string-append out "/bin"))
                             (libexec (string-append out "/libexec/unison"))
                             (real-ucm (string-append libexec "/unison"))
                             (share (string-append out "/share/unison"))
                             (ui (string-append share "/ui"))
                             (ucm (string-append bin "/ucm"))
                             (bash (search-input-file inputs "bin/bash"))
                             (less-bin (dirname (search-input-file inputs
                                                                   "bin/less"))))
                        (mkdir-p bin)
                        (mkdir-p libexec)
                        (install-file "unison/unison" libexec)
                        (mkdir-p share)
                        (copy-recursively "ui" ui)
                        (call-with-output-file ucm
                          (lambda (port)
                            (display (string-append "#!"
                                                    bash
                                                    "\n"
                                                    "export UCM_WEB_UI=\""
                                                    ui
                                                    "\"\n"
                                                    "export PATH=\""
                                                    less-bin
                                                    "${PATH:+:$PATH}\"\n"
                                                    "exec \""
                                                    real-ucm
                                                    "\" \"$@\"\n") port)))
                        (chmod ucm #o755))))
                  (add-after 'install 'check-installed
                    (lambda* (#:key outputs tests? #:allow-other-keys)
                      (when tests?
                        (let* ((out (assoc-ref outputs "out"))
                               (ucm (string-append out "/bin/ucm"))
                               (ui-index (string-append out
                                          "/share/unison/ui/index.html"))
                               (home (string-append (getcwd) "/test-home")))
                          (unless (file-exists? ui-index)
                            (error "bundled web UI is missing" ui-index))
                          (mkdir-p home)
                          (setenv "HOME" home)
                          (invoke ucm "version")
                          (invoke ucm "--help"))))))))
    ;; The source artifact contains prebuilt native code for AArch64 Linux.
    (supported-systems (list "aarch64-linux"))
    (synopsis "Codebase manager for the Unison programming language")
    (description
     "Unison is a statically typed functional programming language based on
content-addressed code.  This package installs the Unison Codebase Manager and
its bundled local web interface from the official upstream release.")
    (home-page "https://www.unison-lang.org/")
    (license (list license:expat license:bsd-3))))
