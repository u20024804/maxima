;********************************************************
; file:        init-cl.lisp                              
; description: Initialize Maxima                         
; date:        Wed Jan 13 1999 - 20:27                   
; author:      Liam Healy <Liam.Healy@nrl.navy.mil>      
;********************************************************

(in-package :maxima)

;;; An ANSI-CL portable initializer to replace init_max1.lisp

(defvar *maxima-prefix*)
(defvar *maxima-datadir*)
(defvar *maxima-infodir*)
(defvar *maxima-plotdir*)
(defvar *maxima-verpkglibexecdir*)
(defvar *maxima-verpkgdatadir*)
(defvar *maxima-libexecdir*)
(defvar *maxima-userdir*)

(defun maxima-path (dir file)
   (format nil "~a/~a/~a" *maxima-prefix* dir file))

(defun maxima-data-path (dir file)
   (format nil "~a/~a/~a"
	   *maxima-verpkgdatadir* dir file))

(defvar $file_search_lisp nil
  "Directories to search for Lisp source code.")

(defvar $file_search_maxima nil
  "Directories to search for Maxima source code.")

(defvar $file_search_demo nil
  "Directories to search for demos.")

(defvar $file_search_usage nil)
(defvar $chemin nil)

#+gcl
(defun maxima-getenv (envvar)
  (si::getenv envvar))

#+allegro
(defun maxima-getenv (envvar)
  (system:getenv envvar))

