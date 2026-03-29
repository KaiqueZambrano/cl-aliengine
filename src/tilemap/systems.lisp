;; systems.lisp

(in-package :cl-aliengine)

(defsystem render-tilemaps :with (transform tilemap) :stage (:render) :priority 0
  "Draw all visible tile layers of every entity that has TRANSFORM and TILEMAP.
  The transform's X/Y is used as the world-space origin of the map.
  Call this before RENDER-SPRITES so the map renders behind sprites."
  (let* ((ts  tilemap.tileset)
         (tw  tilemap.tile-width)
         (th  tilemap.tile-height)
         (ox  transform.x)
         (oy  transform.y)
         (tex (tilemap-tileset-texture  ts))
         (fg  (tilemap-tileset-firstgid ts))
         (col (tilemap-tileset-columns  ts)))
    (dolist (layer tilemap.layers)
      (when (and (eq  (getf layer :type)    :tile)
                 (not (null (getf layer :visible t))))
        (let* ((data (getf layer :data))
               (lw   (getf layer :width))
               (n    (length data)))
          (dotimes (i n)
            (let ((gid (aref data i)))
              (unless (zerop gid)
                (let* ((lid (- gid fg))
                       (tc  (mod   lid col))
                       (tr  (floor lid col))
                       (sx  (* tc tw))
                       (sy  (* tr th))
                       (mx  (mod   i lw))
                       (my  (floor i lw))
                       (dx  (+ ox (* mx tw)))
                       (dy  (+ oy (* my th))))
                  (draw-texture tex sx sy tw th dx dy tw th))))))))))
