;; components.lisp

(in-package :cl-aliengine)

(defcomponent velocity (vx vy ax ay friction))
;; VX VY    : current velocity in pixels per second.
;; AX AY    : constant per-frame acceleration in pixels/s²  (e.g. gravity: :ay 500).
;; FRICTION : exponential damping coefficient per second.
;;            Applied as damp = max(0, 1 - friction*dt).
;;            0.0 → no damping; 5.0 → heavy braking; 20.0 → nearly instant stop.

(defcomponent collider (w h offset-x offset-y layer mask solid on-collide))
;; W H              : bounding-box size in pixels.
;; OFFSET-X OFFSET-Y: offset from the entity's TRANSFORM :x/:y.
;; LAYER            : integer bitmask that identifies this entity's own layer.
;; MASK             : integer bitmask of layers this entity reacts to.
;;                    A pair (A,B) collides only when:
;;                      (logand A.mask B.layer) ≠ 0  AND
;;                      (logand B.mask A.layer) ≠ 0
;;                    Pass -1 to react to all layers; 0 to react to nothing.
;; SOLID            : T → engine pushes the entity out of overlapping solid partners.
;;                    NIL → sensor only (callbacks fire but no position correction).
;; ON-COLLIDE       : (lambda (self other) ...) called each frame a hit is detected.
