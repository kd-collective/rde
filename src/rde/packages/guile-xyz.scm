;;; rde --- Reproducible development environment.
;;;
;;; Copyright © 2024 Andrew Tropin <andrew@trop.in>
;;;
;;; This file is part of rde.
;;;
;;; rde is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; rde is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with rde.  If not, see <http://www.gnu.org/licenses/>.

(define-module (rde packages guile-xyz)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages guile)
  #:use-module (gnu packages guile-xyz)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system guile)
  #:use-module ((guix licenses) #:prefix license:))

(define-public guile-ares-rs-latest
  (let* ((commit "e9b899f986587fbd4cecc2bae5b1b7f8e5351551")
         (revision "5"))
    (package
      (inherit guile-ares-rs)
      (name "guile-ares-rs")
      (version (git-version "0.9.5" revision commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://git.sr.ht/~abcdw/guile-ares-rs")
               (commit commit)))
         (file-name (git-file-name name version))
         (sha256
          (base32
           "0hbf1di0cigqxalbh1g76673jyn1n28ig6jalzbv72575il57yrz")))))))

(define-public guile-ares-shepherd
  (package
    (name "guile-ares-shepherd")
    (version "0.1")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://codeberg.org/cons-town/guile-debugger")
                    (commit (string-append "ares-shepherd-" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "1abnrp67zph4cc8x4pmmja52ma5ixf9ilcz13r19ga8ar8b36hv0"))))
    (build-system guile-build-system)
    (arguments
     (list #:source-directory "shepherd-nrepl/src/guile"))
    (native-inputs `(("guile" ,guile-next)))
    (inputs (list shepherd-1.0
                  guile-fibers
                  guile-ares-rs-latest))
    (home-page "https://codeberg.org/cons-town/guile-debugger")
    (synopsis "Shepherd interface for Ares")
    (description "ares-shepherd is an extension for Ares that adds the ability to
connect and interact to a shepherd via its nREPL service.")
    (license license:gpl3+)))
