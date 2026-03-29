;; src/audio/systems.lisp

(in-package :cl-aliengine)

(defun %resolve-audio-path (raw-path)
  "Resolve RAW-PATH to an absolute namestring suitable for the C shim.

  Strategy (first match wins):
    1. Already absolute -> return as-is.
    2. Exists relative to *default-pathname-defaults* (CWD) -> return absolute.
    3. Exists relative to the aliengine ASDF system root -> return absolute.
    4. None of the above -> return RAW-PATH unchanged so the C shim
       prints a clear 'file not found' message."
  (let ((p (pathname raw-path)))
    (cond
      ((and (pathname-directory p)
            (eq :absolute (car (pathname-directory p))))
       raw-path)
      
      ((probe-file p)
       (namestring (truename p)))
      
      (t
       (let* ((sys-dir  (asdf:system-source-directory :aliengine))
              (abs-path (merge-pathnames p sys-dir)))
         (if (probe-file abs-path)
             (namestring (truename abs-path))
             raw-path))))))

(defsystem audio-system :with (audio-source) :stage (:update)
  ;;
  ;; Call (syscall audio-system) every frame from your scene's :on-going hook.
  ;;
  ;; Frame work:
  ;;   1. Lazy-load  — first frame only: resolve path, call ma_shim_sound_load,
  ;;                   configure volume/pitch/loop, cache pointer in :ptr.
  ;;   2. State dispatch — translate :state keyword to native calls.

  (when (and *audio-ready* (null audio-source.ptr))
    (let* ((resolved (%resolve-audio-path audio-source.path))
           (ptr (ma-shim-sound-load resolved
                                    (if audio-source.stream 0 1))))
      (cond
        ((null-ptr-p ptr)
         (let ((reason (ma-shim-get-last-error)))
           (format t "~&[audio] WARNING: failed to load ~S~%~
                      ~8T~A~%"
                   audio-source.path
                   (if (and reason (> (length reason) 0))
                       reason
                       "unknown error — check path and codec support")))
         (setf (getf audio-source :ptr) :load-failed))
        (t
         (ma-shim-sound-set-volume ptr (coerce (or audio-source.volume 1.0) 'single-float))
         (ma-shim-sound-set-pitch  ptr (coerce (or audio-source.pitch  1.0) 'single-float))
         (ma-shim-sound-set-loop   ptr (if audio-source.loop 1 0))
         (setf (getf audio-source :ptr) ptr)))))

  (let ((ptr audio-source.ptr))
    (when (and ptr (not (keywordp ptr)))
      (case audio-source.state

        (:play
         (ma-shim-sound-play ptr)
         (setf (getf audio-source :state) :playing))

        (:stop
         (ma-shim-sound-stop ptr)
         (setf (getf audio-source :state) :stopped))

        (:playing
         (when (and (not audio-source.loop)
                    (= 1 (ma-shim-sound-at-end ptr)))
           (setf (getf audio-source :state) :stopped)))))))
