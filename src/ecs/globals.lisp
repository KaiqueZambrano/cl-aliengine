;; src/ecs/globals.lisp

(in-package :cl-aliengine)

(defparameter *entities*       '() "List of all live entities.  Each entity is (id . components).")
(defparameter *components*     '() "Registry of declared components as (name . fields) pairs.")
(defparameter *systems*        '() "List of system plists registered via DEFSYSTEM.")
(defparameter *scenes*         '() "List of scene plists registered via DEFSCENE.")
(defparameter *resources*      '() "Alist of (name . box) pairs managed by DEFRESOURCE.
  Each box is a mutable cons (value . nil) so resources are setf-able places.")
(defparameter *next-entity-id* 0   "Monotonically increasing counter used by MAKE-ENTITY-ID.")
(defparameter *current-scene*  nil "The scene plist currently being executed, or NIL.")
