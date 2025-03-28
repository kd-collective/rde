(define-module (gnu home-services mail)
  #:use-module (gnu home services)
  #:use-module (gnu home-services-utils)
  #:use-module (gnu home services shepherd)
  #:use-module (gnu packages mail)
  #:use-module (gnu services configuration)

  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)

  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix diagnostics)
  #:use-module (guix i18n)
  #:use-module ((guix import utils) #:select (flatten))

  #:export (home-isync-service-type
            home-isync-configuration

            home-notmuch-service-type
            home-notmuch-configuration
            home-notmuch-extension

            home-l2md-service-type
            home-l2md-configuration
            l2md-repo
            l2md-repo-name
            l2md-repo-urls
            l2md-repo-maildir
            l2md-repo-pipe
            l2md-repo-initial-import
            l2md-repo-sync-enabled?))

;;; Commentary:
;;;
;;; This modules contains mail-related services.
;;;
;;; Code:


;;;
;;; Isync.
;;;

;; TODO: [Andrew Tropin, 2024-12-04] Fix serialization of gexp value
;; It doesn't handle gexp valued entries (Tunnel #~"gexp")
(define (serialize-isync-config field-name val)
  (define (serialize-term term)
    (match term
      ((? symbol? e) (symbol->string e))
      ((? number? e) (format #f "~a" e))
      ((? string? e) (format #f "~s" e))
      (e e)))
  (define (serialize-item entry)
    (match entry
      ((? gexp? e) e)
      ((? list lst)
       #~(string-join '#$(map serialize-term lst)))))

  #~(string-append #$@(interpose (map serialize-item val) "\n" 'suffix)))

(define-configuration/no-serialization home-isync-configuration
  (isync
   (file-like isync)
   "isync package to use.")
  (xdg-flavor?
   (boolean #t)
   "Whether to use the @file{$XDG_CONFIG_HOME/isync/mbsyncrc}
configuration file or not.  If @code{#t} creates a wrapper for mbsync
binary.")
  (config
   (list '())
   "AList of pairs, each pair is a String and String or Gexp."))

(define (add-isync-package config)
  (define wrapper-gexp
    #~(system
       (string-join
        (cons
         #$(file-append (home-isync-configuration-isync config)
                        "/bin/mbsync")
         (if (or (member "-c" (command-line))
                 (member "--config" (command-line)))
             (cdr (command-line))
             (append
              (list "--config"
                    "${XDG_CONFIG_HOME:-$HOME/.config}/isync/mbsyncrc")
              (cdr (command-line))))))))
  (list
   (if (home-isync-configuration-xdg-flavor? config)
       (wrap-package
        (home-isync-configuration-isync config)
        "mbsync" wrapper-gexp)
       (home-isync-configuration-isync config))))

(define (get-isync-configuration config)
  `((,(if (home-isync-configuration-xdg-flavor? config)
          "isync/mbsyncrc"
          "mbsyncrc")
     ,(mixed-text-file
       "mbsyncrc"
       (serialize-isync-config #f (home-isync-configuration-config config))))))

(define (add-isync-dot-configuration config)
  (if (home-isync-configuration-xdg-flavor? config)
      '()
      (get-isync-configuration config)))

(define (add-isync-xdg-configuration config)
  (if (home-isync-configuration-xdg-flavor? config)
      (get-isync-configuration config)
      '()))

(define (home-isync-extensions cfg extensions)
  (home-isync-configuration
   (inherit cfg)
   (config (append (home-isync-configuration-config cfg) extensions))))

(define home-isync-service-type
  (service-type (name 'home-isync)
                (extensions
                 (list (service-extension
                        home-profile-service-type
                        add-isync-package)
                       (service-extension
                        home-files-service-type
                        add-isync-dot-configuration)
                       (service-extension
                        home-xdg-configuration-files-service-type
                        add-isync-xdg-configuration)))
                (compose concatenate)
                (extend home-isync-extensions)
                (default-value (home-isync-configuration))
                (description "Install and configure isync.")))

(define (list-of-gexps? lst)
  (and (list? lst) (every gexp? lst)))

(define (generate-home-isync-documentation)
  (generate-documentation
   `((home-isync-configuration
      ,home-isync-configuration-fields))
   'home-isync-configuration))


;;;
;;; Notmuch.
;;;

(define-configuration/no-serialization home-notmuch-configuration
  (notmuch
   (file-like notmuch)
   "notmuch package to use.")
  (config
   (ini-config '())
   "AList of pairs, each pair is a String and String or Gexp.")
  (pre-new
   (list-of-gexps '())
   "List of gexp to add in @file{pre-new} hook. Read @code{man
notmuch-hooks} for more information.")
  (post-new
   (list-of-gexps '())
   "List of gexp to add in @file{post-new} hook. Read @code{man
notmuch-hooks} for more information.")
  (post-insert
   (list-of-gexps '())
   "List of gexp to add in @file{post-insert} hook. Read @code{man
notmuch-hooks} for more information."))

(define-configuration/no-serialization home-notmuch-extension
  (config
   (ini-config '())
   "AList of pairs, each pair is a String and String or Gexp.")
  (pre-new
   (list-of-gexps '())
   "List of gexp to add in @file{pre-new} hook. Read @code{man
notmuch-hooks} for more information.")
  (post-new
   (list-of-gexps '())
   "List of gexp to add in @file{post-new} hook. Read @code{man
notmuch-hooks} for more information.")
  (post-insert
   (list-of-gexps '())
   "List of gexp to add in @file{post-insert} hook. Read @code{man
notmuch-hooks} for more information."))

(define (add-notmuch-package config)
  (list (home-notmuch-configuration-notmuch config)))

(define (add-notmuch-configuration config)
  (define (serialize-field key val)
    (let ((val (cond
                ((list? val) (string-join (map maybe-object->string val) ";"))
                (else val))))
      (format #f "~a=~a\n" key val)))

  (define (filter-fields field)
    (filter-configuration-fields home-notmuch-configuration-fields
                                 (list field)))

  (define (hook-file hook gexps)
    (list (string-append "notmuch/default/hooks/" hook)
          (program-file (string-append "notmuch-" hook) #~(begin #$@gexps))))

  (define (get-hook hook)
    (let* ((field-obj (car (filter-fields (string->symbol hook))))
           (gexps ((configuration-field-getter field-obj) config)))
      (if (not (null? gexps))
          (hook-file hook gexps)
          '())))

  (remove null?
  `(,@(map get-hook '("pre-new" "post-new" "post-insert"))
    ("notmuch/default/config"
     ,(mixed-text-file
       "notmuch-config"
       (generic-serialize-ini-config
        #:serialize-field serialize-field
        #:fields (home-notmuch-configuration-config config)))))))

(define (home-notmuch-extensions cfg extensions)
  (home-notmuch-configuration
   (inherit cfg)
   (config
    (append (home-notmuch-configuration-config cfg)
            (append-map home-notmuch-extension-config extensions)))
   (pre-new
    (append (home-notmuch-configuration-pre-new cfg)
            (append-map home-notmuch-extension-pre-new extensions)))
   (post-new
    (append (home-notmuch-configuration-post-new cfg)
            (append-map home-notmuch-extension-post-new extensions)))
   (post-insert
    (append (home-notmuch-configuration-post-insert cfg)
            (append-map home-notmuch-extension-post-insert extensions)))))

(define home-notmuch-service-type
  (service-type (name 'home-notmuch)
                (extensions
                 (list (service-extension
                        home-profile-service-type
                        add-notmuch-package)
                       (service-extension
                        home-xdg-configuration-files-service-type
                        add-notmuch-configuration)))
                (compose identity)
                (extend home-notmuch-extensions)
                (default-value (home-notmuch-configuration))
                (description "Install and configure notmuch.")))

(define (generate-home-notmuch-documentation)
  (generate-documentation
   `((home-notmuch-configuration
      ,home-notmuch-configuration-fields))
   'home-notmuch-configuration))


;;;
;;; L2md.
;;;

(define (string-or-list-of-strings? val)
  (or (string? val) (list-of-strings? val)))

(define-maybe/no-serialization string)
(define-maybe/no-serialization string-or-gexp)

(define-configuration/no-serialization l2md-repo
  (name
   (string)
   "The name of the public-inbox repository.")
  (urls
   (string-or-list-of-strings)
   "A list of URLs to fetch the public-inbox repository from.")
  (maildir
   maybe-string
   "The maildir corresponding to the public-inbox repository.  This is
optional, an external MDA like Procmail can be used instead to filter
the messages, see the @code{pipe} field.")
  (pipe
   maybe-string-or-gexp
   "A command to pipe the messages to for further filtering.  This is
mutually exclusive with the @code{maildir} field.")
  (initial-import
   (integer 0)
   "The number of messages to import initially, if @code{0}, import all
the messages.")
  (sync-enabled?
   (boolean #t)
   "Whether to sync this repository or not."))

(define list-of-l2md-repos? (list-of l2md-repo?))

(define-configuration/no-serialization home-l2md-configuration
  (l2md
   (file-like l2md)
   "The L2md package to use.")
  (autostart?
   (boolean #f)
   "Whether to autostart L2md on login.")
  (period
   (integer 180)
   "The number of seconds between each round of fetching Git
repositories.")
  (oneshot
   (integer 0)
   "@code{0} to watch for new emails every PERIOD seconds, @code{1} to
sync once and exit.")
  (maildir
   maybe-string
   "The maildir to which messages should be delivered.  This can also be
set on a per-list basis using the using the @code{maildir} field in
the @code{<l2md-repo>} record.")
  (pipe
   maybe-string-or-gexp
   "A command to pipe the messages to for further filtering.  This is
mutually exclusive with the @code{maildir} field.  This can also be
set on a per-list basis using the @code{<l2md-repo>} record.")
  (base
   (string "${XDG_STATE_HOME:-$HOME}/l2md")
   "The directory where L2md stores Git repositories and other
metadata.")
  (repos
   (list-of-l2md-repos '())
   "List of @code{l2md-repo} records, representing the configuration for
a particular public-inbox repository."))

(define (serialize-l2md-configuration config)
  (define (serialize-field field-name val)
    (let ((val (cond
                ((boolean? val) (if val "1" "0"))
                (else (maybe-object->string val)))))
      (if (string= val "")
          '()
          (list "\t" (object->snake-case-string field-name) " = " val "\n"))))

  (define (l2md-repo->alist repos)
    (match repos
      (($ <l2md-repo> name urls maildir pipe initial-import sync-enabled? _)
       (begin
         `(repo ,name
                (,@(map (lambda (url)
                          `(url . ,url))
                        (maybe-list urls))
                 ,@(if (eq? maildir %unset-value) '() `((maildir . ,maildir)))
                 ,@(if (eq? pipe %unset-value) '() `((pipe . ,pipe)))
                 (initial-import . ,initial-import)
                 (sync-enabled . ,sync-enabled?)))))))

  (match config
    (($ <home-l2md-configuration> l2md autostart? period oneshot maildir pipe base repos _)
     (begin
       (generic-serialize-git-ini-config
        #:combine-ini (compose flatten list)
        #:combine-alist append
        #:combine-section-alist cons*
        #:serialize-field serialize-field
        #:fields
        `((general
           ((period . ,period)
	    ,@(if (eq? maildir %unset-value) '() `((maildir . ,maildir)))
            ,@(if (eq? pipe %unset-value) '() `((pipe . ,pipe)))
            (oneshot . ,oneshot)
            (base . ,base)))
          ,@(map l2md-repo->alist repos)))))))

(define (l2md-configuration-files config)
  `(("l2md/config"
     ,(apply mixed-text-file
             "l2mdconfig"
             (serialize-l2md-configuration config)))))

(define l2md-shepherd-service
  (match-lambda
    (($ <home-l2md-configuration> l2md autostart? _)
     (if autostart?
         (list (shepherd-service
                (documentation
                 "L2md service for downloading public-inbox archives.")
                (provision '(l2md))
                (start #~(make-forkexec-constructor
                          (list #$(file-append l2md "/bin/l2md"))
                          #:log-file (string-append
                                      (getenv "XDG_STATE_HOME") "/log"
                                      "/l2md.log")))
                (stop #~(make-kill-destructor))))
         '()))))

(define (l2md-profile-service config)
  (list (home-l2md-configuration-l2md config)))

(define home-l2md-service-type
  (service-type (name 'home-l2md)
                (extensions
                 (list (service-extension
                        home-xdg-configuration-files-service-type
                        l2md-configuration-files)
                       (service-extension
                        home-shepherd-service-type
                        l2md-shepherd-service)
                       (service-extension
                        home-profile-service-type
                        l2md-profile-service)))
                (description "Install and configure L2md.")))

(define (generate-home-l2md-documentation)
  (generate-documentation
   `((home-l2md-configuration
      ,home-l2md-configuration-fields
      (l2md-repo l2md-repo))
     (l2md-repo ,l2md-repo-fields))
   'home-l2md-configuration))
