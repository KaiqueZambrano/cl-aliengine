;; src/input/input.lisp

(in-package :cl-aliengine)

(defun key-down-p (key)
  "Return T if the GLFW key code KEY is currently held down.
  Use GLFW key constants (integers) directly, e.g. 262 = GLFW_KEY_RIGHT."
  (= 1 (glfw-get-key *window* key)))
