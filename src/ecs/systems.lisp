;; systems.lisp

(in-package :cl-aliengine)

;;; Helper: build the SYMBOL-MACROLET bindings for a list of resource names.
;;; Each resource name R expands to (car (get-resource-box 'R)), which is a
;;; valid SETF place — so (setf r new-val) works transparently.
(defun %resource-bindings (resource-list)
  (mapcar (lambda (r)
            `(,r (car (get-resource-box ',r))))
          resource-list))

(defmacro query ((&key with without resource) &body body)
  "Iterate over every entity that has all WITH components and none of the
  WITHOUT components, binding each component plist as a local variable.

  :WITH     — required component names; each becomes a local variable.
  :WITHOUT  — component names that must be absent.
  :RESOURCE — resource names to expose as setf-able local bindings.
              Dot-notation (e.g. res.field) is supported when the resource
              value is a plist.

  ENTITY-ID is bound to the current entity's id inside the body.

  Example:
    (query (:with (transform velocity) :resource (player-speed))
      (setf velocity.vx player-speed))"
  (let* ((with-list     (or with     '()))
         (without-list  (or without  '()))
         (resource-list (or resource '()))
         ;; Dot-notation is valid for both component and resource names.
         (all-names     (append with-list resource-list))
         (expanded-body (mapcar (lambda (form) (%expand-dots form all-names)) body))
         (res-bindings  (%resource-bindings resource-list)))
    `(symbol-macrolet ,res-bindings
       (dolist (entity *entities*)
         (when (and ,@(mapcar (lambda (c) `(entity-has  entity ',c)) with-list)
                    ,@(mapcar (lambda (c) `(entity-lacks entity ',c)) without-list))
           (let ((entity-id (car entity))
                 ,@(mapcar (lambda (c) `(,c (get-component entity ',c))) with-list))
             ,@expanded-body))))))

(defmacro defsystem (name &rest args)
  "Define and register a system named NAME.

  Syntax:
    (defsystem my-system
      :with     (comp-a comp-b)   ; required components
      :without  (comp-c)          ; components that must be absent
      :resource (res-a res-b)     ; global resources to expose
      :stage    (:update)         ; stage(s) this system belongs to
      :priority 0                 ; execution order within a stage (default 0)
      body-form...)

  :WITH     — component names whose plists are bound as local variables.
              Dot-notation (comp-a.field) expands to (getf comp-a :field).
  :WITHOUT  — exclusion tags.
  :RESOURCE — resource names exposed as setf-able locals; dot-notation works
              when the resource value is a plist.
  :STAGE    — list of stage keywords (e.g. (:update) or (:update :render)).
              RUN-STAGE will execute this system when called with a matching
              stage keyword.
  :PRIORITY — integer controlling execution order within a stage.  Lower
              numbers run first.  Defaults to 0.  Systems with equal priority
              run in definition order.  Typical convention:
                negative  — pre-pass  (e.g. clear buffers)
                0         — default
                positive  — post-pass (e.g. overlays, UI, debug draw)
              Example: render-tilemaps at priority 0, render-sprites at 10
              ensures the tilemap is always drawn beneath sprites.

  If :WITH is empty the system is treated as *global*: its body runs exactly
  once per frame (not once per entity) when RUN-STAGE or SYSCALL is called.
  ENTITY-ID is bound to NIL in that case.

  ENTITY-ID is bound implicitly inside all system bodies."
  (let ((remaining args)
        (with     nil)
        (without  nil)
        (resource nil)
        (stage    nil)
        (priority 0))
    (loop while (and remaining (keywordp (car remaining)))
          do (let ((k (pop remaining))
                   (v (pop remaining)))
               (case k
                 (:with     (setf with     v))
                 (:without  (setf without  v))
                 (:resource (setf resource v))
                 (:stage    (setf stage    v))
                 (:priority (setf priority v)))))
    (let* ((body          remaining)
           ;; Dot-notation applies to both component and resource names.
           (all-names     (append with resource))
           (expanded-body (mapcar (lambda (form) (%expand-dots form all-names)) body))
           (res-bindings  (%resource-bindings resource)))
      `(push (list :name     ',name
                   :with     ',with
                   :without  ',without
                   :resource ',resource
                   :stage    ',stage
                   :priority ,priority
                   :fn       (lambda (entity)
                               (symbol-macrolet ,res-bindings
                                 (let ((entity-id (car entity))
                                       ,@(mapcar (lambda (c)
                                                   `(,c (get-component entity ',c)))
                                                 with))
                                   ,@expanded-body))))
             *systems*))))

(defun run-system (system)
  "Execute SYSTEM.
  If the system has no :WITH components it is treated as *global* and its
  body runs exactly once (with ENTITY = NIL).  Otherwise the body runs once
  per entity that satisfies the :WITH / :WITHOUT filters."
  (destructuring-bind (&key with without fn &allow-other-keys) system
    (if (null with)
        ;; Global system — no entity iteration, just run once.
        (funcall fn nil)
        (dolist (e *entities*)
          (when (and (every (lambda (c) (entity-has  e c)) with)
                     (every (lambda (c) (entity-lacks e c)) without))
            (funcall fn e))))))

(defun find-system (name)
  "Return the system plist for NAME, or NIL if not found."
  (find name *systems* :key (lambda (s) (getf s :name))))

(defmacro syscall (name)
  "Run the system named NAME.
  Expands to (run-system (find-system 'name)).
  Kept for explicit single-system dispatch; prefer RUN-STAGE for batch execution."
  `(run-system (find-system ',name)))

(defun run-stage (stage)
  "Run every system whose :STAGE list contains STAGE, sorted by :PRIORITY.

  Systems with lower :PRIORITY values execute first.  Systems that share the
  same priority run in definition order (stable sort).  The default priority
  is 0, so most systems need no explicit annotation.

  Suggested priority bands:
    < 0   pre-pass   (clear buffers, begin-frame hooks)
      0   default    (the vast majority of systems)
    > 0   post-pass  (UI, debug overlays, end-frame hooks)

  Render ordering example:
    (defsystem render-tilemaps :stage (:render) :priority  0 ...)
    (defsystem render-sprites  :stage (:render) :priority 10 ...)
    ;; tilemaps are always drawn before sprites regardless of load order.

  Example calls:
    (run-stage :update)
    (run-stage :render)"
  (let* ((candidates (remove-if-not (lambda (s) (member stage (getf s :stage)))
                                    (reverse *systems*)))
         (sorted     (stable-sort candidates #'< :key (lambda (s) (getf s :priority 0)))))
    (dolist (system sorted)
      (run-system system))))
