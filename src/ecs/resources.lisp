;; src/ecs/resources.lisp

(in-package :cl-aliengine)

;;; Resources are engine-managed global values stored as mutable cons boxes
;;; in *RESOURCES*.  Unlike plain DEFPARAMETER bindings they integrate with
;;; DEFSYSTEM and QUERY via the :RESOURCE keyword, which makes them available
;;; as setf-able local names (and supports dot-notation when the value is a
;;; plist).
;;;
;;; Storage layout:
;;;   *resources* = ((name . box) ...)
;;;   box         = (value . nil)          ← a mutable cons cell
;;;
;;; This means every resource access inside a system body goes through
;;; (car (get-resource-box 'name)), which is a valid SETF place.

(defmacro defresource (name value)
  "Declare (or re-declare) a resource named NAME with initial VALUE.

  Resources are stored in *RESOURCES* and can be read/written inside any
  DEFSYSTEM or QUERY body that lists NAME under :RESOURCE.  They are also
  accessible anywhere via GET-RESOURCE and SET-RESOURCE.

  When VALUE is a plist, dot-notation (e.g. name.field) is available inside
  system/query bodies that include NAME in their :RESOURCE list.

  Re-evaluating DEFRESOURCE with the same NAME updates the value in-place
  (the existing box is reused, so live references remain valid).

  Examples:
    (defresource player-speed 600.0d0)
    (defresource hud-config   (list :visible t :alpha 1.0))"
  `(let ((existing (assoc ',name *resources*)))
     (if existing
         ;; Re-initialise: update the existing box in-place so that any
         ;; live symbol-macrolet expansions pointing to it stay valid.
         (setf (car (cdr existing)) ,value)
         (push (cons ',name (cons ,value nil)) *resources*))
     ',name))

(defun get-resource-box (name)
  "Return the mutable cons box for resource NAME, or NIL if not registered.
  The box is a cons (value . nil); its CAR is the live resource value."
  (cdr (assoc name *resources*)))

(defun get-resource (name)
  "Return the current value of resource NAME."
  (let ((box (get-resource-box name)))
    (if box
        (car box)
        (error "Resource ~a not found." name))))

(defun set-resource (name value)
  "Set resource NAME to VALUE.
  Equivalent to (setf (car (get-resource-box name)) value)."
  (let ((box (get-resource-box name)))
    (if box
        (setf (car box) value)
        (error "Resource ~a not found." name))))
