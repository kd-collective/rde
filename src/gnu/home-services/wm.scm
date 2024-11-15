(define-module (gnu home-services wm)
  #:use-module (gnu home services)
  #:use-module (rde home services wm)
  #:use-module (gnu home-services-utils)
  #:use-module (gnu packages wm)
  #:use-module (gnu services configuration)

  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix diagnostics)
  #:use-module (guix ui)

  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)


  #:export (home-xmonad-service-type
            home-xmonad-configuration))

;;; Commentary:
;;;
;;; This module contains services for window managers.
;;;
;;; Code:


;;;
;;; XMonad.
;;;

(define-configuration/no-serialization home-xmonad-configuration
  (package
    (package xmonad)
    "The XMonad package to use.")
  (xmonad-contrib?
   (boolean #f)
   "Whether to install the @code{ghc-xmonad-contrib} package, which
contains many third-party extensions for XMonad.")
  (config
   (gexp-text-config '())
   "List of strings or gexps containing the XMonad configuration, see
the @uref{https://xmonad.org/documentation.html, official XMonad
documentation} for how to configure it."))

(define xmonad-profile-service
  (match-lambda
    (($ <home-xmonad-configuration> package xmonad-contrib? _)
     (if xmonad-contrib?
         (list package ghc-xmonad-contrib)
         (list package)))))

(define xmonad-files-service
  (match-lambda
    (($ <home-xmonad-configuration> package xmonad-contrib? config _)
     (if (null? config)
         '()
         `(("xmonad/xmonad.hs"
            ,(mixed-text-file "xmonad-xmonad.hs"
                              (serialize-gexp-text-config #f config))))))))

(define xmonad-run-on-change-service
  (match-lambda
    (($ <home-xmonad-configuration> package xmonad-contrib? config _)
     `(("files/.config/xmonad/xmonad.hs"
        ,#~(let ((executable #$(file-append package "/bin/xmonad")))
             (system* executable "--recompile")
             (system* executable "--restart")))))))

(define home-xmonad-service-type
  (service-type (name 'home-xmonad)
                (extensions
                 ;; TODO: Extend `on-change' service.
                 (list (service-extension
                        home-profile-service-type
                        xmonad-profile-service)
                       (service-extension
                        home-run-on-change-service-type
                        xmonad-run-on-change-service)
                       (service-extension
                        home-xdg-configuration-files-service-type
                        xmonad-files-service)))
                (description "\
Install and configure XMonad, a window manager written in Haskell.")))

(define (generate-home-xmonad-documentation)
  (generate-documentation
   `((home-xmonad-configuration
      ,home-xmonad-configuration-fields))
   'home-xmonad-configuration))
