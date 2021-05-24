(define-module (rde features predicates)
  #:use-module (rde features)
  #:use-module (gnu system)
  #:use-module (gnu services)
  #:use-module (gnu home-services)
  #:use-module (gnu system file-systems)
  #:use-module (gnu system mapped-devices)

  #:use-module (srfi srfi-1)
  #:use-module (guix packages)
  #:use-module (guix gexp)

  #:re-export (package?))

(define-public (maybe-string? x)
  (or (string? x) (not x)))

(define-public (path? x)
  (string? x))

(define-public (maybe-file-like? x)
  (or (file-like? x) (not x)))

(define-public (file-like-or-path? x)
  (or (file-like? x) (path? x)))

(define-public %number-of-ttys 6)
(define-public (tty-number? x)
  (and (integer? x) (<= 1 x %number-of-ttys)))

(define-public (list-of-packages? lst)
  (and (list? lst) (every package? lst)))

(define-public (list-of-services? lst)
  (and (list? lst) (every service? lst)))

(define-public (string-or-gexp? x)
  (and (string? x) (gexp? x)))
(define-public (list-of-string-or-gexps? lst)
  (and (list? lst) (every string-or-gexp? lst)))


(define-public (list-of-file-systems? lst)
  (and (list? lst) (every file-system? lst)))
(define-public (list-of-mapped-devices? lst)
  (and (list? lst) (every mapped-device? lst)))
