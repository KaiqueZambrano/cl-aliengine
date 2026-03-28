;; globals.lisp

(in-package :cl-aliengine)

(defparameter *entities*       '() "List of all live entities.  Each entity is (id . components).")
(defparameter *components*     '() "Registry of declared components as (name . fields) pairs.")
(defparameter *systems*        '() "List of system plists registered via DEFSYSTEM.")
(defparameter *scenes*         '() "List of scene plists registered via DEFSCENE.")
(defparameter *next-entity-id* 0   "Monotonically increasing counter used by MAKE-ENTITY-ID.")
(defparameter *current-scene*  nil "The scene plist currently being executed, or NIL.")
