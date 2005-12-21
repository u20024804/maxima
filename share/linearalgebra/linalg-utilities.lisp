;;  Copyright 2005 by Barton Willis

;;  This is free software; you can redistribute it and/or
;;  modify it under the terms of the GNU General Public License,
;;  http://www.gnu.org/copyleft/gpl.html.

;; This software has NO WARRANTY, not even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

($put '$linalgutilities 1.1 '$version)

(defmacro while (cond &rest body)
  `(do ()
       ((not ,cond))
     ,@body))

;; Return true iff e is an expression with operator op1, op2,...,or opn. 

(defun op-equalp (e &rest op)
  (and (consp e) (consp (car e)) (some #'(lambda (s) (equal (caar e) s)) op)))

;; Return true iff the operator of e is a Maxima relation operator.

(defun mrelationp (a)
  (op-equalp a 'mlessp 'mleqp 'mequal 'mgeqp 'mgreaterp))

(defun $listp (e &optional (f nil))
  (and (op-equalp e 'mlist) (or (eq f nil) (every #'(lambda (s) (eq t (mfuncall f s))) (margs e)))))

(defun $matrixp (e  &optional (f nil))
  (and (op-equalp e '$matrix) (every #'(lambda (s) ($listp s f)) (margs e))))

(defun $require_nonempty_matrix (m pos fun)
  (if (not (and ($matrixp m) (> ($length m) 0) (> ($length ($first m)) 0)))
      (merror "The ~:M argument of the function ~:M must be a nonempty matrix" pos fun)))

(defun $require_matrix (m pos fun)
  (if (not ($matrixp m))
      (merror "The ~:M argument of the function ~:M must be a matrix" pos fun)))

(defun $require_square_matrix (m pos fun)
  (if (not (and ($matrixp m) (= ($length m) ($length ($first m)))))
      (merror "The ~:M argument of the function ~:M must be a square matrix" pos fun)))

(defun $matrix_size(m)
  ($require_matrix m "$first" "$matrix_size")
  `((mlist) ,($length m) ,($length ($first m))))
  
(defun $require_list (lst pos fun)
  (if (not ($listp lst))
      (merror "The ~:M argument of the function ~:M must be a list" pos fun)))

(defun $require_posinteger(i pos fun)
  (if (not (and (integerp i) (> i 0)))
      (merror "The ~:M argument of the function ~:M must be a positive integer" pos fun)))

(defun $ctranspose (m)
  (let (($matrix_element_transpose 
	 `((lambda simp) ((mlist) x)
	   ((mcond) (($matrixp) x) (($ctranspose) x) t
	    (($conjugate) x)))))
    (mfuncall '$transpose m)))

(eval-when (eval compile load)
  (mfuncall '$alias '$copylist '$copy '$copymatrix '$copy))

(defun $copy (e) (copy-tree e))