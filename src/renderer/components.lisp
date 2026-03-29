;; src/renderer/components.lisp

(in-package :cl-aliengine)

(defcomponent transform (x y))
(defcomponent sprite (texture src-x src-y src-w src-h scale :flip-x))
