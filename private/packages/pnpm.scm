(define-module (private packages pnpm)
  #:use-module (gnu packages base)
  #:use-module ((gnu packages bootstrap) #:select (glibc-dynamic-linker))
  #:use-module (gnu packages elf)
  #:use-module (gnu packages gcc)
  #:use-module (guix build-system copy)
  #:use-module (guix download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages))

(define-public pnpm
  (package
    (name "pnpm")
    (version "12.9.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/pnpm/pnpm/releases/download/v" version
             "/pnpm-linux-arm64.tar.gz"))
       (file-name (string-append "pnpm-" version "-linux-arm64.tar.gz"))
       (sha256
        (base32 "03bk3mdbi311ajkxdrv2rlqblzi7n7prr9z4qs4rilikfsvr90j6"))))
    (build-system copy-build-system)
    (native-inputs
     `(("patchelf" ,patchelf)
       ("license"
        ,(origin
           (method url-fetch)
           (uri (string-append
                 "https://raw.githubusercontent.com/pnpm/pnpm/v"
                 version "/LICENSE"))
           (file-name "pnpm-LICENSE")
           (sha256
            (base32
             "1navy9s5427xvbdxhgh015b8q2fx36zwmsgc6k8b4n17a1bjm3jb"))))))
    (inputs `(("glibc" ,glibc) ("gcc:lib" ,gcc "lib")))
    (arguments
     `(#:strip-binaries? #f
       ;; The helper files use Node.js from PATH, not a bundled runtime.
       #:install-plan '(("pnpm" "bin/pnpm") ("dist" "bin/dist"))
       #:phases
       (modify-phases %standard-phases
         ;; The archive has multiple top-level entries.
         (replace 'unpack
           (lambda* (#:key source #:allow-other-keys)
             (invoke "tar" "-xzf" source)))
         (add-after 'unpack 'patch-elf
           (lambda* (#:key inputs #:allow-other-keys)
             (let ((ld-so (search-input-file inputs ,(glibc-dynamic-linker)))
                   (libc (search-input-file inputs "lib/libc.so.6"))
                   (libgcc (search-input-file inputs "lib/libgcc_s.so.1")))
               (invoke "patchelf" "--set-interpreter" ld-so
                       "--set-rpath"
                       (string-join (list (dirname libc) (dirname libgcc)) ":")
                       "pnpm"))))
         (add-after 'install 'install-license
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (install-file (assoc-ref inputs "license")
                           (string-append (assoc-ref outputs "out")
                                          "/share/doc/pnpm"))))
         (add-after 'install-license 'check-installed
           (lambda* (#:key outputs tests? #:allow-other-keys)
             (use-modules (ice-9 popen) (ice-9 rdelim))
             (when tests?
               (let* ((pnpm (string-append (assoc-ref outputs "out") "/bin/pnpm"))
                      (home (string-append (getcwd) "/test-home"))
                      (project (string-append (getcwd) "/test-project")))
                 (mkdir-p home)
                 (mkdir-p project)
                 (setenv "HOME" home)
                 (setenv "XDG_CACHE_HOME" (string-append home "/.cache"))
                 (setenv "XDG_CONFIG_HOME" (string-append home "/.config"))
                 (setenv "XDG_DATA_HOME" (string-append home "/.local/share"))
                 (let* ((pipe (open-pipe* OPEN_READ pnpm "--version"))
                        (actual (read-line pipe))
                        (status (close-pipe pipe)))
                   (unless (and (zero? status) (string=? actual ,version))
                     (error "unexpected pnpm version" actual)))
                 (invoke pnpm "--help")
                 (with-directory-excursion project
                   (mkdir-p "dependency")
                   (call-with-output-file "dependency/package.json"
                     (lambda (port)
                       (display "{\"name\":\"local-dependency\",\"version\":\"1.0.0\"}" port)))
                   (call-with-output-file "package.json"
                     (lambda (port)
                       (display "{\"name\":\"offline-check\",\"version\":\"1.0.0\",\"dependencies\":{\"local-dependency\":\"file:./dependency\"}}" port)))
                   (invoke pnpm "install" "--offline" "--ignore-scripts")
                   (unless (file-exists? "node_modules/local-dependency/package.json")
                     (error "local dependency is missing"))))))))))
    (supported-systems (list "aarch64-linux"))
    (synopsis "Fast, disk space efficient JavaScript package manager")
    (description
     "pnpm installs JavaScript packages with a content-addressed store.  This
package provides the upstream native executable and its node-gyp helper files.
It does not include Node.js.  Project scripts use the runtime in the environment
unless project settings request a managed runtime.")
    (home-page "https://pnpm.io/")
    (license license:expat)))
