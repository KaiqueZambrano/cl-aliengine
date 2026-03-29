;; src/audio/components.lisp

(in-package :cl-aliengine)

(defcomponent audio-source (path ptr volume pitch loop stream state))
;;
;; Fields
;; ──────
;;   :path   — filesystem path to the audio file (string, required).
;;   :ptr    — internal field, do NOT set manually.
;;               NIL           = not yet loaded (initial value).
;;               :load-failed  = loading was attempted and failed.
;;               <alien (* t)> = live ma_sound* handle.
;;   :volume — playback amplitude, 0.0–1.0.  Default: 1.0.
;;   :pitch  — pitch multiplier.  1.0 = original, 2.0 = one octave up.  Default: 1.0.
;;   :loop   — T for seamless looping (good for BGM).  Default: NIL.
;;   :stream — T to stream from disk (low RAM, good for music).
;;             NIL to pre-decode into RAM (low latency, good for SFX).  Default: NIL.
;;   :state  — playback state / command.  Drive this with AUDIO-PLAY / AUDIO-STOP.
;;               :idle     — loaded but not playing.
;;               :play     — request to start (acted on by AUDIO-SYSTEM).
;;               :playing  — currently playing.
;;               :stop     — request to stop (acted on by AUDIO-SYSTEM).
;;               :stopped  — explicitly stopped.
;;
;; Typical spawn:
;;   (spawn (transform :x 0 :y 0)
;;          (audio-source :path  "assets/sfx/jump.wav"
;;                        :volume 0.8
;;                        :pitch  1.0
;;                        :loop   nil
;;                        :stream nil
;;                        :state  :play   ; start playing immediately
;;                        :ptr    nil))


;; ── public API ────────────────────────────────────────────────────────────

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
