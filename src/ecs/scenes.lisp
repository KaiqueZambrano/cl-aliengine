;; src/ecs/scenes.lisp

(in-package :cl-aliengine)

(defun %parse-scene-body (body)
  "Partition the flat BODY list into four sublists by :on-init/:on-enter/
  :on-going/:on-exit keyword markers.
  Returns a list of four sublists: (init enter going exit)."
  (let ((on-init '()) (on-enter '()) (on-going '()) (on-exit '()) (current nil))
    (dolist (item body)
      (cond
        ((eq item :on-init)  (setf current :init))
        ((eq item :on-enter) (setf current :enter))
        ((eq item :on-going) (setf current :going))
        ((eq item :on-exit)  (setf current :exit))
        (t (case current
             (:init  (push item on-init))
             (:enter (push item on-enter))
             (:going (push item on-going))
             (:exit  (push item on-exit))))))
    (list (nreverse on-init)
          (nreverse on-enter)
          (nreverse on-going)
          (nreverse on-exit))))

(defmacro defscene (name &rest body)
  "Declare a scene named NAME with optional lifecycle hooks.

  Syntax:
    (defscene my-scene
      :on-init  forms-run-once-on-first-enter...
      :on-enter forms-run-each-time-scene-is-entered...
      :on-going forms-run-every-frame...
      :on-exit  forms-run-when-leaving-the-scene...)

  All four hooks are optional.  :on-init runs only the first time the scene
  is entered; :on-enter runs on every subsequent entry.  Call SWITCH-SCENE
  to transition between scenes at runtime."
  (destructuring-bind (on-init on-enter on-going on-exit) (%parse-scene-body body)
    `(push (list :name        ',name
                 :initialized nil
                 :on-init     (lambda () ,@on-init)
                 :on-enter    (lambda () ,@on-enter)
                 :on-going    (lambda () ,@on-going)
                 :on-exit     (lambda () ,@on-exit))
           *scenes*)))

(defun find-scene (name)
  "Return the scene plist for NAME, or NIL if not found."
  (find name *scenes* :key (lambda (s) (getf s :name))))

(defun switch-scene (name)
  "Transition to the scene named NAME.
  Calls :on-exit on the current scene (if any), then :on-init (first visit)
  or :on-enter (subsequent visits) on the new scene."
  (when *current-scene*
    (funcall (getf *current-scene* :on-exit)))
  (let ((new-scene (find-scene name)))
    (if (getf new-scene :initialized)
        (funcall (getf new-scene :on-enter))
        (progn
          (funcall (getf new-scene :on-init))
          (setf (getf new-scene :initialized) t)))
    (setf *current-scene* new-scene)))

(defun update ()
  "Invoke the :on-going hook of *CURRENT-SCENE*.  Called once per frame by RUN."
  (when *current-scene*
    (funcall (getf *current-scene* :on-going))))

