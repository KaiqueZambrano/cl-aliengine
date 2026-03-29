;; src/core/utilities.lisp

(in-package :cl-aliengine)

(defmacro null-ptr (&optional (type '(* t)))
  "Return a typed null alien pointer.
  TYPE defaults to (* t), a generic pointer.  Pass a more specific alien type
  when the callee requires one, e.g. (null-ptr (* (* t)))."
  `(sap-alien (int-sap 0) ,type))

(declaim (inline null-ptr-p))
(defun null-ptr-p (ptr)
  "Return T if the alien pointer PTR is null (address zero)."
  (zerop (sap-int (alien-sap ptr))))
