;;; -*-  Mode: Lisp; Package: Maxima; Syntax: Common-Lisp; Base: 10 -*- ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;     The data in this file contains enhancments.                    ;;;;;
;;;                                                                    ;;;;;
;;;  Copyright (c) 1984,1987 by William Schelter,University of Texas   ;;;;;
;;;     All rights reserved                                            ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;     (c) Copyright 1982 Massachusetts Institute of Technology         ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package :maxima)

(macsyma-module combin)

(declare-top (special *mfactl *factlist donel nn* dn* *ans* *var*
		      dict ans var
		      a* $zerobern *a *n $cflength *a* $prevfib hi lo
		      *infsumsimp *times *plus sum usum makef
		      varlist genvar $sumsplitfact gensim $ratfac $simpsum
		      $prederror $listarith
		      $ratprint $zeta%pi $bftorat))

(load-macsyma-macros mhayat rzmac ratmac)

;; minfactorial and factcomb stuff

(defmfun $makefact (e)
  (let ((makef t)) (if (atom e) e (simplify (makefact1 e)))))

(defun makefact1 (e)
  (cond ((atom e) e)
	((eq (caar e) '%binomial)
	 (subst (makefact1 (cadr e)) 'x
		(subst (makefact1 (caddr e)) 'y
		       '((mtimes) ((mfactorial) x)
			 ((mexpt) ((mfactorial) y) -1)
			 ((mexpt) ((mfactorial) ((mplus) x ((mtimes) -1 y)))
			  -1)))))
	((eq (caar e) '%gamma)
	 (list '(mfactorial) (list '(mplus) -1 (makefact1 (cadr e)))))
	((eq (caar e) '$beta)
	 (makefact1 (subst (cadr e) 'x
			   (subst (caddr e) 'y
				  '((mtimes) ((%gamma) x)
				    ((%gamma) y)
				    ((mexpt) ((%gamma) ((mplus) x y)) -1))))))
	(t (recur-apply #'makefact1 e))))

(defmfun $makegamma (e)
  (if (atom e) e (simplify (makegamma1 ($makefact e)))))

(defmfun $minfactorial (e)
  (let (*mfactl *factlist)
    (if (specrepp e) (setq e (specdisrep e)))
    (getfact e)
    (mapl #'evfac1 *factlist)
    (setq e (evfact e))))

(defun evfact (e)
  (cond ((atom e) e)
	((eq (caar e) 'mfactorial)
	 (cdr (assoc (cadr e) *factlist :test #'equal)))
	((member  (caar e) '(%sum %derivative %integrate %product) :test #'eq)
	 (cons (list (caar e)) (cons (evfact (cadr e)) (cddr e))))
	(t (recur-apply #'evfact e))))

(defun adfactl (e l)
  (let (n)
    (cond ((null l) (push (list e) *mfactl))
	  ((numberp (setq n ($ratsimp `((mplus) ,e ((mtimes) -1 ,(caar l))))))
	   (cond ((plusp n)
		  (rplacd (car l) (cons e (cdar l))))
		 ((rplaca l (cons e (car l))))))
	  ((adfactl e (cdr l))))))

(defun getfact (e)
  (cond ((atom e) nil)
	((eq (caar e) 'mfactorial)
	 (and (null (member (cadr e) *factlist :test #'equal))
	      (prog2
		  (push (cadr e) *factlist)
		  (adfactl (cadr e) *mfactl))))
	((member (caar e) '(%sum %derivative %integrate %product) :test #'eq)
	 (getfact (cadr e)))
	((mapc #'getfact (cdr e)))))

(defun evfac1 (e)
  (do ((al *mfactl (cdr al)))
      ((member (car e) (car al) :test #'equal)
       (rplaca e
	       (cons (car e)
		     (list '(mtimes)
			   (gfact (car e)
				  ($ratsimp (list '(mplus) (car e)
						  (list '(mtimes) -1 (caar al)))) 1)
			   (list '(mfactorial) (caar al))))))))
(defmfun $factcomb (e)
  (let ((varlist varlist ) genvar $ratfac (ratrep (and (not (atom e)) (eq (caar e) 'mrat))))
    (and ratrep (setq e (ratdisrep e)))
    (setq e (factcomb e)
	  e (cond ((atom e) e)
		  (t (simplify (cons (list (caar e))
				     (mapcar #'factcomb1 (cdr e)))))))
    (or $sumsplitfact (setq e ($minfactorial e)))
    (if ratrep (ratf e)	e)))

(defun factcomb1 (e)
  (cond ((free e 'mfactorial) e)
	((member (caar e) '(mplus mtimes mexpt) :test #'eq)
	 (cons (list (caar e)) (mapcar #'factcomb1 (cdr e))))
	(t (setq e (factcomb e))
	   (if (atom e)
	       e
	       (cons (list (caar e)) (mapcar #'factcomb1 (cdr e)))))))

(defun factcomb (e)
  (cond ((atom e) e)
	((free e 'mfactorial) e)
	((member (caar e) '(mplus mtimes) :test #'eq)
	 (factpluscomb (factcombplus e)))
	((eq (caar e) 'mexpt)
	 (simpexpt (list '(mexpt) (factcomb (cadr e))
			 (factcomb (caddr e)))
		   1 nil))
	((eq (caar e) 'mrat)
	 (factrat e))
	(t (cons (car e) (mapcar #'factcomb (cdr e))))))

(defun factrat (e)
  (let (nn* dn*)
    (setq e (factqsnt ($ratdisrep (cons (car e) (cons (cadr e) 1)))
		      ($ratdisrep (cons (car e) (cons (cddr e) 1)))))
    (numden e)
    (div* (factpluscomb nn*) (factpluscomb dn*))))

(defun factqsnt (num den)
  (if (equal num 0) 0
      (let (nn* dn* (e (factpluscomb (div* den num))))
	(numden e)
	(factpluscomb (div* dn* nn*)))))

(defun factcombplus (e)
  (let (nn* dn*)
    (do ((l1 (nplus e) (cdr l1))
	 (l2))
	((null l1)
	 (simplus (cons '(mplus)
			(mapcar #'(lambda (q) (factqsnt (car q) (cdr q))) l2))
		  1 nil))
      (numden (car l1))
      (do ((l3 l2 (cdr l3))
	   (l4))
	  ((null l3) (setq l2 (nconc l2 (list (cons nn* dn*)))))
	(setq l4 (car l3))
	(cond ((not (free ($gcd dn* (cdr l4)) 'mfactorial))
	       (numden (list '(mplus) (div* nn* dn*)
			     (div* (car l4) (cdr l4))))
	       (setq l2 (delete l4 l2 :count 1 :test #'eq))))))))

(defun factpluscomb (e)
  (prog (donel fact indl tt)
   tag (setq e (factexpand e)
	     fact (getfactorial e))
   (or fact (return e))
   (setq indl (mapcar #'(lambda (q) (factplusdep q fact))
		      (nplus e))
	 tt (factpowerselect indl (nplus e) fact)
	 e (cond ((cdr tt)
		  (cons '(mplus) (mapcar #'(lambda (q) (factplus2 q fact))
					 tt)))
		 (t (factplus2 (car tt) fact))))
   (go tag)))

(defun nplus (e)
  (if (eq (caar e) 'mplus)
      (cdr e)
      (list e)))

(defun factexpand (e)
  (cond ((atom e) e)
	((eq (caar e) 'mplus)
	 (simplus (cons '(mplus) (mapcar #'factexpand (cdr e)))
		  1 nil))
	((free e 'mfactorial) e)
	(t ($expand e))))

(defun getfactorial (e)
  (cond ((atom e) nil)
	((member (caar e) '(mplus mtimes) :test #'eq)
	 (do ((e (cdr e) (cdr e))
	      (a))
	     ((null e) nil)
	   (setq a (getfactorial (car e)))
	   (and a (return a))))
	((eq (caar e) 'mexpt)
	 (getfactorial (cadr e)))
	((eq (caar e) 'mfactorial)
	 (and (null (memalike (cadr e) donel))
	      (list '(mfactorial)
		    (car (setq donel (cons (cadr e) donel))))))))

(defun factplusdep (e fact)
  (cond ((alike1 e fact) 1)
	((atom e) nil)
	((eq (caar e) 'mtimes)
	 (do ((l (cdr e) (cdr l))
	      (e) (out))
	     ((null l) nil)
	   (setq e (car l))
	   (and (setq out (factplusdep e fact))
		(return out))))
	((eq (caar e) 'mexpt)
	 (let ((fto (factplusdep (cadr e) fact)))
	   (and fto (simptimes (list '(mtimes) fto
				     (caddr e)) 1 t))))
	((eq (caar e) 'mplus)
	 (same (mapcar #'(lambda (q) (factplusdep q fact))
		       (cdr e))))))

(defun same (l)
  (do ((ca (car l))
       (cd (cdr l) (cdr cd))
       (cad))
      ((null cd) ca)
    (setq cad (car cd))
    (or (alike1 ca cad)
	(return nil))))

(defun factpowerselect (indl e fact)
  (let (l fl)
    (do ((i indl (cdr i))
	 (j e (cdr j))
	 (expt) (exp))
	((null i) l)
      (setq expt (car i)
	    exp (cond (expt
		       (setq exp ($divide (car j) `((mexpt) ,fact ,expt)))
		       ;; (car j) need not involve fact^expt since
		       ;; fact^expt may be the gcd of the num and denom
		       ;; of (car j) and $divide will cancel this out.
		       (if (not (equal (cadr exp) 0))
			   (cadr exp)
			   (progn
			     (setq expt '())
			     (caddr exp))))
		      (t (car j))))
      (cond ((null l) (setq l (list (list expt exp))))
	    ((setq fl (assolike expt l))
	     (nconc fl (list exp)))
	    (t (nconc l (list (list expt exp))))))))

(defun factplus2 (l fact)
  (let ((expt (car l)))
    (cond (expt (factplus0 (cond ((cddr l) (rplaca l '(mplus)))
				 (t (cadr l)))
			   expt (cadr fact)))
	  (t (rplaca l '(mplus))))))

(defun factplus0 (r e fact)
  (do ((i -1 (1- i))
       (fpn fact (list '(mplus) fact i))
       (j -1) (exp) (rfpn) (div))
      (nil)
    (setq rfpn (simpexpt (list '(mexpt) fpn -1) 1 nil))
    (setq div (dypheyed r (simpexpt (list '(mexpt) rfpn e) 1 nil)))
    (cond ((or (null (or $sumsplitfact (equal (cadr div) 0)))
	       (equal (car div) 0))
	   (return (simplus (cons '(mplus) (mapcar
					    #'(lambda (q)
						(incf j)
						(list '(mtimes) q (list '(mexpt)
									(list '(mfactorial) (list '(mplus) fpn j)) e)))
					    (factplus1 (cons r exp) e fpn)))
			    1 nil)))
	  (t (setq r (car div))
	     (setq exp (cons (cadr div) exp))))))

(defun factplus1 (exp e fact)
  (do ((l exp (cdr l))
       (i 2 (1+ i))
       (fpn (list '(mplus) fact 1) (list '(mplus) fact i))
       (div))
      ((null l) exp)
    (setq div (dypheyed (car l) (list '(mexpt) fpn e)))
    (and (or $sumsplitfact (equal (cadr div) 0))
	 (null (equal (car div) 0))
	 (rplaca l (cadr div))
	 (rplacd l (cons (cond ((cadr l)
				(simplus (list '(mplus) (car div) (cadr l))
					 1 nil))
			       (t
				(setq donel
				      (cons (simplus fpn 1 nil) donel))
				(car div)))
			 (cddr l))))))

(defun dypheyed (r f)
  (let (r1 p1 p2)
    (newvar r)
    (setq r1 (ratf f)
	  p1 (pdegreevector (cadr r1))
	  p2 (pdegreevector (cddr r1)))
    (do ((i p1 (cdr i))
	 (j p2 (cdr j))
	 (k (caddar r1) (cdr k)))
	((null k) (kansel r (cadr r1) (cddr r1)))
      (cond ((> (car i) (car j))
	     (return (cdr ($divide r f (car k)))))))))

(defun kansel (r n d)
  (let (r1 p1 p2)
    (setq r1 (ratf r)
	  p1 (testdivide (cadr r1) n)
	  p2 (testdivide (cddr r1) d))
    (if (and p1 p2)
	(cons (rdis (cons p1 p2)) '(0))
	(cons '0 (list r)))))

;; euler and bernoulli stuff

(defvar *bn* (make-array 17 :adjustable t :element-type 'integer
			 :initial-contents '(0 -1 1 -1 5. -691. 7. -3617. 43867. -174611. 854513.
					     -236364091. 8553103. -23749461029. 8615841276005.
					     -7709321041217. 2577687858367.)))

(defvar *bd* (make-array 17 :adjustable t :element-type 'integer
			 :initial-contents '(0 30. 42. 30. 66. 2730. 6. 510. 798. 330. 138. 2730.
					     6. 870. 14322.  510. 6.)))

(defvar *eu* (make-array 11 :adjustable t :element-type 'integer
			 :initial-contents '(-1 5. -61. 1385. -50521. 2702765. -199360981. 19391512145.
					     -2404879675441. 370371188237525. -69348874393137901.)))

(putprop '*eu* 11 'lim)
(putprop 'bern 16 'lim)

(defmfun $euler (s)
  (setq s
	(let ((%n 0) $float)
	  (cond ((or (not (fixnump s)) (< s 0)) (list '($euler) s))
		((zerop (setq %n s)) 1)
		($zerobern
		 (cond ((oddp %n) 0)
		       ((null (> (ash %n -1) (get '*eu* 'lim)))
			(aref *eu* (1- (ash %n -1))))
		       ((eq $zerobern '%$/#&)
			(euler %n))
		       ((adjust-array *eu* (1+ (ash %n -1))) 
			(euler %n))))
		((<= %n (get '*eu* 'lim))
		 (aref *eu* (1- %n)))
		((adjust-array *eu* (1+ %n))
		 (euler (* 2 %n))))))
  (simplify s))

(defun euler (%a*)
  (prog (nom %k e fl $zerobern *a*)
     (setq nom 1 %k %a* fl nil e 0 $zerobern '%$/#& *a* (1+ %a*))
     a	(cond ((zerop %k)
	       (setq e (- e))
	       (setf (aref *eu* (1- (ash %a* -1))) e)
	       (putprop '*eu* (ash %a* -1) 'lim)
	       (return e)))
     (setq nom (nxtbincoef (1+ (- %a* %k)) nom) %k (1- %k))
     (cond ((setq fl (null fl))
	    (go a)))
     (incf e (* nom ($euler %k)))
     (go a)))

(defmfun simpeuler (x vestigial z) 
  (declare (ignore vestigial))
  (oneargcheck x)
  (let ((u (simpcheck (cadr x) z)))
    (if (and (fixnump u) (>= u 0))
	($euler u)
	(eqtest (list '($euler) u) x))))

(defmfun $bern (s)
  (setq s 
	(let ((%n 0) $float)
	  (cond ((or (not (fixnump s)) (< s 0)) (list '($bern) s))
		((= (setq %n s) 0) 1)
		((= %n 1) '((rat) -1 2))
		((= %n 2) '((rat) 1 6))
		($zerobern
		 (cond ((oddp %n) 0)
		       ((null (> (setq %n (1- (ash %n -1))) (get 'bern 'lim)))
			(list '(rat) (aref *bn* %n) (aref *bd* %n)))
		       ((eq $zerobern '$/#&) (bern  (* 2 (1+ %n))))
		       (t (adjust-array *bn* (setq %n (1+ %n)))
			  (adjust-array *bd* %n) (bern  (* 2 %n)))))
		((null (> %n (get 'bern 'lim)))
		 (list '(rat) (aref *bn* %n) (aref *bd* %n)))
		(t (adjust-array *bn* (1+ %n)) (adjust-array *bd* (1+ %n))
		   (bern %n)))))
  (simplify s))

(defun bern (%a*)
  (prog (nom %k bb a b $zerobern l *a*)
     (setq %k 0
	   l (1- %a*)
	   %a* (1+ %a*)
	   nom 1
	   $zerobern '$/#&
	   a 1
	   b 1
	   *a* (1+ %a*))
     a	(cond ((= %k l)
	       (setq bb (*red a (* -1 b %a*)))
	       (putprop 'bern (setq %a* (1- (ash %a* -1))) 'lim)
	       (setf (aref *bn* %a*) (cadr bb))
	       (setf (aref *bd* %a*) (caddr bb))
	       (return bb)))
     (incf %k)
     (setq a (+ (* b (setq nom (nxtbincoef %k nom))
			  (num1 (setq bb ($bern %k))))
		   (* a (denom1 bb))))
     (setq b (* b (denom1 bb)))
     (setq a (*red a b) b (denom1 a) a (num1 a))
     (go a)))

(defmfun simpbern (x vestigial z) 
  (declare (ignore vestigial))
  (oneargcheck x)
  (let ((u (simpcheck (cadr x) z)))
    (if (and (fixnump u) (not (< u 0)))
	($bern u)
	(eqtest (list '($bern) u) x))))

(defmfun $bernpoly (x s)
  (let ((%n 0))
    (cond ((not (fixnump s)) (list '($bernpoly) x s))
	  ((> (setq %n s) -1)
	   (do ((sum (cons (if (and (= %n 0) (zerop1 x))
			       (addk 1 x)
			       (power x %n)) nil)
		     (cons (m* (timesk (binocomp %n %k) ($bern %k))
			       (if (and (= %n %k) (zerop1 x))
				   (addk 1 x)
				   (m^ x (- %n %k))))
			   sum))
		(%k 1 (1+ %k)))
	       ((> %k %n) (addn sum t))))
	  (t (list '($bernpoly) x %n)))))

;; zeta and fibonacci stuff

(defmfun $zeta (s)
  (cond (($bfloatp s) (mfuncall '$bfzeta s $fpprec))
	((or (floatp s) (and (or $numer $float) (integerp s)))
	 (let (($float2bf t))
	   ($float (mfuncall '$bfzeta s 18))))
	((null (fixnump s)) (list '($zeta) s))
	((oddp s)
	 (cond ((> s 1)
		(list '($zeta) s))
	       ((= 1 s) '$inf)
	       ((setq s (sub 1 s))
		(mult -1 (div ($bern s) s)))))
	((equal s 0) '((rat simp) -1 2))
	((minusp s) 0)
	((not $zeta%pi) (list '($zeta) s))
	(t (let ($numer $float)
	     (setq s (mul2 (power '$%pi s)
			   (timesk (*red (expt 2 (1- s)) (factorial s))
				   (simpabs (list 'mabs ($bern s)) 1 nil)))))
	   (resimplify s))))

(defmfun $fib (n) 
  (cond ((fixnump n) (ffib n))
	(t (setq $prevfib (list '($fib) (add2* n -1)))
	   (list '($fib) n))))

(defun ffib (%n) 
  (cond ((or (eql %n -1) (zerop %n))
	 (setq $prevfib (boole boole-ior %n 1) *a (- %n)))
	(t
	 (let ((x (+ (ffib (ash (boole  boole-andc2 %n 1) -1)) $prevfib))
	       (y (* $prevfib $prevfib))
	       (z (* *a *a)))
	   (setq *a (- (* x x) y)
		 $prevfib (+ y z)))
	 (cond ((oddp %n)
		(setq *a (prog1
			     (+ *a $prevfib)
			   (setq $prevfib *a))))
	       (*a)))))

;; continued fraction stuff

(defmfun $cfdisrep (a)
  (cond ((not ($listp a))
	 (merror "Arg to `cfdisrep' not a list: ~M" a))
	((null (cddr a)) (cadr a))
	((equal (cadr a) 0)
	 (list '(mexpt) (cfdisrep1 (cddr a)) -1))
	((cfdisrep1 (cdr a)))))

(defun cfdisrep1 (a)
  (cond ((cdr a)
	 (list '(mplus simp cf) (car a)
	       (prog2 (setq a (cfdisrep1 (cdr a)))
		   (cond ((integerp a) (list '(rat simp) 1 a))
			 (t (list '(mexpt simp) a -1))))))
	((car a))))

(defun cfmak (a)
  (setq a (meval a))
  (cond ((integerp a) (list a))
	((eq (caar a) 'mlist) (cdr a))
	((eq (caar a) 'rat) (ratcf (cadr a) (caddr a)))
	((merror "Continued fractions must be lists or integers"))))

(defun makcf (a)
  (cond ((null (cdr a)) (car a))
	((cons '(mlist simp cf) a))))

;;; Translation properties for $CF defined in MAXSRC;TRANS5 >

(defmspec $cf (a)
  (cfratsimp  (let ($listarith)
		(cfeval (meval (fexprcheck a))))))

;; Definition of cfratsimp as given in SF bug report # 620928.
(defun cfratsimp (a)
  (cond ((atom a) a)
        ((member 'cf (car a) :test #'eq) a)
        (t (cons '(mlist cf simp)
                 (apply 'find-cf (cf-back-recurrence (cdr a)))))))

; Code to expand nth degree roots of integers into continued fraction
; approximations. E.g. cf(2^(1/3))
; Courtesy of Andrei Zorine (feniy@mail.nnov.ru) 2005/05/07

(defun cfnroot(b)
  (let ((ans (list '(mlist xf))) ent ($algebraic $true))
    (dotimes (i $cflength (nreverse ans))
      (setq ent (meval `(($floor) ,b))
	    ans (cons ent ans)
	    b ($ratsimp (m// (m- b ent)))))))

(defun cfeval (a)
  (let (temp $ratprint)
    (cond ((integerp a) (list '(mlist cf) a))
	  ((floatp a)
	   (let ((a (maxima-rationalize a)))
	     (cons '(mlist cf) (ratcf (car a) (cdr a)))))
	  (($bfloatp a)
	   (let (($bftorat t))
	     (setq a (bigfloat2rat a))
	     (cons '(mlist cf) (ratcf (car a) (cdr a)))))
	  ((atom a)
	   (merror "~:M - not a continued fraction" a))
	  ((eq (caar a) 'rat)
	   (cons '(mlist cf) (ratcf (cadr a) (caddr a))))
	  ((eq (caar a) 'mlist)
	   (cfratsimp a))
	  ;;the following doesn't work for non standard form
	  ;;		(cfplus a '((mlist) 0)))
	  ((and (mtimesp a) (cddr a) (null (cdddr a))
		(fixnump (cadr a))
		(mexptp (caddr a))
		(fixnump (cadr (caddr a)))
		(alike1 (caddr (caddr a)) '((rat) 1 2)))
	   (cfsqrt (cfeval (* (expt (cadr a) 2) (cadr (caddr a))))))
	  ((eq (caar a) 'mexpt)
	   (cond ((alike1 (caddr a) '((rat) 1 2))
		  (cfsqrt (cfeval (cadr a))))
		 ((integerp (m- (caddr a) '((rat) 1 2)))
		  (cftimes (cfsqrt (cfeval (cadr a)))
			   (cfexpt (cfeval (cadr a))
				   (m- (caddr a) '((rat) 1 2)))))
		 ((integerp (cadr a)) (cfnroot a)) ; <=== new case x
		 ((cfexpt (cfeval (cadr a)) (caddr a)))))
	  ((setq temp (assoc (caar a) '((mplus . cfplus) (mtimes . cftimes) (mquotient . cfquot)
				       (mdifference . cfdiff) (mminus . cfminus)) :test #'eq))
	   (cf (cfeval (cadr a)) (cddr a) (cdr temp)))
	  ((eq (caar a) 'mrat)
	   (cfeval ($ratdisrep a)))
	  (t (merror "Not a continued fraction:~%~M" a)))))

(defun cf (a l fun)
  (cond ((null l) a)
	((cf (funcall fun a (meval (list '($cf) (car l)))) (cdr l) fun))))

(defun cfplus (a b)
  (setq a (cfmak a) b (cfmak b))
  (makcf (cffun '(0 1 1 0) '(0 0 0 1) a b)))

(defun cftimes (a b)
  (setq a (cfmak a) b (cfmak b))
  (makcf (cffun '(1 0 0 0) '(0 0 0 1) a b)))

(defun cfdiff (a b)
  (setq a (cfmak a) b (cfmak b))
  (makcf (cffun '(0 1 -1 0) '(0 0 0 1) a b)))

(defun cfmin (a)
  (setq a (cfmak a))
  (makcf (cffun '(0 0 -1 0) '(0 0 0 1) a '(0))))

(defun cfquot (a b)
  (setq a (cfmak a) b (cfmak b))
  (makcf (cffun '(0 1 0 0) '(0 0 1 0) a b)))

(defun cfexpt (b e)
  (setq b (cfmak b))
  (cond ((null (integerp e))
	 (merror "Can't raise continued fraction to non-integral powers"))
	((let ((n (abs e)))
	   (do ((n (ash n -1) (ash n -1))
		(s (cond ((oddp n) b)
			 (t '(1)))))
	       ((zerop n)
		(makcf
		 (cond ((signp g e)
			s)
		       ((cffun '(0 0 0 1) '(0 1 0 0) b '(1))))))
	     (setq b (cffun '(1 0 0 0) '(0 0 0 1) b b))
	     (and (oddp n)
		  (setq s (cffun '(1 0 0 0) '(0 0 0 1) s b))))))))


(defun conf1 (f g a b &aux (den (conf2 g a b)))
  (cond ((zerop den)
	 (* (signum (conf2 f a b )) ; (/ most-positive-fixnum (^ 2 4))
	    #.(expt 2 31)))
	(t (truncate (conf2 f a b) den))))

(defun conf2 (n a b)			;2*(abn_0+an_1+bn_2+n_3)
  (* 2 (+ (* (car n) a b)
		 (* (cadr n) a)
		 (* (caddr n) b)
		 (cadddr n))))

;;(cffun '(0 1 1 0) '(0 0 0 1) '(1 2) '(1 1 1 2)) gets error
;;should give (3 10)

(defun cf-convergents-p-q (cf &optional (n (length cf)) &aux pp qq)
  "returns two lists such that pp_i/qq_i is the quotient of the first i terms
   of cf"
  (case (length cf)
    (0 1)
    (1  cf(list 1))
    (t
     (setq pp (list (1+ (* (first cf) (second cf))) (car cf)))
     (setq qq (list (second cf) 1))
     (show pp qq)
     (setq cf (cddr cf))
     (loop for i from 2 to n
	    while cf
	    do 
	    (push (+  (* (car cf) (car pp))
		      (second pp)) pp)
	    (push (+  (* (car cf) (car qq))
		      (second qq)) qq)
	    (setq cf (cdr cf))
	    finally (return (list (reverse pp) (reverse qq)))))))


(defun find-cf1 (p q so-far)
  (multiple-value-bind (quot rem) (truncate p q)
    (cond ((< rem 0) (incf rem q) (incf quot -1))
	  ((zerop rem) (return-from find-cf1 (cons quot so-far))))
    (setq so-far (cons quot so-far))
    (find-cf1 q rem so-far)))
 
(defun find-cf (p q)
  "returns the continued fraction for p and q integers, q not zero"
  (cond  ((zerop q) (maxima-error "find-cf: quotient by zero"))
	 ((< q 0) (setq p (- p)) (setq q (- q))))
  (nreverse (find-cf1 p q ()))) 

(defun cf-back-recurrence (cf &aux tem (num-gg 0)(den-gg 1))
  "converts CF (a continued fraction list) to a list of numerator
  denominator using  recurrence from end
  and not calculating intermediate quotients.
  The numerator and denom are relatively
   prime"
  (loop for v in (reverse cf)
	 do (setq tem (* den-gg v))
	 (setq tem (+ tem num-gg))
	 (setq num-gg den-gg)
	 (setq den-gg tem)
	 finally
	 (return
	   (cond ((and (<= den-gg 0) (< num-gg 0))
		  (list  (- den-gg) (- num-gg)))
		 (t(list den-gg num-gg))))))

(declare-top (unspecial w))

;;(cffun '(0 1 1 0) '(0 0 0 1) '(1 2) '(1 1 1 2)) gets error
;;should give (3 10)

(defun cffun (f g a b)
  (prog (c v w)
     (declare (special v))
     a   (and (zerop (cadddr g))
	      (zerop (caddr g))
	      (zerop (cadr g))
	      (zerop (car g))
	      (return (reverse c)))
     (and (equal (setq w (conf1 f g (car a) (1+ (car b))))
		 (setq v (conf1 f g (car a) (car b))))
	  (equal (conf1 f g (1+ (car a)) (car b)) v)
	  (equal (conf1 f g (1+ (car a)) (1+ (car b))) v)
	  (setq g (mapcar #'(lambda (a b)
			      (declare (special v))
			      (- a (* v b)))
			  f (setq f g)))
	  (setq c (cons v c))
	  (go a))
     (cond ((< (abs (- (conf1 f g (1+ (car a)) (car b)) v))
		   (abs (- w v)))
	    (cond ((setq v (cdr b))
		   (setq f (conf6 f b))
		   (setq g (conf6 g b))
		   (setq b v))
		  (t (setq f (conf7 f b)) (setq g  (conf7 g b)))))
	   (t
	    (cond ((setq v (cdr a))
		   (setq f (conf4 f a))
		   (setq g (conf4 g a))
		   (setq a v))
		  (t (setq f (conf5 f a)) (setq g  (conf5 g a))))))
     (go a)))

(defun conf4 (n a)		      ;n_0*a_0+n_2,n_1*a_0+n_3,n_0,n_1
  (list (+ (* (car n) (car a)) (caddr n))
	(+ (* (cadr n) (car a)) (cadddr n))
	(car n)
	(cadr n)))

(defun conf5 (n a)			;0,0, n_0*a_0,n_2
  (list 0 0
	(+ (* (car n) (car a)) (caddr n))
	(+ (* (cadr n) (car a)) (cadddr n))))

(defun conf6 (n b)
  (list (+ (* (car n) (car b)) (cadr n))
	(car n)
	(+ (* (caddr n) (car b)) (cadddr n))
	(caddr n)))

(defun conf7 (n b)
  (list 0 (+ (* (car n) (car b)) (cadr n))
	0 (+ (* (caddr n) (car b)) (cadddr n))))

(defun cfsqrt (n)
  (cond ((cddr n)			;A non integer
	 (merror "Can't take square roots of non-integers yet"))
	((setq n (cadr n))))
  (setq n (sqcont n))
  (cond ((= $cflength 1)
	 (cons '(mlist simp) n))
	((do ((i 2 (1+ i))
	      (a (copy-tree (cdr n))))
	     ((> i $cflength) (cons '(mlist simp) n))
	   (setq n (nconc n (copy-tree a)))))))	

(defmfun $qunit (n)
  (let ((l (sqcont n)))
    (list '(mplus) (pelso1 l 0 1) 
	  (list '(mtimes) 
		(list '(mexpt) n '((rat) 1 2))
		(pelso1 l 1 0)))))

(defun pelso1 (l a b)
  (do ((i l (cdr i))) (nil)
    (and (null (cdr i)) (return b))
    (setq b (+ a (* (car i) (setq a b))))))

(defun sqcont (n)
  (prog (q q1 q2 m m1 a0 a l)
     (setq a0 ($isqrt n) a (list a0) q2 1 m1 a0 
	   q1 (- n (* m1 m1)) l (* 2 a0))
     a	(setq a (cons (truncate (+ m1 a0) q1) a))
     (cond ((equal (car a) l)
	    (return (nreverse a))))
     (setq m (- (* (car a) q1) m1)
	   q (+ q2 (* (car a) (- m1 m)))
	   q2 q1 q1 q m1 m)
     (go a)))

(defun ratcf (x y)
  (prog (a b)
   a	(cond ((equal  y 1) (return (nreverse (cons x a))))
	      ((minusp x)
	       (setq b (+ y (rem x y))
		     a (cons (1- (truncate x y)) a)
		     x y y b))
	      ((> y x)
	       (setq a (cons 0 a))
	       (setq b x x y y b))
	      ((equal x y) (return (nreverse (cons 1 a))))
	      ((setq b (rem x y))
	       (setq a (cons (truncate x y) a) x y y b)))
   (go a)))

(defmfun $cfexpand (x)
  (cond ((null ($listp x)) x)
	((cons '($matrix) (cfexpand (cdr x))))))

(defun cfexpand (ll)
  (do ((p1 0 p2)
       (p2 1 (simplify (list '(mplus) (list '(mtimes) (car l) p2) p1)))
       (q1 1 q2)
       (q2 0 (simplify (list '(mplus) (list '(mtimes) (car l) q2) q1)))
       (l ll (cdr l)))
      ((null l) (list (list '(mlist) p2 p1) (list '(mlist) q2 q1)))))

;; Summation stuff

(defun adsum (e)
  (push (simplify e) sum))

(defun adusum (e)
  (push (simplify e) usum))

(defmfun simpsum2 (exp i lo hi)
  (prog (*plus *times $simpsum u)
     (setq *plus (list 0) *times 1)
     (when (or (and (eq hi '$inf) (eq lo '$minf))
	       (equal 0 (m+ hi lo)))
       (setq $simpsum t lo 0)
       (setq *plus (cons (m* -1 *times (maxima-substitute 0 i exp)) *plus))
       (setq exp (m+ exp (maxima-substitute (m- i) i exp))))
     (cond ((eq ($sign (setq u (m- hi lo))) '$neg)
	    (if (equal u -1)
		(return 0)
		(merror "Lower bound to sum is > upper bound")))
	   ((free exp i)
	    (return (m+l (cons (freesum exp lo hi *times) *plus))))

	   ((setq exp (sumsum exp i lo hi))
	    (setq exp (m* *times (dosum (cadr exp) (caddr exp)
					(cadddr exp) (cadr (cdddr exp)) t :evaluate-summand nil))))
	   (t (return (m+l *plus))))
     (return (m+l (cons exp *plus)))))

(defun sumsum (e *var* lo hi)
  (let (sum usum)
    (cond ((eq hi '$inf)
	   (cond (*infsumsimp (isum e))
		 ((setq usum (list e))))) 
	  ((sum e 1)))
    (cond ((eq sum nil)
	   (return-from sumsum (list '(%sum) e *var* lo hi))))
    (setq *plus
	  (nconc (mapcar 
		  #'(lambda (q) (simptimes (list '(mtimes) *times q) 1 nil))
		  sum)
		 *plus))
    (and usum (setq usum (list '(%sum) (simplus (cons '(plus) usum) 1 t) *var* lo hi)))))

(defun sum (e y)
  (cond ((null e))
	((free e *var*)
	 (adsum (m* y e (m+ hi 1 (m- lo)))))
	((poly? e *var*)
	 (adsum (m* y (fpolysum e))))
	((eq (caar e) '%binomial) (fbino e y))
	((eq (caar e) 'mplus)
	 (mapc #'(lambda (q) (sum q y)) (cdr e)))
	((and (or (mtimesp e) (mexptp e) (mplusp e))
	      (fsgeo e y)))
	(t
	 (adusum e)
	 nil)))

(defun isum-giveup (e)
  (cond ((atom e) nil)
	((eq (caar e) 'mexpt)
	 (not (or (free (cadr e) *var*)
		  (ratp (caddr e) *var*))))
	((member (caar e) '(mplus mtimes) :test #'eq)
	 (some #'identity (mapcar #'isum-giveup (cdr e))))
	(t)))

(defun isum (e)
  (cond ((isum-giveup e)
	 (setq sum nil usum (list e)))
	((eq (catch 'isumout (isum1 e)) 'divergent)
	 (merror "Sum is divergent"))))

(defun isum1 (e)
  (cond ((or (free e *var*) (atom e))
	 (unless (eq (asksign e) '$zero)
	   (throw 'isumout 'divergent)))
	((ratp e *var*)
	 (adsum (ipolysum e)))
	((eq (caar e) 'mplus)
	 (mapc #'isum1 (cdr e)))
	( (isgeo e))
	((adusum e))))

(defun ipolysum (e)
  (ipoly1 ($expand e)))

(defun ipoly1 (e)
  (cond ((smono e *var*)
	 (ipoly2 *a *n (asksign (simplify (list '(mplus) *n 1)))))
	((mplusp e)
	 (cons '(mplus) (mapcar #'ipoly1 (cdr e))))
	(t (adusum e)
	   0)))

(defun ipoly2 (a n sign)
  (cond ((member (asksign lo) '($zero $negative) :test #'eq)
	 (throw 'isumout 'divergent)))
  (and (null (equal lo 1))
       (let ((sign sign) ($simpsum t))
         (adsum `((%sum)
                  ((mtimes) ,a -1 ((mexpt) ,*var* ,n))
                  ,*var* 1 ((mplus) -1 ,lo)))))
  (cond ((eq sign '$negative)
	 (list '(mtimes) a ($zeta (meval (list '(mtimes) -1 n)))))
	((throw 'isumout 'divergent))))

(defun fsgeo (e y)
  (let ((r ($ratsimp (div* (maxima-substitute (list '(mplus) *var* 1) *var* e) e))))
    (cond ((free r *var*)
	   (adsum 
	    (list '(mtimes) y
		  (maxima-substitute 0 *var* e)
		  (list '(mplus)
			(list '(mexpt) r (list '(mplus) hi 1))
			(list '(mtimes) -1 (list '(mexpt) r lo)))
		  (list '(mexpt) (list '(mplus) r -1) -1)))))))

(defun isgeo (e)
  (let ((r ($ratsimp (div* (maxima-substitute (list '(mplus) *var* 1) *var* e) e))))
    (and (free r *var*)
	 (isgeo1 (maxima-substitute lo *var* e)
		 r (asksign (simplify (list '(mplus) (list '(mabs) r) -1)))))))

(defun isgeo1 (a r sign)
  (cond ((eq sign '$positive)
	 (throw 'isumout 'divergent))
	((eq sign '$zero)
	 (throw 'isumout 'divergent))
	((eq sign '$negative)
	 (adsum (list '(mtimes) a
		      (list '(mexpt) (list '(mplus) 1 (list '(mtimes) -1 r)) -1))))))


;; Sums of polynomials using
;;   bernpoly(x+1, n) - bernpoly(x, n) = n*x^(n-1)
;; which implies
;;   sum(k^n, k, A, B) = 1/(n+1)*(bernpoly(B+1, n+1) - bernpoly(A, n+1))
;;
;; fpoly1 returns 1/(n+1)*(bernpoly(foo+1, n+1) - bernpoly(0, n+1)) for each power
;; in the polynomial e

(defun fpolysum (e)			;returns *ans*
  (let ((a (fpoly1 (setq e ($expand ($ratdisrep ($rat e *var*))))))
	(b) ($prederror))
    (cond ((null a) 0)
	  ((member lo '(0 1))
	   (maxima-substitute hi 'foo a))
	  (t
	   (list '(mplus) (maxima-substitute hi 'foo a)
		 (list '(mtimes) -1 (maxima-substitute (list '(mplus) lo -1) 'foo a)))))))

(defun fpoly1 (e)
  (cond ((smono e *var*)
	 (fpoly2 *a *n e))
	((eq (caar e) 'mplus)
	 (cons '(mplus) (mapcar #'fpoly1 (cdr e))))
	(t (adusum e) 0)))

(defun fpoly2 (a n e)
  (cond ((null (and (integerp n) (> n -1))) (adusum e) 0)
	((equal n 0)
	 (m* (cond ((signp e lo)
		    (m1+ 'foo))
		   (t 'foo))
	     a))
	(($ratsimp
	  (m* a (list '(rat) 1 (1+ n))
	      (m- ($bernpoly (m+ 'foo 1) (1+ n))
		  ($bern (1+ n))))))))

;; fbino can do these sums:
;;  a) sum(binomial(n,k),k,0,n) -> 2^n
;;  b) sum(binomial(n-k,k,k,0,n) -> fib(n+1)
;;  c) sum(binomial(n,2k),k,0,n) -> 2^(n-1)
;;  d) sum(binomial(a+k,b),k,l,h) -> binomial(h+a+1,b+1) - binomial(l+a,b+1)
(defun fbino (e y)
  ;; e=binomial(n,d)
  (prog (n d l h)
     ;; check that n and d are linear in *var*
     (cond ((null (setq n (m2 (cadr e) (list 'n 'linear* *var*) nil)))
	    (return (adusum e))))
     (setq n (cdr (assoc 'n n :test #'eq)))
     (cond ((null (setq d (m2 (caddr e) (list 'd 'linear* *var*) nil)))
	    (return (adusum e))))
     (setq d (cdr (assoc 'd d :test #'eq)))

     ;; binomial(a+b*k,c+b*k) -> binomial(a+b*k, a-c)
     (when (equal (cdr n) (cdr d))
       (setq d (cons (m- (car n) (car d)) 0)))
     
     (cond
       ;; substitute k with -k in sum(binomial(a+b*k, c-d*k))
       ;; and sum(binomial(a-b*k,c))
       ((and (numberp (cdr d))
	     (or (minusp (cdr d))
		 (and (zerop (cdr d))
		      (numberp (cdr n))
		      (minusp (cdr n)))))
	(rplacd d (- (cdr d)))
	(rplacd n (- (cdr n)))
	(setq l (m- hi)
	      h (m- lo)))
       (t (setq l lo  h hi)))

     (cond

       ;; sum(binomial(a+k,c),k,l,h)
       ((and (equal 0 (cdr d)) (equal 1 (cdr n)))
	(adsum (m* y (m- (list '(%binomial) (m+ h (car n) 1) (m+ (car d) 1))
			 (list '(%binomial) (m+ l (car n) 1) (m+ (car d) 1))))))

       ;; sum(binomial(n,k),k,0,n)=2^n
       ((and (equal 1 (cdr d)) (equal 0 (cdr n)))
	;; sum(binomial(n,k+c),k,l,h)=sum(binomial(n,k+c+l),k,0,h-l)
	(let ((h1 (m- h l))
	      (c (m+ (car d) l)))
	  (if (and (integerp (m- (car n) h1))
		   (integerp c))
	      (progn
		(adsum (m* y (m^ 2 (car n))))
		(when (member (asksign (m- h1 (car n))) '($zero $negative) :test #'eq)
		  (adsum (m* -1 y (dosum (list '(%binomial) (car n) *var*)
					 *var* (m+ h1 1) (car n) t :evaluate-summand nil))))
		(when (> c 0)
		  (adsum (m* -1 y (dosum (list '(%binomial) (car n) *var*)
					 *var* 0 (m- c 1) t :evaluate-summand nil)))))
	      (adusum e))))

       ;; sum(binomial(b-k,k),k,0,floor(b/2))=fib(b+1)
       ((and (equal -1 (cdr n)) (equal 1 (cdr d)))
	;; sum(binomial(a-k,b+k),k,l,h)=sum(binomial(a+b-k,k),k,l+b,h+b)
	(let ((h1 (m+ h (car d)))
	      (l1 (m+ l (car d)))
	      (a1 (m+ (car n) (car d))))
	  ;; sum(binomial(a1-k,k),k,0,floor(a1/2))=fib(a1+1)
	  ;; we only do sums with h>floor(a1/2)
	  (if (and (integerp l1)
		   (member (asksign (m- h1 (m// a1 2))) '($zero $positive) :test #'eq))
	      (progn
		(adsum (m* y ($fib (m+ a1 1))))
		(when (> l1 0)
		  (adsum (m* -1 y (dosum (list '(%binomial) (m- a1 *var*) *var*)
					 *var* 0 (m- l1 1) t :evaluate-summand nil)))))
	      (adusum e))))

       ;; sum(binomial(n,2*k),k,0,floor(n/2))=2^(n-1)
       ;; sum(binomial(n,2*k+1),k,0,floor((n-1)/2))=2^(n-1)
       ((and (equal 0 (cdr n)) (equal 2 (cdr d)))
	;; sum(binomial(a,2*k+b),k,l,h)=sum(binomial(a,2*k),k,l+b/2,h+b/2), b even
	;; sum(binomial(a,2*k+b),k,l,h)=sum(binomial(a,2*k+1),k,l+(b-1)/2,h+(b-1)/2), b odd
	(let ((a (car n))
	      (r1 (if (oddp (car d)) 1 0))
	      (l1 (if (oddp (car d))
		      (m+ l (truncate (1- (car d)) 2))
		      (m+ l (truncate (car d) 2))))
	      (h1 (if (oddp (car d))
		      (m+ h (truncate (1- (car d)) 2))
		      (m+ h (truncate (car d) 2)))))
	  (if (and (integerp l1)
		   (member (asksign (m- a hi)) '($zero $positive) :test #'eq))
	      (progn
		(adsum (m* y (m^ 2 (m- a 1))))
		(when (> l1 0)
		  (adsum (m* -1 y (dosum (list '(%binomial) a (m+ *var* *var* r1))
					 *var* 0 (m- l1 1) t :evaluate-summand nil))))))))

       ;; other sums we can't do
       (t
	(adusum e)))))

;; product routines

(defmspec $product (l)
  (setq l (cdr l))
  (cond ((not (= (length l) 4)) (merror "Wrong no. of args to product"))
	((dosum (car l) (cadr l) (meval (caddr l)) (meval (cadddr l)) nil :evaluate-summand t))))

(declare-top (special $ratsimpexpons))

;; Is this guy actually looking at the value of its middle arg?

(defun simpprod (x y z)
  (let (($ratsimpexpons t))
    (cond ((equal y 1)
	   (setq y (simplifya (cadr x) z)))
	  ((setq y (simptimes (list '(mexpt) (cadr x) y) 1 z)))))
  (simpprod1 y (caddr x)
	     (simplifya (cadddr x) z)
	     (simplifya (cadr (cdddr x)) z)))

(defmfun $taytorat (e)
  (cond ((mbagp e) (cons (car e) (mapcar #'$taytorat (cdr e))))
	((or (atom e) (not (member 'trunc (cdar e) :test #'eq))) (ratf e))
	((catch 'srrat (srrat e))) 
	(t (ratf ($ratdisrep e)))))

(defun srrat (e)
  (cons (list 'mrat 'simp (caddar e) (cadddr (car e)))
	(srrat2 (cdr e))))

(defun srrat2 (e)
  (if (pscoefp e) e (srrat3 (terms e) (gvar e))))

(defun srrat3 (l *var*)
  (cond ((null l) '(0 . 1))
	((null (=1 (cdr (le l))))
	 (throw 'srrat nil))
	((null (n-term l))
	 (rattimes (cons (list *var* (car (le l)) 1) 1)
		   (srrat2 (lc l))
		   t))
	((ratplus
	  (rattimes (cons (list *var* (car (le l)) 1) 1)
		    (srrat2 (lc l))
		    t)
	  (srrat3 (n-term l) *var*)))))


(declare-top (special $props *i))

(defmspec $deftaylor (l)
  (prog (fun series param op ops)
   a	(when (null (setq l (cdr l))) (return (cons '(mlist) ops)))
   (setq fun (meval (car l)) series (meval (cadr l)) l (cdr l) param () )
   (when (or (atom fun) 
	     (if (eq (caar fun) 'mqapply)
		 (or (cdddr fun)	; must be one parameter
		     (null (cddr fun))	; must have exactly one
		     (do ((subs (cdadr fun) (cdr subs)))
			 ((null subs)
			  (setq op (caaadr fun))
			  (when (cddr fun)
			    (setq param (caddr fun)))
			  '())
		       (unless (atom (car subs)) (return 't))))
		 (progn
		   (setq op (caar fun))
		   (when (cdr fun) (setq param (cadr fun)))
		   (or (and (oldget op 'op) (not (eq op 'mfactorial)))
		       (not (atom (cadr fun)))
		       (not (= (length fun) 2))))))
     (merror "Bad argument to `deftaylor':~%~M" fun))
   (when (oldget op 'sp2)
     (mtell "~:M being redefined in `deftaylor'.~%" op))
   (when param (setq series (subst 'sp2var param series)))
   (setq series (subsum '*index series))
   (putprop op series 'sp2)
   (when (eq (caar fun) 'mqapply)
     (putprop op (cdadr fun) 'sp2subs))
   (add2lnc op $props)
   (push op ops)
   (go a)))

(defun subsum (*i e) (susum1 e))

(defun susum1 (e)
  (cond ((atom e) e)
	((eq (caar e) '%sum)
	 (if (null (smonop (cadr e) 'sp2var))
	     (merror "Argument to `deftaylor' must be power series at 0.")
	     (subst *i (caddr e) e)))
	(t (recur-apply #'susum1 e))))

(declare-top (special varlist genvar $factorflag $ratfac *p* *var* *l* *x*))

(defmfun $polydecomp (e v)
  (let ((varlist (list v))
	(genvar nil)
	*var* p den $factorflag $ratfac)
    (setq p (cdr (ratf (ratdisrep e)))
	  *var* (cdr (ratf v)))
    (cond ((or (null (cdr *var*))
	       (null (equal (cdar *var*) '(1 1))))
	   (merror "Second arg to `polydecomp' must be an atom"))
	  (t (setq *var* (caar *var*))))
    (cond ((or (pcoefp (cdr p))
	       (null (eq (cadr p) *var*)))
	   (setq den (cdr p)
		 p (car p)))
	  (t (merror "Cannot `polydecomp' a rational function")))
    (cons '(mlist)
	  (cond ((or (pcoefp p)
		     (null (eq (car p) *var*)))
		 (list (rdis (cons p den))))
		(t (setq p (pdecomp p *var*))
		   (do ((l
			 (setq p (mapcar #'(lambda (q) (cons q 1)) p))
			 (cdr l))
			(a))
		       ((null l)
			(cons (rdis (cons (caar p)
					  (ptimes (cdar p) den)))
			      (mapcar #'rdis (cdr p))))
		     (cond ((setq a (pdecpow (car l) *var*))
			    (rplaca l (car a))
			    (cond ((cdr l)
				   (rplacd l
					   (cons (ratplus
						  (rattimes
						   (cadr l)
						   (cons (pterm (cdaadr a) 1)
							 (cdadr a))
						   t)
						  (cons
						   (pterm (cdaadr a) 0)
						   (cdadr a)))
						 (cddr l))))
				  ((equal (cadr a)
					  (cons (list *var* 1 1) 1)))
				  (t (rplacd l (list (cadr a)))))))))))))


;;; POLYDECOMP is like $POLYDECOMP except it takes a poly in *POLY* format (as
;;; defined in SOLVE) (numerator of a RAT form) and returns a list of
;;; headerless rat forms.  In otherwords, it is $POLYDECOMP minus type checking
;;; and conversions to/from general representation which SOLVE doesn't
;;; want/need on a general basis.
;;; It is used in the SOLVE package and as such it should have an autoload
;;; property 

(defun polydecomp (p *var*)
  (let ($factorflag $ratfac)
    (cond ((or (pcoefp p)
	       (null (eq (car p) *var*)))
	   (cons p nil))
	  (t (setq p (pdecomp p *var*))
	     (do ((l (setq p (mapcar #'(lambda (q) (cons q 1)) p))
		     (cdr l))
		  (a))
		 ((null l)
		  (cons (cons (caar p)
			      (cdar p))
			(cdr p)))
	       (cond ((setq a (pdecpow (car l) *var*))
		      (rplaca l (car a))
		      (cond ((cdr l)
			     (rplacd l
				     (cons (ratplus
					    (rattimes
					     (cadr l)
					     (cons (pterm (cdaadr a) 1)
						   (cdadr a))
					     t)
					    (cons
					     (pterm (cdaadr a) 0)
					     (cdadr a)))
					   (cddr l))))
			    ((equal (cadr a)
				    (cons (list *var* 1 1) 1)))
			    (t (rplacd l (list (cadr a))))))))))))



(defun pdecred (f h *var*)		;f = g(h(*var*))
  (cond ((or (pcoefp h) (null (eq (car h) *var*))
	     (equal (cadr h) 1)
	     (null (zerop (rem (cadr f) (cadr h))))
	     (and (null (pzerop (caadr (setq f (pdivide f h)))))
		  (equal (cdadr f) 1)))
	 nil)
	(t (do ((q (pdivide (caar f) h) (pdivide (caar q) h))
		(i 1 (1+ i))
		(*ans*))
	       ((pzerop (caar q))
		(cond ((and (equal (cdadr q) 1)
			    (or (pcoefp (caadr q))
				(null (eq (caar (cadr q)) *var*))))
		       (psimp *var* (cons i (cons (caadr q) *ans*))))))
	     (cond ((and (equal (cdadr q) 1)
			 (or (pcoefp (caadr q))
			     (null (eq (caar (cadr q)) *var*))))
		    (and (null (pzerop (caadr q)))
			 (setq *ans* (cons i (cons (caadr q) *ans*)))))
		   (t (return nil)))))))

(defun pdecomp (p *var*)
  (let ((c (pterm (cdr p) 0))
	(a) (*x* (list *var* 1 1)))
    (cons (pcplus c (car (setq a (pdecomp* (pdifference p c)))))
	  (cdr a))))

(defun pdecomp* (*p*)
  (let ((a)
	(l (pdecgdfrm (pfactor (pquotient *p* *x*)))))
    (cond ((or (pdecprimep (cadr *p*))
	       (null (setq a (pdecomp1 *x* l))))
	   (list *p*))
	  (t (append (pdecomp* (car a)) (cdr a))))))

(defun pdecomp1 (prod l)
  (cond ((null l)
	 (and (null (equal (cadr prod) (cadr *p*)))
	      (setq l (pdecred *p* prod *var*))
	      (list l prod)))
	((pdecomp1 prod (cdr l)))
	(t (pdecomp1 (ptimes (car l) prod) (cdr l)))))

(defun pdecgdfrm (l)			;Get list of divisors
  (do ((l (copy-list l ))
       (ll (list (car l))
	   (cons (car l) ll)))
      (nil)
    (rplaca (cdr l) (1- (cadr l)))
    (cond ((signp e (cadr l))
	   (setq l (cddr l))))
    (cond ((null l) (return ll)))))

(defun pdecprimep (x)
  (setq x (cfactorw x))
  (and (null (cddr x)) (equal (cadr x) 1))) 
       
(defun pdecpow (p *var*)
  (setq p (car p))
  (let ((p1 (pderivative p *var*))
	p2 p1p p1c a lin p2p)
    (setq p1p (oldcontent p1)
	  p1c (car p1p) p1p (cadr p1p))
    (setq p2 (pderivative p1 *var*))
    (setq p2p (cadr (oldcontent p2)))
    (and (setq lin (testdivide p1p p2p))
	 (null (pcoefp lin))
	 (eq (car lin) *var*)
	 (list (ratplus
		(rattimes (cons (list *var* (cadr p) 1) 1)
			  (setq a (ratreduce p1c
					     (ptimes (cadr p)
						     (caddr lin))))
			  t)
		(ratdif (cons p 1)
			(rattimes a (cons (pexpt lin (cadr p)) 1)
				  t)))
	       (cons lin 1)))))

(declare-top (unspecial *mfactl *factlist donel nn* dn* ans var
			dict *var* *ans* a* *a *n *a*  hi lo
			*infsumsimp *times *plus sum usum makef gensim))
