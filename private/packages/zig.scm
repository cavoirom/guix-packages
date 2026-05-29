(define-module (private packages zig)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix platform)
  #:use-module (guix search-paths)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system cmake)
  #:use-module (gnu packages)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages llvm-meta)
  #:use-module (gnu packages web)
  #:use-module (gnu packages zig))           ; For bootstrap

;; Replicate upstream helper
(define (zig-source version commit hash)
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://codeberg.org/ziglang/zig")
          (commit commit)))
    (file-name (git-file-name "zig" version))
    (sha256 (base32 hash))
    (modules '((guix build utils)))
    (snippet
     #~(for-each (lambda (file)
                   (when (file-exists? file)
                     (delete-file file)))
                 (append '("stage1/zig1.wasm"
                           "stage1/zig1.wasm.zst")
                         '("lib/libc/glibc/abilists")
                         (find-files "." "^rfc[0-9]+\\.txt"))))))

;; libc-abi-tools for Zig ≥ 0.15
;; TODO: Update commit/hash if upstream changed for 0.16.0
(define zig-0.16-libc-abi-tools
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://github.com/ziglang/libc-abi-tools")
          (commit "ec46122c7b8c7854f08e67e108083907d09996f5")))
    (file-name "libc-abi-tools")
    (sha256 (base32 "0s46f1wbqg53wxlrljb9afw4s8j5cl5vz5xhajy6fagy05xns2bc"))))

(define-public zig-0.16
  (package
    (name "zig")
    (version "0.16.0")
    (source (origin
              (inherit (zig-source version
                                   version       ; tag is "0.16.0"
                                   "0m5sj165wf4imq4fj7bsb38y49il5cagx1vw0slb5jmcls2wri6s")) ; <-- run: guix hash -x <zig-0.16.0-checkout>
              ;; TODO: Place your patches in the channel's patches directory
              ;; or remove this field if not needed.
              ;; Common upstream patches you may want to adapt:
              ;; - build-respect-PKG_CONFIG-env-var
              ;; - use-baseline-cpu-by-default
              ;; - use-system-paths
              ;; - fix-runpath
              ;; (patches (search-patches
              ;;           "zig-0.16-build-respect-PKG_CONFIG-env-var.patch"
              ;;           "zig-0.14-use-baseline-cpu-by-default.patch"
              ;;           "zig-0.14-use-system-paths.patch"
              ;;           "zig-0.16-fix-runpath.patch"))
	      ))
    (build-system cmake-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "-DZIG_LIB_DIR=" #$output "/lib/zig")
              "-DZIG_TARGET_MCPU=baseline"
              (string-append "-DZIG_TARGET_TRIPLE="
                             (zig-target
                              #$(platform-target
                                 (lookup-platform-by-target-or-system
                                  (or (%current-target-system)
                                      (%current-system))))))
              "-DZIG_USE_LLVM_CONFIG=ON")
      #:out-of-source? #f          ; Zig expects in-tree builds
      #:tests? (not (%current-target-system))
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'configure 'zig-configure
            zig-configure)
          (delete 'check)
          (add-after 'install 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                ;; Matches the upstream zig-0.11+ test invocation
                (invoke (string-append #$output "/bin/zig")
                        "test" "-I" "test" "test/behavior.zig"))))
          ;; Install abilists for glibc, freebsd, netbsd
          (add-before 'check 'install-abilists
            (lambda* (#:key inputs native-inputs #:allow-other-keys)
              (mkdir-p "/tmp/libc-abi-tools")
              (with-directory-excursion "/tmp/libc-abi-tools"
                (copy-recursively
                 (dirname (search-input-file
                           (or native-inputs inputs)
                           "list.zig"))
                 ".")
                (for-each make-file-writable (find-files "."))
                (for-each (lambda (libc)
                            (with-directory-excursion libc
                              (invoke (string-append #$output "/bin/zig")
                                      "run" "consolidate.zig")
                              (install-file "abilists"
                                            (string-append #$output
                                                           "/lib/zig/libc/"
                                                           libc))))
                          '("freebsd" "glibc" "netbsd"))))))))
    (inputs
     (list clang-21              ; Requires LLVM 21
           lld-21
           zlib
           `(,zstd "lib")))
    (native-inputs
     (list llvm-21
           zig-0.16-libc-abi-tools
           ;; TODO: Bootstrap zig. Upstream uses a specific intermediate commit
           ;; from the previous release series (e.g. zig-0.14.0-1197 for 0.15).
           ;; For a private channel, you can either:
           ;; 1. Use the latest zig from Guix (may or may not be new enough)
           ;; 2. Create a bootstrap binary package
           ;; 3. Import upstream's full bootstrap chain
           `(,zig-0.15 "zig1")))   ; <-- Adjust bootstrap as needed
    (native-search-paths
     (list $C_INCLUDE_PATH
           $CPLUS_INCLUDE_PATH
           $LIBRARY_PATH
           (search-path-specification
            (variable "GUIX_ZIG_PACKAGE_PATH")
            (files '("src/zig")))))
    (synopsis "General-purpose programming language and toolchain")
    (description
     "Zig is a general-purpose programming language and toolchain.  Among other
features it provides an optional type instead of null pointers, manual memory
management, generic data structures and functions, compile-time reflection and
code execution, integration with C using Zig as a C compiler, and concurrency
via async functions.")
    (home-page "https://ziglang.org/")
    (supported-systems %64bit-supported-systems)
    (properties `((max-silent-time . 9600)
                  ,@(clang-compiler-cpu-architectures "21")))
    (license license:expat)))

