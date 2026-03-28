;; systems.lisp

(in-package :cl-aliengine)

(defsystem render-sprites :with (transform sprite)
  "Enqueue a draw call for every entity with both TRANSFORM and SPRITE.
  Scale is applied uniformly to SRC-W and SRC-H.  Call this after ANIMATE
  so the source rectangle reflects the current frame."
  (draw-texture sprite.texture
                sprite.src-x sprite.src-y
                sprite.src-w sprite.src-h
                transform.x transform.y
                (* sprite.src-w sprite.scale)
                (* sprite.src-h sprite.scale)
                sprite.flip-x))
