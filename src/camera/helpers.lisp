;; helpers.lisp

(in-package :cl-aliengine)

(defun camera-snap (camera-entity)
  "Teleport the camera immediately to its target, bypassing the smooth lerp.
  Call this in :on-init after spawning the camera to avoid a slide-in on the
  first frame.  CAMERA-ENTITY is the entity returned by SPAWN."
  (let* ((cam  (get-component camera-entity 'camera))
         (tgt  (getf cam :target))
         (tpos (when tgt (get-component tgt 'transform))))
    (when tpos
      (let ((nx (- (getf tpos :x) (ash *screen-width*  -1)))
            (ny (- (getf tpos :y) (ash *screen-height* -1))))
        (setf (getf cam :x) nx
              (getf cam :y) ny
              *camera-x*    nx
              *camera-y*    ny)))))

(defun camera-set-clamp (camera-entity x0 y0 x1 y1)
  "Update the world bounds used for camera clamping at runtime.
  Pass NIL for both X0/X1 or Y0/Y1 to disable clamping on that axis.

  Example — after loading a new level:
    (camera-set-clamp *cam* 0 0 (* cols tile-w) (* rows tile-h))
    (camera-snap *cam*)"
  (let ((cam (get-component camera-entity 'camera)))
    (setf (getf cam :clamp-x0) x0
          (getf cam :clamp-y0) y0
          (getf cam :clamp-x1) x1
          (getf cam :clamp-y1) y1)))

(defun camera-set-target (camera-entity target-entity)
  "Change the camera's follow target to TARGET-ENTITY at runtime.
  TARGET-ENTITY must have a TRANSFORM component."
  (setf (getf (get-component camera-entity 'camera) :target)
        target-entity))

(defun camera-world-to-screen (wx wy)
  "Convert world-space coordinates (WX, WY) to screen-space coordinates.
  Returns two values: (screen-x screen-y).
  Useful for drawing UI elements anchored to world positions."
  (values (- wx *camera-x*)
          (- wy *camera-y*)))

(defun camera-screen-to-world (sx sy)
  "Convert screen-space coordinates (SX, SY) to world-space coordinates.
  Returns two values: (world-x world-y).
  Useful for mapping mouse/touch input to world positions."
  (values (+ sx *camera-x*)
          (+ sy *camera-y*)))
