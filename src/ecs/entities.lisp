;; src/ecs/entities.lisp

(in-package :cl-aliengine)

(defun make-entity-id ()
  "Return a unique integer ID for a new entity."
  (incf *next-entity-id*))

(defmacro spawn (&rest components)
  "Create a new entity, attach the given COMPONENTS, register it, and return it.
  Each element of COMPONENTS is a list of the form (component-name field-value ...).
  Example:
    (spawn (transform :x 0 :y 0)
           (sprite :texture tex :src-x 0 :src-y 0 :src-w 16 :src-h 16 :scale 2 :flip-x nil))"
  (let ((entity-sym (gensym "ENTITY")))
    `(let ((,entity-sym (cons (make-entity-id) '())))
       ,@(mapcar (lambda (comp)
                   (destructuring-bind (name &rest args) comp
                     `(add-component ,entity-sym ',name (list ,@args))))
                 components)
       (push ,entity-sym *entities*)
       ,entity-sym)))

(defun kill-entity (entity)
  "Remove ENTITY from *ENTITIES*, effectively destroying it.
  Safe to call from inside a system body; the entity is removed after the
  current frame's iteration completes because DOLIST takes a snapshot of the
  list head at the start.  Do not rely on any component data after calling this."
  (setf *entities* (remove entity *entities* :test #'eq)))

(defun kill-all-entities ()
  "Remove every entity from *ENTITIES*.
  Useful in scene :on-exit hooks to reset world state between scenes."
  (setf *entities* '()))

(defun entity-has (entity comp)
  "Return the component cons cell for COMP on ENTITY, or NIL if absent."
  (assoc comp (cdr entity)))

(defun entity-lacks (entity comp)
  "Return T if ENTITY does not have component COMP."
  (not (entity-has entity comp)))

