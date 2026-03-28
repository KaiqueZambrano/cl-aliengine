(load "../cl-aliengine.lisp")

(in-package :cl-aliengine)

(defcomponent velocity (vx vy))
(defcomponent player ())
(defcomponent dead ())

(defsystem movement :with (transform velocity) :without (dead)
  (setf transform.x (+ transform.x velocity.vx)
        transform.y (+ transform.y velocity.vy)))

(defsystem input :with (player velocity sprite)
  (cond
    ((key-down-p 262)
     (setf velocity.vx 10)
     (setf sprite.flip-x nil))
    ((key-down-p 263)
     (setf velocity.vx -10)
     (setf sprite.flip-x t))
    ((key-down-p 265)
     (setf velocity.vy -10))
    ((key-down-p 264)
     (setf velocity.vy 10))
    (t
     (setf velocity.vx 0
           velocity.vy 0))))

(defsystem select-animation :with (animator velocity)
  (let ((speed (abs velocity.vx)))
    (setf animator.current
          (if (> speed 0) :run :idle))))

(defscene gameplay
  :on-init
    (let* ((tex-idle (asset-texture "assets/idle.png"))
           (tex-run  (asset-texture "assets/run.png"))
           
           (player-entity
             (spawn
               (player)
               (transform :x 40 :y 40)
               (sprite :texture tex-idle :src-x 0 :src-y 0 :src-w 16 :src-h 16 :scale 4 :flip-x nil)
               (velocity :vx 0 :vy 0)
               (animator :animations (make-animations
                                       (idle :texture tex-idle :frames '(0 1 2 3) :frame-time 0.1 :loop t)
                                       (run  :texture tex-run  :frames '(0 1 2 3 4 5) :frame-time 0.1 :loop t))
                         :current :idle
                         :current-time 0.0
                         :current-frame 0
                         :playing t
                         :last-animation nil))))

      (multiple-value-bind (ts w h tw th ly) (load-tilemap "assets/level.json")
        (spawn (transform :x 0 :y 0)
               (tilemap :tileset ts :width w :height h
                        :tile-width tw :tile-height th :layers ly))

        (let ((cam (spawn (camera :x 0 :y 0
                                  :smooth 6.0
                                  :target player-entity
                                  :clamp-x0 0          :clamp-y0 0
                                  :clamp-x1 (* w tw)   :clamp-y1 (* h th)))))
          (camera-snap cam))))

  :on-going
    (syscall update-camera)
    (syscall input)
    (syscall movement)
    (syscall select-animation)
    (syscall render-tilemaps)
    (syscall animate)
    (syscall render-sprites))

(run "Exemplo" 800 600 60 'gameplay)
