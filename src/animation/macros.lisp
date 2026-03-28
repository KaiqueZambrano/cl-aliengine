;; macros.lisp

(in-package :cl-aliengine)

(defmacro make-animations (&rest specs)
  "Build an animation alist suitable for the ANIMATOR component's :animations field.

  Each SPEC has the form (name &rest plist-args), where NAME becomes a keyword
  and PLIST-ARGS are passed through verbatim.  Common plist keys:
    :texture    — GPU-TEXTURE to switch to when this animation starts (optional).
    :frames     — list of frame indices into the sprite sheet row.
    :frame-time — duration in seconds per frame.
    :loop       — T for looping, NIL for one-shot.

  Example:
    (make-animations
      (idle :texture tex-idle :frames '(0 1 2 3) :frame-time 0.12 :loop t)
      (run  :texture tex-run  :frames '(0 1 2 3 4 5) :frame-time 0.08 :loop t))"
  `(list ,@(mapcar (lambda (spec)
                     (destructuring-bind (name &rest args) spec
                       `(list ,(intern (string name) :keyword) ,@args)))
                   specs)))
