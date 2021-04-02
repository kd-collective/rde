(define-module (gnu home-services shells)
  #:use-module (gnu services configuration)
  #:use-module (gnu home-services-utils)
  #:use-module (gnu home-services)
  #:use-module (gnu home-services files)
  #:use-module (gnu packages shells)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (guix packages)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)

  #:export (home-shell-profile-service-type
	    home-shell-profile-configuration
	    home-zsh-service-type
	    home-zsh-configuration
	    home-zsh-extension))

(define path? string?)
(define (serialize-path field-name val) val)

(define-configuration home-shell-profile-configuration
  (he-symlink-path
   (path "~/.guix-home-environment")
   "Path to home-environment symlink, which contains files that have
to be sourced or executed by login shell.  This path will be set
automatically by home-environment.")
  (profile
   (text-config '())
   "\
@code{home-shell-profile} is instantiated automatically by
@code{home-environment}, DO NOT create this service manually, it can
only be extended.

@code{profile} is a list of strings or gexps, which will go to
@file{~/.profile}.  By default @file{~/.profile} contains the
initialization code, which have to be evaluated by login shell to make
home-environment's profile avaliable to the user, but other commands
can be added to the file if it is really necessary.

In most cases shell's configuration files are preferred places for
user's customizations.  Extend home-shell-profile service only if you
really know what you do."))

(define (add-shell-profile-file config)
  `(("profile"
     ,(mixed-text-file
       "shell-profile"
       (format #f "\
HOME_ENVIRONMENT=\"~a\"
source $HOME_ENVIRONMENT/setup-environment
sh $HOME_ENVIRONMENT/on-login\n"
	       (home-shell-profile-configuration-he-symlink-path config))
       (serialize-configuration
	config
	(filter-configuration-fields
	 home-shell-profile-configuration-fields '(profile)))))))

(define (add-profile-extensions config extensions)
  (home-shell-profile-configuration
   (inherit config)
   (profile
    (append (home-shell-profile-configuration-profile config)
	    extensions))))

(define home-shell-profile-service-type
  (service-type (name 'home-shell-profile)
                (extensions
                 (list (service-extension
			home-files-service-type
			add-shell-profile-file)))
		(compose concatenate)
		(extend add-profile-extensions)
		(default-value (home-shell-profile-configuration))
                (description "\
Create @file{~/.profile}, which is used for environment initialization
of POSIX compatible login shells.  Can be extended with a list of strings or
gexps.")))

(define (serialize-boolean field-name val) "")

(define-configuration home-zsh-configuration
  (package
   (package zsh)
   "The Zsh package to use.")
  (xdg-flavor?
   (boolean #f)
   "Place all the configs to @file{$XDG_CONFIG_HOME/zsh}.  Makes
@file{~/.zshenv} to set @env{ZDOTDIR} to @file{$XDG_CONFIG_HOME/zsh}.
Shell startup process will continue with
@file{$XDG_CONFIG_HOME/zsh/.zshenv}.")
  (zshenv
   (text-config '())
   "List of strings or gexps, which will be added to @file{.zshenv}.
Used for setting user's shell environment variables.  Must not contain
commands assuming the presence of tty or producing output.  Will be
read always.  Will be read before any other file in @env{ZDOTDIR}.")
  (zprofile
   (text-config '())
   "List of strings or gexps, which will be added to @file{.zprofile}.
Used for executing user's commands at start of login shell (In most
cases the shell started on tty just after login).  Will be read before
@file{.zlogin}.")
  (zshrc
   (text-config '())
   "List of strings or gexps, which will be added to @file{.zshrc}.
Used for executing user's commands at start of interactive shell (The
shell for interactive usage started by typing @code{zsh} or by
terminal app or any other program).")
  (zlogin
   (text-config '())
   "List of strings or gexps, which will be added to @file{.zlogin}.
Used for executing user's commands at the end of starting process of
login shell.")
  (zlogout
   (text-config '())
   "List of strings or gexps, which will be added to @file{.zlogout}.
Used for executing user's commands at the exit of login shell.  It
won't be read in some cases (if the shell terminates by exec'ing
another process for example)."))

(define (add-zsh-configuration config)
  (let* ((xdg-flavor? (home-zsh-configuration-xdg-flavor? config)))

    (define prefix-file
      (cut string-append
	(if xdg-flavor?
	    "config/zsh/."
	    "") <>))

    (define (filter-fields field)
      (filter-configuration-fields home-zsh-configuration-fields
				   (list field)))

    (define (serialize-field field)
      (serialize-configuration
       config
       (filter-fields field)))

    (define (file-if-not-empty field)
      (let ((file-name (symbol->string field))
	    (field-obj (car (filter-fields field))))
	(if (not (null? ((configuration-field-getter field-obj) config)))
	    `(,(prefix-file file-name)
	      ,(mixed-text-file
		file-name
		(serialize-field field)))
	    '())))

    (filter
     (compose not null?)
     `(,(if xdg-flavor?
	    `("zshenv"
	      ,(mixed-text-file
		"auxiliary-zshenv"
		(if xdg-flavor?
		    "source ${XDG_CONFIG_HOME:-$HOME/.config}/zsh/.zshenv\n"
		    "")))
	    '())
       (,(prefix-file "zshenv")
	,(mixed-text-file
	  "zshenv"
	  (if xdg-flavor?
	      "export ZDOTDIR=${XDG_CONFIG_HOME:-$HOME/.config}/zsh\n"
	      "")
	  (serialize-field 'zshenv)))
       (,(prefix-file "zprofile")
	,(mixed-text-file
	  "zprofile"
	  "\
# Setups system and user profiles and related variables
source /etc/profile
# Setups home environment profile
source ~/.profile

# It's only necessary if zsh is a login shell, otherwise profiles will
# be already sourced by bash
"
	  (serialize-field 'zprofile)))

       ,@(list (file-if-not-empty 'zshrc)
	       (file-if-not-empty 'zlogin)
	       (file-if-not-empty 'zlogout))))))

(define (add-zsh-packages config)
  (list (home-zsh-configuration-package config)))

(define-configuration home-zsh-extension
  (zshrc
   (text-config '())
   "List of strings or gexps.")
  (zshenv
   (text-config '())
   "List of strings or gexps.")
  (zprofile
   (text-config '())
   "List of strings or gexps.")
  (zlogin
   (text-config '())
   "List of strings or gexps.")
  (zlogout
   (text-config '())
   "List of strings or gexps."))

(define (home-zsh-extensions original-config extension-configs)
  (home-zsh-configuration
   (inherit original-config)
   (zshrc
    (append (home-zsh-configuration-zshrc original-config)
	    (append-map
	     home-zsh-extension-zshrc extension-configs)))
   (zshenv
    (append (home-zsh-configuration-zshenv original-config)
	    (append-map
	     home-zsh-extension-zshenv extension-configs)))
   (zprofile
    (append (home-zsh-configuration-zprofile original-config)
	    (append-map
	     home-zsh-extension-zprofile extension-configs)))
   (zlogin
    (append (home-zsh-configuration-zlogin original-config)
	    (append-map
	     home-zsh-extension-zlogin extension-configs)))
   (zlogout
    (append (home-zsh-configuration-zlogout original-config)
	    (append-map
	     home-zsh-extension-zlogout extension-configs)))))

(define home-zsh-service-type
  (service-type (name 'home-zsh)
                (extensions
                 (list (service-extension
                        home-files-service-type
                        add-zsh-configuration)
                       (service-extension
                        home-profile-service-type
                        add-zsh-packages)))
		(compose identity)
		(extend home-zsh-extensions)
                (default-value (home-zsh-configuration))
                (description "Install and configure Zsh.")))

;; (define-record-type* <home-bash-configuration>
;;   home-bash-configuration make-home-bash-configuration
;;   home-bash-configuration?
;;   (package     home-bash-configuration-package
;;                (default bash)))

;; (define (add-bash-packages config)
;;   (append
;;    (list (home-bash-configuration-package config))))

;; (define home-bash-service-type
;;   (service-type (name 'home-bash)
;;                 (extensions
;;                  (list (service-extension
;; 			home-files-service-type
;; 			add-bash-configs)
;; 		       (service-extension
;; 			home-profile-service-type
;; 			)))
;; 		(default-value (home-gnupg-configuration))
;;                 (description "Configure and install gpg-agent.")))