(define-module (private packages k)
  #:use-module (gnu packages bash)
  #:use-module (guix build-system copy)
  #:use-module (guix git-download)
  #:use-module (guix packages)
  #:use-module ((private packages unison-lang)
                #:select (unison-lang-1.3)))

(define k-version
  "0.1.0")

(define k-commit
  "5cde77c4a6889191c3959e47057cee340440351c")

(define-public k
  (package
    (name "k")
    (version k-version)
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/cavoirom/k")
             (commit k-commit)))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1949kvby0p82778iyg34a2d5wz4k3a5zi7568rwxmj7k52mqwhbj"))))
    (build-system copy-build-system)
    (inputs (list bash-minimal unison-lang-1.3))
    (arguments
     `(#:phases (modify-phases %standard-phases
                  (add-after 'unpack 'prepare-build
                    (lambda _
                      (let ((home (string-append (getcwd) "/build-home")))
                        (mkdir-p home)
                        (setenv "HOME" home))))
                  (add-after 'prepare-build 'import-codebase
                    (lambda* (#:key inputs #:allow-other-keys)
                      (let ((codebase (string-append (getcwd)
                                                     "/build-codebase"))
                            (ucm (search-input-file inputs "bin/ucm")))
                        (call-with-output-file "import.md"
                          (lambda (port)
                            (display "```ucm
scratch/main> project.create-empty k
k/main> sync.from-file ./k.usync /master
```
"
                             port)))
                        (invoke ucm "transcript.in-place" "--codebase-create"
                                codebase "import.md"))))
                  (add-after 'import-codebase 'check
                    (lambda* (#:key inputs tests? #:allow-other-keys)
                      (when tests?
                        (let ((codebase (string-append (getcwd)
                                                       "/build-codebase"))
                              (ucm (search-input-file inputs "bin/ucm")))
                          (call-with-output-file "test.md"
                            (lambda (port)
                              (display "```ucm\nk/master> test\n```\n" port)))
                          (invoke ucm "transcript.in-place"
                                  "--codebase-create" codebase "test.md")))))
                  (add-after 'check 'compile
                    (lambda* (#:key inputs #:allow-other-keys)
                      (let ((codebase (string-append (getcwd)
                                                     "/build-codebase"))
                            (ucm (search-input-file inputs "bin/ucm")))
                        (call-with-output-file "compile.md"
                          (lambda (port)
                            (display
                                     "```ucm\nk/master> compile k.main ./k\n```\n"
                                     port)))
                        (invoke ucm "transcript.in-place" "--codebase-create"
                                codebase "compile.md"))))
                  (replace 'install
                    (lambda* (#:key inputs outputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (bin (string-append out "/bin"))
                             (libexec (string-append out "/libexec/k"))
                             (artifact (string-append libexec "/k.uc"))
                             (launcher (string-append bin "/k"))
                             (bash (search-input-file inputs "bin/bash"))
                             (ucm (search-input-file inputs "bin/ucm")))
                        (mkdir-p bin)
                        (mkdir-p libexec)
                        (install-file "k.uc" libexec)
                        (chmod artifact #o444)
                        (call-with-output-file launcher
                          (lambda (port)
                            (display (string-append "#!"
                                                    bash
                                                    "\n"
                                                    "exec \""
                                                    ucm
                                                    "\" run.compiled \""
                                                    artifact
                                                    "\" -- \"$@\"\n") port)))
                        (chmod launcher #o755))))
                  (add-after 'install 'check-installed
                    (lambda* (#:key outputs tests? #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (launcher (string-append out "/bin/k"))
                             (artifact (string-append out "/libexec/k/k.uc")))
                        (unless (and (file-exists? launcher)
                                     (file-exists? artifact))
                          (error "installed k files are missing"))
                        (when tests?
                          (invoke launcher "models" "codex" "status"))))))))
    ;; UCM 1.3.0 is packaged from an AArch64 Linux release artifact.
    (supported-systems (list "aarch64-linux"))
    (synopsis "Minimal coding agent written in Unison")
    (description
     "k is a minimal personal coding agent written in the Unison programming
language.  This package compiles its exported Unison codebase and runs the
result with the matching Unison Codebase Manager runtime.")
    (home-page "https://github.com/cavoirom/k")
    ;; The 0.1.0 source tag does not declare a license.
    (license #f)))
