;; components.lisp

(in-package :cl-aliengine)

(defmacro defcomponent (name fields)
  "Declare a component named NAME with the given FIELDS list.
  Components are stored as plists on each entity; field names become keywords.
  Example:
    (defcomponent transform (x y))
    ;; fields accessed as transform.x and transform.y inside DEFSYSTEM bodies."
  `(push (cons ',name ',fields) *components*))

(defun get-component (entity name)
  "Return the component plist for NAME on ENTITY, or NIL if absent."
  (cdr (assoc name (cdr entity))))

(defun add-component (entity comp-name data)
  "Attach component COMP-NAME with plist DATA to ENTITY.
  DATA should be a list of alternating keyword/value pairs matching the
  field declaration from DEFCOMPONENT."
  (push (cons comp-name data) (cdr entity)))
