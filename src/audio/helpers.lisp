;; src/audio/helpers.lisp

(defun audio-play (entity)
  "Request that ENTITY's audio-source starts playing from the beginning.
  The AUDIO-SYSTEM will honour this command on the next frame.
  Has no effect if the entity has no audio-source component."
  (let ((src (get-component entity 'audio-source)))
    (when src
      (setf (getf src :state) :play))))

(defun audio-stop (entity)
  "Request that ENTITY's audio-source stops playback.
  The AUDIO-SYSTEM will honour this command on the next frame."
  (let ((src (get-component entity 'audio-source)))
    (when src
      (setf (getf src :state) :stop))))

(defun audio-resume (entity)
  "Resume ENTITY's audio-source from its current position without rewinding.
  Useful for un-pausing music mid-track."
  (let* ((src (get-component entity 'audio-source))
         (ptr (and src (getf src :ptr))))
    (when (and ptr (not (keywordp ptr)))
      (ma-shim-sound-resume ptr)
      (setf (getf src :state) :playing))))

(defun audio-set-volume (entity vol)
  "Set the playback volume (0.0–1.0) on ENTITY's audio-source immediately."
  (let* ((src (get-component entity 'audio-source))
         (ptr (and src (getf src :ptr))))
    (when src
      (setf (getf src :volume) (float vol)))
    (when (and ptr (not (keywordp ptr)))
      (ma-shim-sound-set-volume ptr (coerce vol 'single-float)))))

(defun audio-set-pitch (entity pitch)
  "Set the pitch multiplier on ENTITY's audio-source immediately."
  (let* ((src (get-component entity 'audio-source))
         (ptr (and src (getf src :ptr))))
    (when src
      (setf (getf src :pitch) (float pitch)))
    (when (and ptr (not (keywordp ptr)))
      (ma-shim-sound-set-pitch ptr (coerce pitch 'single-float)))))

(defun audio-playing-p (entity)
  "Return T if ENTITY's audio-source is currently playing."
  (let ((src (get-component entity 'audio-source)))
    (and src (eq (getf src :state) :playing))))

(defun audio-source-free (entity)
  "Free the native sound pointer held by ENTITY's audio-source component.
  Call this BEFORE KILL-ENTITY to avoid leaking audio memory.
  Safe to call even if the sound has not been loaded yet."
  (let* ((src (get-component entity 'audio-source))
         (ptr (and src (getf src :ptr))))
    (when (and ptr (not (keywordp ptr)))
      (ma-shim-sound-free ptr)
      (setf (getf src :ptr)   nil)
      (setf (getf src :state) :stopped))))