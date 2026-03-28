;; components.lisp

(in-package :cl-aliengine)

(defcomponent particle-emitter
  (texture src-x src-y src-w src-h
   rate max-particles lifetime
   speed-min speed-max angle-min angle-max
   gravity scale particles accumulator active))
;; TEXTURE                 : GPU-TEXTURE used for all particles in this emitter.
;; SRC-X SRC-Y SRC-W SRC-H: source rectangle within TEXTURE.
;;                           Omit SRC-W/SRC-H to use the full texture size.
;; RATE                    : new particles spawned per second.
;; MAX-PARTICLES           : hard cap on simultaneous live particles.
;; LIFETIME                : seconds each particle lives after being spawned.
;; SPEED-MIN SPEED-MAX     : random initial speed range (pixels/second).
;; ANGLE-MIN ANGLE-MAX     : random emission angle range in radians.
;;                           0 = right, π/2 = down, π = left, 3π/2 = up.
;;                           Defaults to full 360°: 0 .. 2π.
;; GRAVITY                 : extra downward acceleration on particles (pixels/s²).
;;                           Independent of the entity's own VELOCITY component.
;; SCALE                   : draw-scale multiplier applied to SRC-W/SRC-H.
;; PARTICLES               : internal list of live particle plists — do not set.
;; ACCUMULATOR             : internal fractional spawn counter — do not set.
;; ACTIVE                  : T = keep spawning; NIL = drain and let all particles die.

