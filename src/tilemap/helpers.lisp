;; helpers.lisp

(in-package :cl-aliengine)

(defun tilemap-get-layer (tilemap-component layer-name)
  "Return the layer plist whose :name equals LAYER-NAME, or NIL.
  TILEMAP-COMPONENT is the plist returned by GET-COMPONENT for the tilemap
  component, or the dot-notation variable inside a DEFSYSTEM body."
  (find layer-name
        (getf tilemap-component :layers)
        :key  (lambda (l) (getf l :name))
        :test #'equal))

(defun tilemap-get-objects (tilemap-component layer-name)
  "Return the list of object plists from the object layer named LAYER-NAME, or NIL.
  Each object plist has keys: :id :name :type :x :y :width :height :properties.

  Example — spawn enemies from an object layer:
    (dolist (obj (tilemap-get-objects tilemap \"Enemies\"))
      (spawn (transform :x (getf obj :x) :y (getf obj :y))
             (enemy :kind (getf obj :type))))"
  (let ((layer (tilemap-get-layer tilemap-component layer-name)))
    (when (and layer (eq (getf layer :type) :object))
      (getf layer :objects))))

(defun tilemap-tile-at (tilemap-component layer-name tx ty)
  "Return the GID of the tile at tile coordinates (TX, TY) in the tile layer
  named LAYER-NAME.  Returns 0 for empty tiles or out-of-bounds coordinates.

  Example — simple tile collision:
    (unless (zerop (tilemap-tile-at tilemap \"Collision\" tile-x tile-y))
      (resolve-collision ...))"
  (let ((layer (tilemap-get-layer tilemap-component layer-name)))
    (when (and layer (eq (getf layer :type) :tile))
      (let ((lw (getf layer :width))
            (lh (getf layer :height)))
        (if (and (>= tx 0) (< tx lw) (>= ty 0) (< ty lh))
            (aref (getf layer :data) (+ (* ty lw) tx))
            0)))))

(defun tilemap-world-to-tile (tilemap-component wx wy)
  "Convert world-space pixel coordinates (WX, WY) to tile coordinates (TX, TY).
  Assumes the map origin is at (0, 0); subtract the tilemap entity's transform
  before calling if the map is offset."
  (values (floor wx (getf tilemap-component :tile-width))
          (floor wy (getf tilemap-component :tile-height))))
