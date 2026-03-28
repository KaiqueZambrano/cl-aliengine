;; systems.lisp

(in-package :cl-aliengine)

(defsystem animate :with (sprite animator)
  "Advance the animator and update the sprite's source rectangle each frame.
  Handles animation switching, looping, and one-shot playback.
  TEXTURE is swapped on the sprite if the animation plist provides one."
  (let* ((current-anim animator.current)
         (anim-data    (cdr (assoc current-anim animator.animations))))
    (when anim-data
      (unless (eq current-anim animator.last-animation)
        (setf animator.current-time 0.0
              animator.current-frame 0
              animator.last-animation current-anim)
        (let ((new-tex (getf anim-data :texture)))
          (when new-tex
            (setf sprite.texture new-tex))))

      (let* ((dt *dt*)
             (frame-time (getf anim-data :frame-time))
             (loop (getf anim-data :loop))
             (playing animator.playing)
             (frames (getf anim-data :frames))
             (current-time animator.current-time)
             (current-frame animator.current-frame)
             (frame-width sprite.src-w)
             (frame-height sprite.src-h)
             (texture sprite.texture))

        (when playing
          (setf current-time (+ current-time dt))
          (let ((total-time (* frame-time (length frames))))
            (if loop
                (setf current-time (mod current-time total-time))
                (when (> current-time total-time)
                  (setf current-time total-time
                        playing nil))))
          (setf current-frame (floor current-time frame-time))
          (setf animator.current-time current-time
                animator.current-frame current-frame
                animator.playing playing))

        (let* ((cols (floor (gpu-texture-width texture) frame-width))
               (frame-x (mod current-frame cols))
               (frame-y (floor current-frame cols)))
          (setf sprite.src-x (* frame-x frame-width)
                sprite.src-y (* frame-y frame-height)))))))
