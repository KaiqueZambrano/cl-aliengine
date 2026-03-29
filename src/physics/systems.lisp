;; systems.lisp

(in-package :cl-aliengine)

(defsystem physics :with (transform velocity) :stage (:update)
  "Integrate acceleration and velocity into TRANSFORM each frame.

  Execution order inside DEFSCENE :on-going (recommended):
    handle input → (syscall physics) → (run-collisions) → (syscall render-sprites)

  Example — entity with gravity and horizontal friction:
    (spawn (transform  :x 200 :y 50)
           (velocity   :vx 0 :vy 0 :ax 0 :ay 500 :friction 0)
           (sprite     ...))"
  (let ((dt *dt*))
    (incf velocity.vx (* velocity.ax dt))
    (incf velocity.vy (* velocity.ay dt))
    (let ((damp (max 0.0d0 (- 1.0d0 (* velocity.friction dt)))))
      (setf velocity.vx (* velocity.vx damp)
            velocity.vy (* velocity.vy damp)))
    (setf transform.x (round (+ transform.x (* velocity.vx dt)))
          transform.y (round (+ transform.y (* velocity.vy dt))))))

(defun run-collisions ()
  "Detect AABB collisions between all entities that have TRANSFORM + COLLIDER.
  For each overlapping pair whose layers/masks are compatible:
    1. Calls ON-COLLIDE callbacks on both entities (if set).
    2. If either entity is SOLID, applies a minimum-translation push to
       separate them and zeroes the velocity component on the pushed axis
       (if the entity also has a VELOCITY component).

  Call once per frame from DEFSCENE :on-going, AFTER (syscall physics):
    (syscall physics)
    (run-collisions)
    (syscall render-sprites)

  Layer/mask example — player (layer 1) vs enemy (layer 2):
    Player collider: :layer 1 :mask 2   ← reacts to enemies
    Enemy  collider: :layer 2 :mask 1   ← reacts to player
    Terrain collider: :layer 4 :mask 0  ← sensor, no reactions
    Player vs terrain: :mask (logior 2 4) to also react to terrain. "
  (let ((candidates '()))
    (dolist (entity *entities*)
      (when (and (entity-has entity 'transform)
                 (entity-has entity 'collider))
        (push entity candidates)))
    (loop for rest on candidates do
      (let* ((a       (car rest))
             (a-col   (get-component a 'collider))
             (a-layer (or (getf a-col :layer) 0))
             (a-mask  (or (getf a-col :mask)  0)))
        (dolist (b (cdr rest))
          (let* ((b-col   (get-component b 'collider))
                 (b-layer (or (getf b-col :layer) 0))
                 (b-mask  (or (getf b-col :mask)  0)))
            (when (and (not (zerop (logand a-mask b-layer)))
                       (not (zerop (logand b-mask a-layer))))
              (multiple-value-bind (ax ay aw ah) (%collider-world-rect a)
                (multiple-value-bind (bx by bw bh) (%collider-world-rect b)
                  (when (%aabb-overlap-p ax ay aw ah bx by bw bh)
                    (let ((a-fn (getf a-col :on-collide))
                          (b-fn (getf b-col :on-collide)))
                      (when a-fn (funcall a-fn a b))
                      (when b-fn (funcall b-fn b a)))
                    (let ((a-solid (getf a-col :solid))
                          (b-solid (getf b-col :solid)))
                      (when (or a-solid b-solid)
                        (multiple-value-bind (dx dy)
                            (%aabb-mtv ax ay aw ah bx by bw bh)
                          (flet ((push-entity (ent pdx pdy)
                                   "Translate ENT's transform and zero the matching velocity axis."
                                   (let ((tr (get-component ent 'transform)))
                                     (incf (getf tr :x) pdx)
                                     (incf (getf tr :y) pdy))
                                   (when (entity-has ent 'velocity)
                                     (let ((vel (get-component ent 'velocity)))
                                       (unless (zerop pdx)
                                         (setf (getf vel :vx) 0.0d0))
                                       (unless (zerop pdy)
                                         (setf (getf vel :vy) 0.0d0))))))
                            (cond
                              ((and a-solid b-solid)
                               (let ((hx (round (/ dx 2)))
                                     (hy (round (/ dy 2))))
                                 (push-entity a    hx     hy)
                                 (push-entity b (- hx) (- hy))))
                              (a-solid
                               (push-entity a dx dy))
                              (t
                               (push-entity b (- dx) (- dy))))))))))))))))))
