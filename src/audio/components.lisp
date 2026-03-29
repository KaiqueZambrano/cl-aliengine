;; src/audio/components.lisp

(in-package :cl-aliengine)

(defcomponent audio-source (path ptr volume pitch loop stream state))
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