(define-module (rde features predicates)
  #:use-module (rde features)
  #:use-module (rde serializers ini)
  #:use-module (gnu system)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (gnu system file-systems)
  #:use-module (gnu system mapped-devices)

  #:use-module (srfi srfi-1)
  #:use-module (guix deprecation)
  #:use-module (guix packages)
  #:use-module (guix inferior)
  #:use-module (guix gexp)

  #:export (any-package?
            list-of-packages?)
  #:re-export (file-like?
               package?
               ini-config?))

(define-public (maybe-integer? x)
  (or (integer? x) (not x)))

(define-public (maybe-procedure? x)
  (or (procedure? x) (not x)))

(define-public (maybe-symbol? x)
  (or (symbol? x) (not x)))

(define-public (maybe-string? x)
  (or (string? x) (not x)))

(define-public (maybe-url? x)
  (maybe-string? x))

(define-public (path? x)
  (string? x))

(define-public (maybe-path? x)
  (or (path? x) (not x)))

(define-public (maybe-file-like? x)
  (or (file-like? x) (not x)))

(define-public (file-like-or-path? x)
  (or (file-like? x) (path? x)))

(define-public %number-of-ttys 6)
(define-public (tty-number? x)
  (and (integer? x) (<= 1 x %number-of-ttys)))

(define-public (brightness? x)
  (and (integer? x) (<= 0 x 100)))

(define-public (maybe-list? lst)
  (or (list? lst) (not lst)))

(define-public (list-of-strings? lst)
  (and (list? lst) (every string? lst)))

(define-public (list-of-file-likes? lst)
  (and (list? lst) (every file-like? lst)))

(define-deprecated/alias any-package? file-like?)

(define-deprecated/alias list-of-packages? list-of-file-likes?)

(define-public list-of-elisp-packages? list-of-file-likes?)

(define-public (list-of-services? lst)
  (and (list? lst) (every service? lst)))

(define-public (string-or-gexp? x)
  (or (string? x) (gexp? x)))
(define-public (list-of-string-or-gexps? lst)
  (and (list? lst) (every string-or-gexp? lst)))


(define-public (list-of-file-systems? lst)
  (and (list? lst) (every file-system? lst)))
(define-public (list-of-mapped-devices? lst)
  (and (list? lst) (every mapped-device? lst)))
(define-public (list-of-swap-devices? lst)
  (and (list? lst) (every swap-space? lst)))

(define-public (rde-procedure? x)
  "Checks if procedure have exactly one required argument, no optional and no
rest arguments."
  (and (procedure? x)
       (equal?
        (procedure-minimum-arity x)
        '(1 0 #f))))
