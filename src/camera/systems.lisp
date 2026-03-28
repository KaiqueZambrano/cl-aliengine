;; system.lisp

(in-package :cl-aliengine)

(defsystem update-camera :with (camera)
  "Move the camera toward its TARGET using delta-time-independent lerp, then
  clamp the result within the declared world bounds.  Writes the final position
  to *CAMERA-X* and *CAMERA-Y* so DRAW-TEXTURE picks it up automatically.
  Always call this before any render system each frame."
  (let* ((sw  *screen-width*)
         (sh  *screen-height*)
         (cx  camera.x)
         (cy  camera.y)
         (tgt camera.target))

    (when tgt
      (let* ((tpos   (get-component tgt 'transform))
             (dest-x (- (getf tpos :x) (ash sw -1)))
             (dest-y (- (getf tpos :y) (ash sh -1)))
             (spd    camera.smooth))
        (if (or (null spd) (zerop spd))
            (setf cx dest-x
                  cy dest-y)
            (let ((alpha (float (* spd *dt*) 1.0d0)))
              (setf cx (round (+ cx (* alpha (- dest-x cx))))
                    cy (round (+ cy (* alpha (- dest-y cy))))))))

    (let ((x0 camera.clamp-x0) (y0 camera.clamp-y0)
          (x1 camera.clamp-x1) (y1 camera.clamp-y1))
      (when (and x0 x1)
        (setf cx (max x0 (min cx (- x1 sw)))))
      (when (and y0 y1)
        (setf cy (max y0 (min cy (- y1 sh))))))

    (setf camera.x    cx
          camera.y    cy
          *camera-x*  cx
          *camera-y*  cy))))
