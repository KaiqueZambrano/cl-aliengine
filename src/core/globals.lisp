;; src/core/globals.lisp

(in-package :cl-aliengine)

(defparameter *dt* 0.0d0
  "Delta-time in seconds for the current frame.
  Bound dynamically inside the game loop; read this from systems to get
  frame-rate-independent behaviour.")

(defparameter *window* nil
  "The active GLFW window alien pointer, or NIL when outside RUN.")

(defparameter *screen-width* 800
  "Width of the game window in pixels.  Set by RUN before the first frame.")

(defparameter *screen-height* 600
  "Height of the game window in pixels.  Set by RUN before the first frame.")

(defparameter *camera-x* 0
  "Current camera X offset in world pixels.
  Subtracted from every dst-x in DRAW-TEXTURE.  Updated each frame by the
  UPDATE-CAMERA system.  Do not set manually; use CAMERA-SNAP instead.")

(defparameter *camera-y* 0
  "Current camera Y offset in world pixels.
  Subtracted from every dst-y in DRAW-TEXTURE.  Updated each frame by the
  UPDATE-CAMERA system.  Do not set manually; use CAMERA-SNAP instead.")

(defparameter *nk-ctx* nil
  "Alien pointer to the nk_context.  Valid after NUI-INIT, NIL otherwise.
  Macros like WITH-UI-WINDOW and UI-* implicitly use this context; you should
  never need to pass it explicitly.")

(defparameter *nk-active* nil
  "T when the Nuklear layer is initialised and ready to accept widget calls.")
