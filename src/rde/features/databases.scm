;;; rde --- Reproducible development environment.
;;;
;;; Copyright © 2023 Miguel Ángel Moreno <me@mianmoreno.com>
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

(define-module (rde features databases)
  #:use-module (rde features)
  #:use-module (rde features emacs)
  #:use-module (rde features predicates)
  #:use-module (gnu packages databases)
  #:use-module (gnu services)
  #:use-module (gnu services databases)
  #:use-module (srfi srfi-1)
  #:export (feature-postgresql))

(define-public (list-of-postgresql-roles? lst)
  (and (list? lst) (every postgresql-role? lst)))

(define-public (maybe-list-of-postgresql-roles? x)
  (or (list-of-postgresql-roles? x) (not x)))

(define* (feature-postgresql
          #:key
          (postgresql postgresql)
          (postgresql-roles #f))
  "Configure the PostgreSQL relational database."
  (ensure-pred any-package? postgresql)
  (ensure-pred maybe-list-of-postgresql-roles? postgresql-roles)

  (define f-name 'postgresql)

  (define (get-system-services config)
    "Return system services related to PostgreSQL."
    (append
     (list
      (service postgresql-service-type
               (postgresql-configuration
                (postgresql postgresql))))
     (if postgresql-roles
         (list
          (service postgresql-role-service-type
                   (postgresql-role-configuration
                    (roles postgresql-roles))))
         '())))

  (define (get-home-services config)
    "Return home services related to PostgreSQL."
    (if (get-value 'emacs config)
        (list
         (rde-elisp-configuration-service
          f-name
          config
          `(,@(if (get-value 'emacs-org config)
                  '((with-eval-after-load 'ob-core
                      (require 'ob-sql))
                    (with-eval-after-load 'ob-sql
                      (setq org-babel-default-header-args:sql
                            '((:engine . "postgresql")))))
                  '()))))
        '()))

  (feature
   (name f-name)
   (values `((,f-name . ,postgresql)))
   (system-services-getter get-system-services)
   (home-services-getter get-home-services)))
