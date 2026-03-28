;; run-with-ui.lisp

(in-package :cl-aliengine)

(defun run-with-ui (title width height fps initial-scene)
  "Like RUN, but with the Nuklear GUI layer fully integrated.

  TITLE         — window title string.
  WIDTH HEIGHT  — window dimensions in pixels.
  FPS           — target frame rate; 0 for uncapped.
  INITIAL-SCENE — symbol naming the first scene to activate.

  The frame sequence differs slightly from plain RUN:

    1. glfwPollEvents is called FIRST so Nuklear sees fresh input.
    2. nk_glfw3_new_frame — Nuklear processes that input.
    3. glClear.
    4. UPDATE — runs :on-going (declare panels and call SYSCALL render-ui here).
    5. gl-use-program + FLUSH-BATCH — draw all queued sprite quads.
    6. nk_glfw3_render — composite the Nuklear draw lists on top of sprites.
    7. glfwSwapBuffers.
    8. FPS cap if requested.

  On exit, NUI-SHUTDOWN is called automatically before GLFW terminates."
  (unless (= (glfw-init) 1)
    (error "GLFW initialisation failed"))

  (let ((win (glfw-create-window width height title (null-ptr) (null-ptr))))
    (when (null-ptr-p win)
      (glfw-terminate)
      (error "Failed to create GLFW window"))

    (setf *window*        win
          *screen-width*  width
          *screen-height* height)
    (glfw-make-context-current win)
    (glfw-swap-interval 0)

    (gl-enable +blend+)
    (gl-blend-func +src-alpha+ +one-minus-src-alpha+)

    (let ((nk-ctx (%nk-init win)))
      (when (null-ptr-p nk-ctx)
        (glfw-terminate)
        (error "Nuklear initialisation failed"))
      (setf *nk-ctx*    nk-ctx
            *nk-active* t))

    (let ((prog (make-shader-program *vert-src* *frag-src*)))
      (multiple-value-bind (vao vbo) (make-batch-renderer)
        (setf *batch-vao*     vao
              *batch-vbo*     vbo
              *sprite-shader* prog)

        (gl-use-program prog)
        (gl-uniform-1i (gl-get-uniform-location prog "uTexture") 0)
        (gl-uniform-4f (gl-get-uniform-location prog "uTint") 1.0f0 1.0f0 1.0f0 1.0f0)

        (switch-scene initial-scene)

        (let* ((target-dt (if (> fps 0) (/ 1.0d0 fps) 0.0d0))
               (last-time (glfw-get-time)))

          (loop while (= 0 (glfw-window-should-close win)) do
            (glfw-poll-events)

            (let* ((frame-start (glfw-get-time))
                   (dt          (- frame-start last-time)))
              (setf last-time frame-start)

              (%nk-new-frame)

              (gl-clear-color 0.2f0 0.2f0 0.2f0 1.0f0)
              (gl-clear +color-buffer-bit+)

              (let ((*dt* dt))
                (update))

              (gl-use-program *sprite-shader*)
              (gl-enable +blend+)
              (gl-blend-func +src-alpha+ +one-minus-src-alpha+)
              (flush-batch)

              (%nk-render)

              (glfw-swap-buffers win)

              (when (> target-dt 0.0d0)
                (let ((remaining (- target-dt (- (glfw-get-time) frame-start))))
                  (when (> remaining 0.002d0)
                    (sleep (- remaining 0.002d0)))
                  (loop while (< (- (glfw-get-time) frame-start) target-dt)))))))

        (when *current-scene*
          (funcall (getf *current-scene* :on-exit)))

        (nui-shutdown)
        (asset-free-all)

        (with-alien ((p unsigned-int vao) (q unsigned-int vbo))
          (gl-delete-vertex-arrays 1 (addr p))
          (gl-delete-buffers       1 (addr q)))
        (gl-delete-program prog))))

  (setf *window* nil)
  (glfw-terminate))
