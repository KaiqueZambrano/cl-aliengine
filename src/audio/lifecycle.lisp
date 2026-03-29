;; src/audio/lifecycle.lisp

(defun audio-init ()
  "Initialise the miniaudio engine.  Returns T on success, NIL otherwise."
  (if (= 1 (ma-shim-init))
      (progn (setf *audio-ready* t) t)
      (progn
        (format t "~&[audio] ERROR: engine init failed: ~A~%"
                (ma-shim-get-last-error))
        (setf *audio-ready* nil)
        nil)))

(defun audio-shutdown ()
  "Shut down the miniaudio engine.  Safe to call even if never initialised."
  (when *audio-ready*
    (ma-shim-uninit)
    (setf *audio-ready* nil)))

(defun audio-free-all ()
  "Free every live audio-source native pointer across all entities."
  (dolist (entity *entities*)
    (when (entity-has entity 'audio-source)
      (audio-source-free entity))))

(defun set-master-volume (vol)
  "Set global audio volume (0.0-1.0).  Updates *MASTER-VOLUME*."
  (let ((v (max 0.0 (min 1.0 (float vol)))))
    (setf *master-volume* v)
    (when *audio-ready*
      (ma-shim-set-master-volume (coerce v 'single-float)))))