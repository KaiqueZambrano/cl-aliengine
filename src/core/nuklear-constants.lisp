;; src/core/nuklear-constants.lisp

(in-package :cl-aliengine)

(defconstant +nk-text-left+     17
  "Left-justify text within its layout cell.")
(defconstant +nk-text-centered+ 18
  "Centre text within its layout cell.")
(defconstant +nk-text-right+    20
  "Right-justify text within its layout cell.")

(defconstant +nk-window-border+         1)
(defconstant +nk-window-movable+        2)
(defconstant +nk-window-scalable+       4)
(defconstant +nk-window-closable+       8)
(defconstant +nk-window-minimizable+   16)
(defconstant +nk-window-no-scrollbar+  32)
(defconstant +nk-window-title+         64)
(defconstant +nk-window-no-input+     512)

(defconstant +nk-window-default+
  (logior +nk-window-border+ +nk-window-movable+ +nk-window-title+)
  "Bordered, movable window with a title bar.")
(defconstant +nk-window-static+
  (logior +nk-window-border+ +nk-window-title+ +nk-window-no-scrollbar+)
  "Fixed window — suitable for HUDs that should not be dragged.")
(defconstant +nk-window-tooltip+
  (logior +nk-window-border+ +nk-window-no-scrollbar+ +nk-window-no-input+)
  "Borderless overlay with no interaction — handy for debug overlays.")