#+cmu
(defun maxima-getenv (envvar)
  (cdr (assoc envvar ext:*environment-list* :test #'string=)))

#+sbcl
(defun maxima-getenv (envvar)
  (sb-ext:posix-getenv envvar))

#+clisp
(defun maxima-getenv (envvar)
  (ext:getenv envvar))

#+mcl
(defun maxima-getenv (envvar)
  (ccl::getenv envvar))

(defun set-pathnames ()
  (let ((maxima-prefix-env (maxima-getenv "MAXIMA_PREFIX"))
	(maxima-datadir-env (maxima-getenv "MAXIMA_DATADIR"))
	(maxima-infodir-env (maxima-getenv "MAXIMA_INFODIR"))
	(maxima-plotdir-env (maxima-getenv "MAXIMA_PLOTDIR"))
	(maxima-userdir-env (maxima-getenv "MAXIMA_USERDIR"))
	(maxima-verpkgdatadir-env (maxima-getenv "MAXIMA_VERPKGDATADIR"))
	(home-env (maxima-getenv "HOME")))
    ;; MAXIMA_DIRECTORY is a deprecated substitute for MAXIMA_PREFIX
    (if (not maxima-prefix-env)
	(setq maxima-prefix-env (maxima-getenv "MAXIMA_DIRECTORY")))
    (if maxima-prefix-env
	(setq *maxima-prefix* maxima-prefix-env)
      (setq *maxima-prefix* *autoconf-prefix*))
    (if maxima-datadir-env
	(setq *maxima-datadir* maxima-datadir-env)
      (if maxima-prefix-env
	  (setq *maxima-datadir* (concatenate 'string *maxima-prefix*
					      "/"
					      "share"))
	(setq *maxima-datadir* *autoconf-datadir*)))
    (if maxima-verpkgdatadir-env
	(setq *maxima-verpkgdatadir* maxima-verpkgdatadir-env)
      (setq *maxima-verpkgdatadir* (concatenate 'string
						*maxima-datadir*
						"/"
						*autoconf-package*
						"/"
						*autoconf-version*)))
    (if maxima-prefix-env
	(setq *maxima-libexecdir* (concatenate 'string *maxima-prefix*
					       "/"
					       "libexec"))
      (setq *maxima-libexecdir* *autoconf-libexecdir*))
    (setq *maxima-verpkglibexecdir* (concatenate 'string
						 *maxima-libexecdir*
						 "/"
						 *autoconf-package*
						 "/"
						 *autoconf-version*))
    (if maxima-plotdir-env
	(setq *maxima-plotdir* (maxima-getenv "MAXIMA_PLOTDIR"))
      (setq *maxima-plotdir* *maxima-verpkglibexecdir*))
    (if maxima-infodir-env
	(setq *maxima-infodir* maxima-infodir-env)
      (if maxima-prefix-env
	  (setq *maxima-infodir* (concatenate 'string *maxima-prefix*
					      "/"
					      "info"))
	(setq *maxima-infodir* *autoconf-infodir*)))
    (if maxima-userdir-env
	(setq *maxima-userdir* maxima-userdir-env)
      (setq *maxima-userdir* (concatenate 'string home-env "/.maxima"))))
	 
  
  (let* ((ext #+gcl "o"
	      #+cmu (c::backend-fasl-file-type c::*target-backend*)
	      #+sbcl "fasl"
	      #+clisp "fas"
	      #+allegro "fasl"
	      #+(and openmcl darwinppc-target) "dfsl"
	      #+(and openmcl linuxppc-target) "pfsl"
	      #-(or gcl cmu sbcl clisp allegro openmcl)
	      "")
	 (lisp-patterns (concatenate 'string
				     "###.{"
				     (concatenate 'string ext ",lisp,lsp}")))
	 (share-with-subdirs "{share,share/algebra,share/calculus,share/combinatorics,share/contrib,share/contrib/nset,share/contrib/pdiff,share/diffequations,share/graphics,share/integequations,share/integration,share/macro,share/matrix,share/misc,share/numeric,share/physics,share/simplification,share/specfunctions,share/sym,share/tensor,share/trigonometry,share/utils,share/vector}"))
    (setq $file_search_lisp
	  (list '(mlist)
		;; actually, this entry is not correct.
		;; there should be a separate directory for compiled
		;; lisp code. jfa 04/11/02
		(concatenate 'string *maxima-userdir* "/" lisp-patterns)
		(maxima-data-path share-with-subdirs lisp-patterns)
		(maxima-data-path "src" lisp-patterns)))
  (setq $file_search_maxima
	(list '(mlist)
	      (concatenate 'string *maxima-userdir* "/" "###.{mac,mc}")
	      (maxima-data-path share-with-subdirs "###.{mac,mc}")))
  (setq $file_search_demo
	(list '(mlist)
	      (maxima-data-path share-with-subdirs
					 "###.{dem,dm1,dm2,dm3,dmt}")
	      (maxima-data-path "{demo}"
					 "###.{dem,dm1,dm2,dm3,dmt}")))
  (setq $file_search_usage
	(list '(mlist) (maxima-data-path share-with-subdirs
					 "###.{usg,texi}")
	      (maxima-data-path "doc" "###.{mac}")))
  (setq $chemin
	(maxima-data-path "sym" ""))
  (setq cl-info::*info-paths* (list (concatenate 'string
					    *maxima-infodir* "/")))))

;#+gcl (setq si::*top-level-hook* 'user::run)
(defun user::run ()
  "Run Maxima in its own package."
  (in-package "MAXIMA")
  (setf *load-verbose* nil)
  (setf *debugger-hook* #'maxima-lisp-debugger)
  ; jfa new command-line communication
  (let ((input-string *standard-input*)
	(maxima_int_lisp_preload (maxima-getenv "MAXIMA_INT_LISP_PRELOAD"))
	(maxima_int_input_string (maxima-getenv "MAXIMA_INT_INPUT_STRING"))
	(batch-flag (maxima-getenv "MAXIMA_INT_BATCH_FLAG")))
    (if maxima_int_lisp_preload
	(load maxima_int_lisp_preload))
    (if maxima_int_input_string
	(setq input-string (make-string-input-stream maxima_int_input_string)))

    #+allegro
    (progn
      (set-readtable-for-macsyma)
      (setf *read-default-float-format* 'lisp::double-float))
      
    (catch 'to-lisp
      (set-pathnames)
      #+(or cmu sbcl clisp allegro mcl)
      (progn
	(loop 
	  (with-simple-restart (macsyma-quit "Macsyma top-level")
			       (macsyma-top-level input-string batch-flag))))
      #-(or cmu sbcl clisp allegro mcl)
      (catch 'macsyma-quit
	(macsyma-top-level input-string batch-flag)))))

(import 'user::run)
  
($setup_autoload "eigen.mac" '$eigenvectors '$eigenvalues)

(defun $to_lisp ()
  (format t "~&Type (to-maxima) to restart~%")
  (let ((old-debugger-hook *debugger-hook*))
    (catch 'to-maxima
      (unwind-protect
	  (maxima-read-eval-print-loop)
	(setf *debugger-hook* old-debugger-hook)
	(format t "Returning to Maxima~%"))))
)

(defun to-maxima ()
  (throw 'to-maxima t))

(defun maxima-read-eval-print-loop ()
  (setf *debugger-hook* #'maxima-lisp-debugger-repl)
  (loop
   (catch 'to-maxima-repl
     (format t "~a~%~a> ~a" *prompt-prefix* 
	     (package-name *package*) *prompt-suffix*)
     (let ((form (read)))
       (prin1 (eval form))))))

(defun maxima-lisp-debugger-repl (condition me-or-my-encapsulation)
  (format t "~&Maxima encountered a Lisp error:~%~% ~A" condition)
  (format t "~&~%Automatically continuing.~%To reenable the Lisp debugger set *debugger-hook* to nil.~%")
  (throw 'to-maxima-repl t))

(defun $jfa_lisp ()
  (format t "jfa was here"))

(defvar $help "type describe(topic) or example(topic);")

(defun $help () $help)			;

;; CMUCL needs because when maxima reaches EOF, it calls BYE, not $QUIT.
#+cmu
(defun bye ()
  (ext:quit))

#+sbcl
(defun bye ()
  (sb-ext:quit))

#+allegro
(defun bye ()
  (excl:exit))

#+mcl
(defun bye ()
  (ccl::quit))

(defun $maxima_server (port)
  (load "/home/amundson/devel/maxima/archive/src/server.lisp")
  (user::setup port))
