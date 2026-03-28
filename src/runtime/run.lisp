;; run.lisp

(in-package :cl-aliengine)

(defun run (title width height fps initial-scene)
  "Initialise the engine and run the game loop until the window is closed.

  TITLE         — window title string.
  WIDTH HEIGHT  — window dimensions in pixels; also set *SCREEN-WIDTH/HEIGHT*.
  FPS           — target frame rate; pass 0 to run uncapped.
  INITIAL-SCENE — symbol naming the first scene to activate (via SWITCH-SCENE).

  The loop sequence each frame:
    1. Compute delta-time and bind *DT*.
    2. Call UPDATE, which dispatches to the current scene's :on-going hook.
    3. Call FLUSH-BATCH to submit all queued draw calls to OpenGL.
    4. Swap buffers and poll events.
    5. Busy-wait if necessary to honour the FPS cap.

  On exit, :on-exit is called on the current scene, all assets are freed, and
  the VAO/VBO and shader program are deleted before GLFW terminates."
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

    (let ((prog (make-shader-program *vert-src* *frag-src*)))
      (multiple-value-bind (vao vbo) (make-batch-renderer)
        (setf *batch-vao*    vao
              *batch-vbo*    vbo
              *sprite-shader* prog)

        (gl-use-program prog)
        (gl-uniform-1i (gl-get-uniform-location prog "uTexture") 0)
        (gl-uniform-4f (gl-get-uniform-location prog "uTint") 1.0f0 1.0f0 1.0f0 1.0f0)

        (switch-scene initial-scene)

        (let* ((target-dt (if (> fps 0) (/ 1.0d0 fps) 0.0d0))
               (last-time (glfw-get-time)))

          (loop while (= 0 (glfw-window-should-close win)) do
            (let* ((frame-start (glfw-get-time))
                   (dt          (- frame-start last-time)))
              (setf last-time frame-start)

              (gl-clear-color 0.2f0 0.2f0 0.2f0 1.0f0)
              (gl-clear +color-buffer-bit+)

              (let ((*dt* dt))
                (update))

              (flush-batch)

              (glfw-swap-buffers win)
              (glfw-poll-events)

              (when (> target-dt 0.0d0)
                (let ((remaining (- target-dt (- (glfw-get-time) frame-start))))
                  (when (> remaining 0.002d0)
                    (sleep (- remaining 0.002d0)))
                  (loop while (< (- (glfw-get-time) frame-start) target-dt)))))))

        (when *current-scene*
          (funcall (getf *current-scene* :on-exit)))

        (asset-free-all)

        (with-alien ((p unsigned-int vao) (q unsigned-int vbo))
          (gl-delete-vertex-arrays 1 (addr p))
          (gl-delete-buffers      1 (addr q)))
        (gl-delete-program prog))))

  (setf *window* nil)
  (glfw-terminate))
