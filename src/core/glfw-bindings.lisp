;; src/core/glfw-bindings.lisp

(in-package :cl-aliengine)

(define-alien-routine ("glfwInit"               glfw-init)                int)
(define-alien-routine ("glfwTerminate"          glfw-terminate)           void)
(define-alien-routine ("glfwCreateWindow"       glfw-create-window)       (* t)
  (w int) (h int) (title c-string) (monitor (* t)) (share (* t)))
(define-alien-routine ("glfwMakeContextCurrent" glfw-make-context-current) void
  (window (* t)))
(define-alien-routine ("glfwWindowShouldClose"  glfw-window-should-close) int
  (window (* t)))
(define-alien-routine ("glfwSwapBuffers"        glfw-swap-buffers)        void
  (window (* t)))
(define-alien-routine ("glfwPollEvents"         glfw-poll-events)         void)
(define-alien-routine ("glfwGetTime"            glfw-get-time)            double)
(define-alien-routine ("glfwSwapInterval"       glfw-swap-interval)       void
  (interval int))
(define-alien-routine ("glfwGetKey"             glfw-get-key)             int
  (window (* t)) (key int))
