(define-module (private packages vibium)
  #:use-module (gnu packages golang)
  #:use-module (gnu packages golang-build)
  #:use-module (gnu packages golang-web)
  #:use-module (gnu packages golang-xyz)
  #:use-module (gnu packages linux)
  #:use-module (guix build-system go)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages))

(define-public vibium
  (package
    (name "vibium")
    (version "26.11.16")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/VibiumDev/vibium")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "16p2ha2im07vh48ml6nfa2kk1fippyipm2w3li49m2vqwlr9jsg9"))))
    (build-system go-build-system)
    (arguments
     (list
      #:go go-1.27
      #:modules '((guix build go-build-system)
                  (guix build union)
                  (guix build utils)
                  (ice-9 popen)
                  (ice-9 textual-ports))
      #:install-source? #f
      ;; The Go module github.com/vibium/clicker is in the clicker directory.
      #:unpack-path "github.com/vibium"
      #:import-path "github.com/vibium/clicker/cmd/clicker"
      ;; Test all packages of the module, not only the command.
      #:test-subdirs #~(list "../../...")
      ;; Upstream sets the same two version values.
      #:build-flags
      #~(list (string-append
               "-ldflags=-s -w -X main.version=" #$version
               " -X github.com/vibium/clicker/internal/api.Version=" #$version))
      #:phases
      #~(modify-phases %standard-phases
          ;; Copy the files required by go:embed, as in upstream's Makefile.
          (add-after 'unpack 'prepare-embedded-files
            (lambda* (#:key unpack-path #:allow-other-keys)
              (with-directory-excursion (string-append "src/" unpack-path)
                (copy-file "skills/browser/SKILL.md"
                           "clicker/cmd/clicker/SKILL.md")
                (copy-file "skills/check/SKILL.md"
                           "clicker/cmd/clicker/CHECK_SKILL.md")
                (copy-file "config/ai.env"
                           "clicker/cmd/clicker/AI_ENV_TEMPLATE")
                (copy-file "config/cloud-browser.env"
                           "clicker/cmd/clicker/CLOUD_ENV_TEMPLATE"))))
          ;; Like the upstream release binaries, link statically, so the
          ;; closure does not include glibc and gcc.
          (add-before 'build 'disable-cgo
            (lambda _
              (setenv "CGO_ENABLED" "0")))
          (add-before 'check 'prepare-tests
            (lambda* (#:key unpack-path #:allow-other-keys)
              ;; GOPATH mode defaults to the old HTTP routing rules.
              (setenv "GODEBUG" "httpmuxgo121=0")
              (setenv "TMPDIR" "/tmp") ; leave room for Unix socket names
              (with-directory-excursion (string-append "src/" unpack-path "/clicker")
                (substitute* (find-files "." "_test\\.go$")
                  (("#!/bin/sh") (string-append "#!" (which "sh"))))
                ;; The sandbox has only loopback. Enable it for ICE in the
                ;; tests, after the installed binary has been compiled.
                (substitute* "internal/watch/watch.go"
                  (("api := webrtc.NewAPI")
                   "quiet.SetIncludeLoopbackCandidate(true)\n\tapi := webrtc.NewAPI"))
                (substitute* "internal/watch/watchtest/rig.go"
                  (("pc, err := webrtc.NewPeerConnection")
                   (string-append
                    "settings := webrtc.SettingEngine{}\n\t"
                    "settings.SetIncludeLoopbackCandidate(true)\n\t"
                    "pc, err := webrtc.NewAPI(webrtc.WithSettingEngine(settings)).NewPeerConnection"))))))
          (add-after 'install 'rename-binary
            (lambda _
              (rename-file (string-append #$output "/bin/clicker")
                           (string-append #$output "/bin/vibium"))))
          (add-after 'rename-binary 'check-version
            (lambda _
              (let* ((port (open-pipe* OPEN_READ
                                       (string-append #$output "/bin/vibium")
                                       "--version"))
                     (reported (string-trim-right (get-string-all port)))
                     (status (close-pipe port))
                     (expected (string-append "vibium v" #$version)))
                (format #t "Vibium version: ~a~%" reported)
                (unless (and (zero? status) (string=? reported expected))
                  (error "unexpected vibium version" reported expected
                         status))))))))
    (native-inputs (list procps)) ; for the process cleanup tests
    (inputs (list go-github-com-gorilla-websocket
                  go-github-com-pion-interceptor
                  go-github-com-pion-logging
                  go-github-com-pion-rtcp
                  go-github-com-pion-rtp
                  go-github-com-pion-webrtc-v4
                  go-github-com-spf13-cobra
                  go-github-com-spf13-pflag
                  go-golang-org-x-term))
    (home-page "https://vibium.com")
    (synopsis "Browser automation CLI and MCP server for AI agents")
    (description
     "Vibium controls browsers through WebDriver BiDi.  It supplies a
command-line interface with a background daemon and a Model Context Protocol
(MCP) server.  It can connect to an existing BiDi session or start a browser
from its own cache.")
    (license license:asl2.0)))
