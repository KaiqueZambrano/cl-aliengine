;; lifecycle.lisp

(in-package :cl-aliengine)

(defun nui-init ()
  "Initialise the Nuklear GUI layer for *WINDOW*.
  Call this inside a scene's :on-init hook, or let RUN-WITH-UI handle it.
  Signals an error if the GLFW window is not yet open."
  (unless *window*
    (error "NUI-INIT called before the GLFW window was created.  ~
            Use RUN-WITH-UI, or call NUI-INIT from inside :on-init."))
  (let ((ctx (%nk-init *window*)))
    (when (null-ptr-p ctx)
      (error "Nuklear initialisation failed (alien_nk_init returned NULL)"))
    (setf *nk-ctx*    ctx
          *nk-active* t)))

(defun nui-shutdown ()
  "Shut down the Nuklear GUI layer and release its GPU resources.
  Called automatically by RUN-WITH-UI when the game loop exits."
  (when *nk-active*
    (%nk-shutdown)
    (setf *nk-ctx*    nil
          *nk-active* nil)))

(declaim (inline nui-new-frame nui-render))

(defun nui-new-frame ()
  "Begin a new Nuklear frame.  Called by RUN-WITH-UI before UPDATE each frame.
  If you are not using RUN-WITH-UI, call this at the very start of :on-going."
  (when *nk-active* (%nk-new-frame)))

(defun nui-render ()
  "Composite the Nuklear draw lists onto the framebuffer.
  Called by RUN-WITH-UI after FLUSH-BATCH so the UI appears above sprites.
  If you are not using RUN-WITH-UI, call this at the very end of :on-going."
  (when *nk-active* (%nk-render)))
