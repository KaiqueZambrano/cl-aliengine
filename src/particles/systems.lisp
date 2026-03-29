;; src/particles/systems.lisp

(in-package :cl-aliengine)

(defsystem update-particles :with (transform particle-emitter) :stage (:update)
  "Advance every live particle in PARTICLE-EMITTER and spawn new ones.
  Each particle is a plist: (:x :y :vx :vy :life :max-life).

  Recommended call order:
    (syscall physics)
    (run-collisions)
    (syscall update-particles)   ; ← here
    (syscall render-particles)
    (syscall render-sprites) "
  (let* ((dt       *dt*)
         (grav     (or particle-emitter.gravity   0.0d0))
         (lifetime (or particle-emitter.lifetime  1.0d0))
         (acc      (+ (or particle-emitter.accumulator 0.0d0)
                      (* (or particle-emitter.rate 10.0d0) dt)))
         (to-spawn (floor acc))
         (ex       (float transform.x 1.0d0))
         (ey       (float transform.y 1.0d0)))

    (let ((live '()))
      (dolist (p particle-emitter.particles)
        (let ((new-life (- (getf p :life) dt)))
          (when (> new-life 0.0d0)
            (setf (getf p :life) new-life)
            (incf (getf p :x) (* (getf p :vx) dt))
            (incf (getf p :y) (* (getf p :vy) dt))
            (incf (getf p :vy) (* grav dt))
            (push p live))))
      (setf particle-emitter.particles live))

    (when particle-emitter.active
      (let* ((max-p (or particle-emitter.max-particles 200))
             (amin  (or particle-emitter.angle-min 0.0d0))
             (amax  (or particle-emitter.angle-max (* 2.0d0 pi)))
             (smin  (or particle-emitter.speed-min  50.0d0))
             (smax  (or particle-emitter.speed-max 100.0d0)))
        (dotimes (_ to-spawn)
          (when (< (length particle-emitter.particles) max-p)
            (let* ((angle (+ amin (* (random 1.0d0) (- amax amin))))
                   (speed (+ smin (* (random 1.0d0) (- smax smin)))))
              (push (list :x ex :y ey
                          :vx (* speed (cos angle))
                          :vy (* speed (sin angle))
                          :life     lifetime
                          :max-life lifetime)
                    particle-emitter.particles))))))

    (setf particle-emitter.accumulator (- acc to-spawn))))

(defsystem render-particles :with (particle-emitter) :stage (:render) :priority 15
  "Draw every live particle owned by PARTICLE-EMITTER.
  Particles are centered on their (x, y) world-space position.
  Call AFTER UPDATE-PARTICLES and before FLUSH-BATCH."
  (let* ((tex particle-emitter.texture))
    (when tex
      (let* ((sw  (or particle-emitter.src-w (gpu-texture-width  tex)))
           (sh  (or particle-emitter.src-h (gpu-texture-height tex)))
           (sx  (or particle-emitter.src-x 0))
           (sy  (or particle-emitter.src-y 0))
           (sc  (or particle-emitter.scale 1))
           (dw  (round (* sw sc)))
           (dh  (round (* sh sc)))
           (hw  (round (/ dw 2)))
           (hh  (round (/ dh 2))))
        (dolist (p particle-emitter.particles)
          (draw-texture tex sx sy sw sh
                        (- (round (getf p :x)) hw)
                        (- (round (getf p :y)) hh)
                        dw dh))))))
