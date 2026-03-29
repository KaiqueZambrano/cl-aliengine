;; src/audio/globals.lisp

(in-package :cl-aliengine)

(defparameter *audio-ready* nil
  "T when the miniaudio engine has been successfully initialised.
  Set to T by AUDIO-INIT; reset to NIL by AUDIO-SHUTDOWN.
  Check this before making any audio calls from outside the ECS.")

(defparameter *master-volume* 1.0
  "Global playback volume in the range 0.0–1.0.
  Change it with SET-MASTER-VOLUME; do not write directly.")
