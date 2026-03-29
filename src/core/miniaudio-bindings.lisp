;; src/audio/bindings.lisp

(in-package :cl-aliengine)

;; ── engine lifecycle ──────────────────────────────────────────────────────

(define-alien-routine ("ma_shim_init"   ma-shim-init)   int)
(define-alien-routine ("ma_shim_uninit" ma-shim-uninit) void)

;; ── error reporting ───────────────────────────────────────────────────────
;;
;; Returns a C string describing the last failure (file-not-found, decode
;; error, etc.).  Valid until the next ma_shim_* call.  Empty on success.

(define-alien-routine ("ma_shim_get_last_error" ma-shim-get-last-error) c-string)

;; ── per-sound lifecycle ───────────────────────────────────────────────────

(define-alien-routine ("ma_shim_sound_load" ma-shim-sound-load) (* t)
  (path   c-string)
  (decode int))

(define-alien-routine ("ma_shim_sound_free" ma-shim-sound-free) void
  (ptr (* t)))

;; ── playback control ──────────────────────────────────────────────────────

(define-alien-routine ("ma_shim_sound_play"   ma-shim-sound-play)   void (ptr (* t)))
(define-alien-routine ("ma_shim_sound_resume" ma-shim-sound-resume) void (ptr (* t)))
(define-alien-routine ("ma_shim_sound_stop"   ma-shim-sound-stop)   void (ptr (* t)))
(define-alien-routine ("ma_shim_sound_rewind" ma-shim-sound-rewind) void (ptr (* t)))

;; ── sound parameters ──────────────────────────────────────────────────────

(define-alien-routine ("ma_shim_sound_set_loop"   ma-shim-sound-set-loop)   void
  (ptr (* t)) (loop int))

(define-alien-routine ("ma_shim_sound_set_volume" ma-shim-sound-set-volume) void
  (ptr (* t)) (vol single-float))

(define-alien-routine ("ma_shim_sound_set_pitch"  ma-shim-sound-set-pitch)  void
  (ptr (* t)) (pitch single-float))

;; ── state queries ─────────────────────────────────────────────────────────

(define-alien-routine ("ma_shim_sound_is_playing" ma-shim-sound-is-playing) int
  (ptr (* t)))

(define-alien-routine ("ma_shim_sound_at_end" ma-shim-sound-at-end) int
  (ptr (* t)))

;; ── global engine ─────────────────────────────────────────────────────────

(define-alien-routine ("ma_shim_set_master_volume" ma-shim-set-master-volume) void
  (vol single-float))
