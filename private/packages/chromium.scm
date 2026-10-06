(define-module (private packages chromium)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module ((gnu packages bootstrap) #:select (glibc-dynamic-linker))
  #:use-module (gnu packages compression)
  #:use-module (gnu packages cups)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages fonts)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages nss)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages qt)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages video)
  #:use-module (gnu packages xml)
  #:use-module (gnu packages xorg)
  #:use-module (guix build-system copy)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages))

(define-public chromium
  (package
    (name "chromium")
    (version "154.0.8037.97-1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/ungoogled-software/ungoogled-chromium-portablelinux/"
             "releases/download/" version "/"
             "ungoogled-chromium-" version "-arm64_linux.tar.xz"))
       ;; GitHub release API and the downloaded archive have the same digest:
       ;; 594c337b1d35e0a8b9eb9233740498a8fdab386e22602412e26d12b0ef4a09f1.
       (sha256
        (base32 "1w899bpv04kdw8928q12dqwapzd8k0278cwjxfwsiq1m3mxk6k2r"))))
    (build-system copy-build-system)
    (native-inputs (list patchelf binutils coreutils-minimal util-linux))
    (inputs (list bash-minimal
                  glibc
                  (list gcc "lib")
                  glib
                  nspr
                  nss
                  at-spi2-core
                  dbus
                  cups-minimal
                  expat
                  libxcb
                  libxkbcommon
                  alsa-lib
                  mesa
                  libx11
                  libxext
                  cairo
                  pango
                  eudev
                  libxcomposite
                  libxdamage
                  libxfixes
                  libxrandr
                  qtbase-5
                  qtbase
                  fontconfig
                  font-dejavu
                  ;; These libraries are loaded at run time rather than by DT_NEEDED.
                  gtk+
                  gtk
                  pipewire
                  libva))
    (arguments
     ;; Chromium reports its version without the portable release revision.
     (let ((browser-version (car (string-split version #\-))))
       (list
        #:modules '((guix build copy-build-system)
                    (guix build utils)
                    (ice-9 popen)
                    (ice-9 textual-ports)
                    (srfi srfi-1))
        #:phases
        #~(modify-phases %standard-phases
            (delete 'make-dynamic-linker-cache)
            (replace 'install
              (lambda* (#:key outputs #:allow-other-keys)
                (copy-recursively "."
                                  (string-append (assoc-ref outputs "out")
                                                 "/libexec/ungoogled-chromium"))))
            (add-after 'install 'patch-installed-elf
              (lambda* (#:key inputs outputs #:allow-other-keys)
                (let* ((tree (string-append (assoc-ref outputs "out")
                                            "/libexec/ungoogled-chromium"))
                       (interpreter (search-input-file inputs
                                                       #$(glibc-dynamic-linker)))
                       (paths (delete-duplicates (map (lambda (file)
                                                        (dirname (search-input-file
                                                                  inputs file)))
                                                      '("lib/libc.so.6"
                                                        "lib/libgcc_s.so.1"
                                                        "lib/libglib-2.0.so.0"
                                                        "lib/libnspr4.so"
                                                        "lib/nss/libnss3.so"
                                                        "lib/libatk-1.0.so.0"
                                                        "lib/libdbus-1.so.3"
                                                        "lib/libcups.so.2"
                                                        "lib/libexpat.so.1"
                                                        "lib/libxcb.so.1"
                                                        "lib/libxkbcommon.so.0"
                                                        "lib/libasound.so.2"
                                                        "lib/libgbm.so.1"
                                                        "lib/libX11.so.6"
                                                        "lib/libXext.so.6"
                                                        "lib/libcairo.so.2"
                                                        "lib/libpango-1.0.so.0"
                                                        "lib/libudev.so.1"
                                                        "lib/libXcomposite.so.1"
                                                        "lib/libXdamage.so.1"
                                                        "lib/libXfixes.so.3"
                                                        "lib/libXrandr.so.2"
                                                        "lib/libQt5Core.so.5"
                                                        "lib/libQt6Core.so.6"
                                                        "lib/libfontconfig.so.1"
                                                        "lib/libgtk-3.so.0"
                                                        "lib/libgtk-4.so.1"
                                                        "lib/libpipewire-0.3.so.0"
                                                        "lib/libva.so.2"))))
                       (rpath (string-join (cons "$ORIGIN" paths) ":")))
                  (for-each (lambda (file)
                              (let* ((port (open-pipe* OPEN_READ "readelf" "-l"
                                                       file))
                                     (headers (get-string-all port)))
                                (unless (zero? (status:exit-val (close-pipe port)))
                                  (error "cannot inspect ELF" file))
                                (when (string-contains headers "INTERP")
                                  (invoke "patchelf" "--set-interpreter"
                                          interpreter file))
                                (invoke "patchelf" "--set-rpath" rpath file)))
                            (find-files tree
                                        (lambda (file stat)
                                          (elf-file? file)))))))
            (add-after 'patch-installed-elf 'make-launcher
              (lambda* (#:key inputs outputs #:allow-other-keys)
                (let* ((out (assoc-ref outputs "out"))
                       (tree (string-append out "/libexec/ungoogled-chromium"))
                       (bin (string-append out "/bin"))
                       (launcher (string-append bin "/chromium"))
                       (fonts (string-append out "/etc/fonts/fonts.conf")))
                  (mkdir-p bin)
                  (mkdir-p (dirname fonts))
                  (call-with-output-file fonts
                    (lambda (port)
                      (format port
                       "<?xml version=\"1.0\"?>
<!DOCTYPE fontconfig SYSTEM \"urn:fontconfig:fonts.dtd\">
<fontconfig><include>~a</include><dir>~a/share/fonts</dir></fontconfig>
"
                       (search-input-file inputs "etc/fonts/fonts.conf")
                       #$font-dejavu)))
                  ;; Retain the upstream script, but do not use its FHS probes.
                  (substitute* (string-append tree "/chrome-wrapper")
                    (("^#!/bin/bash")
                     (string-append "#!"
                                    (search-input-file inputs "bin/bash"))))
                  (call-with-output-file launcher
                    (lambda (port)
                      (format port
                              "#!~a
export FONTCONFIG_FILE=\"${FONTCONFIG_FILE:-~a}\"
exec ~a/chrome \"$@\"
"
                              (search-input-file inputs "bin/bash") fonts tree)))
                  (chmod launcher #o755))))
            (add-after 'make-launcher 'install-license
              (lambda* (#:key outputs #:allow-other-keys)
                (let ((directory (string-append (assoc-ref outputs "out")
                                  "/share/doc/chromium")))
                  (mkdir-p directory)
                  (with-output-to-file (string-append directory "/LICENSE")
                    (lambda ()
                      (invoke "base64" "--decode"
                              #$(origin
                                  (method url-fetch)
                                  (uri
                                   (string-append
                                    "https://chromium.googlesource.com/chromium/src/+/"
                                    browser-version "/LICENSE?format=TEXT"))
                                  (file-name
                                   (string-append "chromium-" browser-version
                                                  "-LICENSE.base64"))
                                  (sha256 (base32
                                           "1ld6wld1ldrmp69qsyll1ajavvhp1ba3n5rqdy1d8c08q3zdsgin")))))))))
            (add-after 'install-license 'check-installed
              (lambda* (#:key outputs tests? #:allow-other-keys)
                (when tests?
                  (let* ((out (assoc-ref outputs "out"))
                         (tree (string-append out "/libexec/ungoogled-chromium")))
                    (for-each (lambda (name)
                                (unless (file-exists? (string-append tree "/"
                                                                     name))
                                  (error "missing browser resource" name)))
                              '("resources.pak" "chrome_100_percent.pak"
                                "chrome_200_percent.pak"
                                "icudtl.dat"
                                "v8_context_snapshot.bin"
                                "locales/en-US.pak"
                                "vk_swiftshader_icd.json"))
                    (let* ((port (open-pipe* OPEN_READ "timeout"
                                             "--kill-after=5s" "60s"
                                             (string-append out "/bin/chromium")
                                             "--version"))
                           (reported (string-trim-right (get-string-all port)))
                           (status (close-pipe port))
                           (expected (string-append "Chromium " #$browser-version)))
                      (format #t "Browser version: ~a~%" reported)
                      (unless (and (zero? status) (string=? reported expected))
                        (error "unexpected browser version" reported expected
                               status)))))))))))
    (supported-systems '("aarch64-linux"))
    (home-page "https://ungoogled-software.github.io/")
    (synopsis "Prebuilt Chromium browser without Google services")
    (description
     "This package installs the AArch64 portable release of
Ungoogled Chromium.  It includes the browser, driver, graphics libraries, and
browser resources.  Third-party license notices remain in resources.pak and
are available at chrome://credits.  Chromium uses its built-in root store and
NSS for certificate support.")
    ;; Chromium is BSD-3; the bundle also includes components under these
    ;; licenses.  The complete component notices are in chrome://credits.
    (license (list license:bsd-3
                   license:bsd-2
                   license:expat
                   license:asl2.0
                   license:mpl1.1
                   license:mpl2.0
                   license:isc
                   license:public-domain
                   license:unicode
                   license:silofl1.1
                   license:lgpl2.1+
                   license:lgpl3+))))
