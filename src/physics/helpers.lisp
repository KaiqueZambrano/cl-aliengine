;; helpers.lisp

(in-package :cl-aliengine)

(declaim (inline %aabb-overlap-p))
(defun %aabb-overlap-p (ax ay aw ah bx by bw bh)
  "Return T when the two AABBs overlap."
  (declare (type real ax ay aw ah bx by bw bh))
  (and (< ax (+ bx bw))
       (> (+ ax aw) bx)
       (< ay (+ by bh))
       (> (+ ay ah) by)))

(defun %aabb-mtv (ax ay aw ah bx by bw bh)
  "Minimum-translation vector that pushes box-A out of box-B.
  Returns (values dx dy); pushes along the axis of least overlap."
  (declare (type real ax ay aw ah bx by bw bh))
  (let* ((ox1    (- (+ ax aw) bx))
         (ox2    (- (+ bx bw) ax))
         (oy1    (- (+ ay ah) by))
         (oy2    (- (+ by bh) ay))
         (push-x (if (< ox1 ox2) (- ox1) ox2))
         (push-y (if (< oy1 oy2) (- oy1) oy2)))
    (if (< (abs push-x) (abs push-y))
        (values push-x 0)
        (values 0     push-y))))

(defun %collider-world-rect (entity)
  "Return (values x y w h) for ENTITY's collider in world-space.
  Requires TRANSFORM and COLLIDER components to be present."
  (let ((tr (get-component entity 'transform))
        (co (get-component entity 'collider)))
    (values (+ (getf tr :x) (or (getf co :offset-x) 0))
            (+ (getf tr :y) (or (getf co :offset-y) 0))
            (getf co :w)
            (getf co :h))))
