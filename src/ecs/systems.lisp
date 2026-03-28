;; systems.lisp

(in-package :cl-aliengine)

(defmacro query ((&key with without) &body body)
  (let* ((with-list   (or with '()))
         (without-list (or without '()))
         (expanded-body
           (mapcar (lambda (form) (%expand-dots form with-list)) body)))
    `(dolist (entity *entities*)
       (when (and ,@(mapcar (lambda (c) `(entity-has entity ',c)) with-list)
                  ,@(mapcar (lambda (c) `(entity-lacks entity ',c)) without-list))
         (let ((entity-id (car entity))
               ,@(mapcar (lambda (c) `(,c (get-component entity ',c))) with-list))
           ,@expanded-body)))))

(defmacro defsystem (name &rest args)
  "Define a system named NAME that runs its body for every matching entity.

  Syntax:
    (defsystem my-system :with (comp-a comp-b) :without (comp-c)
      body-form...)

  :WITH    — list of required component names.  Each becomes a local variable
             bound to the component plist.  Dot-notation (e.g. comp-a.field)
             expands to (getf comp-a :field) inside the body.
  :WITHOUT — list of component names that must be absent.  Useful for tags
             like (dead) to exclude entities from a system.
  ENTITY-ID is also bound implicitly inside the body."
  (let ((remaining args)
        (with nil)
        (without nil))
    (loop while (and remaining (keywordp (car remaining)))
          do (let ((k (pop remaining))
                   (v (pop remaining)))
               (case k
                 (:with    (setf with v))
                 (:without (setf without v)))))
    (let* ((body remaining)
           (expanded-body (mapcar (lambda (form) (%expand-dots form with)) body)))
      `(push (list :name    ',name
                   :with    ',with
                   :without ',without
                   :fn      (lambda (entity)
                              (let ((entity-id (car entity))
                                    ,@(mapcar (lambda (c) `(,c (get-component entity ',c))) with))
                                ,@expanded-body)))
             *systems*))))

(defun run-system (system)
  "Execute SYSTEM against every entity that satisfies its :with/:without filters."
  (destructuring-bind (&key with without fn &allow-other-keys) system
    (dolist (e *entities*)
      (when (and (every (lambda (c) (entity-has  e c)) with)
                 (every (lambda (c) (entity-lacks e c)) without))
        (funcall fn e)))))

(defun find-system (name)
  "Return the system plist for NAME, or NIL if not found."
  (find name *systems* :key (lambda (s) (getf s :name))))

(defmacro syscall (name)
  "Run the system named NAME against all matching entities.
  Expands to (run-system (find-system 'name)).
  Use this inside DEFSCENE :on-going bodies to drive your game logic."
  `(run-system (find-system ',name)))

