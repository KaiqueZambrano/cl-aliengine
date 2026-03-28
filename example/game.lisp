;;;; game.lisp

(load "cl-aliengine.lisp")

(in-package :cl-aliengine)

;; ------------------------------------------------------------
;; Global state
;; ------------------------------------------------------------

(defparameter *volume*      80)
(defparameter *difficulty* :normal)
(defparameter *show-hud*    t)

(defparameter *frame-count*  0)
(defparameter *fps-display*  0)
(defparameter *fps-accum*   0.0)

(defparameter *pause-panel-entity* nil)

;; ------------------------------------------------------------
;; Components
;; ------------------------------------------------------------

(defcomponent velocity    (vx vy))
(defcomponent player      ())
(defcomponent dead        ())
(defcomponent pause-panel ())
(defcomponent hud-panel   ())

;; ------------------------------------------------------------
;; Systems
;; ------------------------------------------------------------

(defsystem movement :with (transform velocity) :without (dead)
  (setf transform.x (+ transform.x velocity.vx)
        transform.y (+ transform.y velocity.vy)))

(defsystem input :with (player velocity sprite)
  (cond
    ((key-down-p 256)
     (switch-scene 'pause-menu))
    ((key-down-p 262)
     (setf velocity.vx  10
           sprite.flip-x nil))
    ((key-down-p 263)
     (setf velocity.vx -10
           sprite.flip-x t))
    ((key-down-p 265) (setf velocity.vy -10))
    ((key-down-p 264) (setf velocity.vy  10))
    (t
     (setf velocity.vx 0
           velocity.vy 0))))

(defsystem select-animation :with (animator velocity)
  (setf animator.current
        (if (> (abs velocity.vx) 0) :run :idle)))

(defsystem sync-hud :with (hud-panel ui-panel)
  (incf *frame-count*)
  (incf *fps-accum* *dt*)
  (when (>= *fps-accum* 1.0)
    (setf *fps-display* *frame-count*
          *frame-count* 0
          *fps-accum*   (- *fps-accum* 1.0)))
  (setf ui-panel.visible *show-hud*))

(defun set-ui-panel-visible (entity visible)
  (let ((ui (get-component entity 'ui-panel)))
    (when ui
      (setf (getf ui :visible) visible))))

;; ------------------------------------------------------------
;; Scenes
;; ------------------------------------------------------------

(defscene gameplay
  :on-init
  (let* ((tex-idle (asset-texture "example/assets/idle.png"))
         (tex-run  (asset-texture "example/assets/run.png"))
         (player-entity
           (spawn
             (player)
             (transform :x 40 :y 40)
             (sprite    :texture tex-idle
                        :src-x 0 :src-y 0 :src-w 16 :src-h 16
                        :scale 4 :flip-x nil)
             (velocity  :vx 0 :vy 0)
             (animator  :animations
                          (make-animations
                            (idle :texture tex-idle
                                  :frames '(0 1 2 3)
                                  :frame-time 0.1 :loop t)
                            (run  :texture tex-run
                                  :frames '(0 1 2 3 4 5)
                                  :frame-time 0.1 :loop t))
                        :current        :idle
                        :current-time   0.0
                        :current-frame  0
                        :playing        t
                        :last-animation nil))))

    (multiple-value-bind (ts w h tw th ly)
        (load-tilemap "example/assets/level.json")
      (spawn (transform :x 0 :y 0)
             (tilemap :tileset ts :width w :height h
                      :tile-width tw :tile-height th :layers ly))
      (let ((cam (spawn (camera :x 0 :y 0
                                :smooth 6.0
                                :target  player-entity
                                :clamp-x0 0        :clamp-y0 0
                                :clamp-x1 (* w tw) :clamp-y1 (* h th)))))
        (camera-snap cam)))

    (spawn
      (hud-panel)
      (ui-panel :title   "##hud"
                :x       (- *screen-width* 170) :y 8
                :w       162 :h 120
                :flags   +nk-window-tooltip+
                :visible *show-hud*
                :fn      (lambda ()
                           (ui-style-window-bg    0   0   0 140)
                           (ui-style-text-color 180 255 180)

                           (ui-layout-row-dynamic 16 1)
                           (ui-label ">> HUD ATIVO <<" +nk-text-left+)

                           (query (:with (transform velocity))
                             (ui-layout-row-dynamic 16 1)
                             (ui-label (format nil "Pos  ~4d, ~4d"
                                               transform.x transform.y)
                                       +nk-text-left+)
                             (ui-layout-row-dynamic 16 1)
                             (ui-label (format nil "Vel  ~3d, ~3d"
                                               velocity.vx velocity.vy)
                                       +nk-text-left+)
                             (ui-layout-row-dynamic 2 1)
                             (ui-separator)
                             (ui-layout-row-dynamic 16 1)
                             (ui-label (format nil "FPS  ~3d" *fps-display*)
                                       +nk-text-left+))

                           (unless (find-if (lambda (e) (entity-has e 'player)) *entities*)
                             (ui-layout-row-dynamic 16 1)
                             (ui-label "Player not found" +nk-text-left+)))))
    )

  :on-going
  (syscall update-camera)
  (syscall sync-hud)
  (syscall input)
  (syscall movement)
  (syscall select-animation)
  (syscall animate)
  (syscall render-tilemaps)
  (syscall render-sprites)
  (syscall render-ui))

(defscene pause-menu
  :on-init
  (let ((mw 300) (mh 400))
    (setf *pause-panel-entity*
          (spawn
            (pause-panel)
            (ui-panel :title   "PAUSA"
                      :x       (floor (- *screen-width*  mw) 2)
                      :y       (floor (- *screen-height* mh) 2)
                      :w       mw :h mh
                      :flags   (logior +nk-window-border+
                                       +nk-window-title+
                                       +nk-window-no-scrollbar+)
                      :visible t
                      :fn      (lambda ()
                                 (ui-layout-row-dynamic 14 1)
                                 (ui-spacer)

                                 (ui-layout-row-dynamic 36 1)
                                 (when (ui-button "▶  Continuar")
                                   (switch-scene 'gameplay))

                                 (ui-layout-row-dynamic 14 1)
                                 (ui-spacer)
                                 (ui-layout-row-dynamic 2 1)
                                 (ui-separator)
                                 (ui-layout-row-dynamic 14 1)
                                 (ui-spacer)

                                 (ui-layout-row-dynamic 18 1)
                                 (ui-label (format nil "Volume: ~a" *volume*))

                                 (ui-layout-row-dynamic 22 1)
                                 (setf *volume* (ui-slider-int 0 *volume* 100))

                                 (ui-layout-row-dynamic 14 1)
                                 (ui-spacer)
                                 (ui-layout-row-dynamic 2 1)
                                 (ui-separator)
                                 (ui-layout-row-dynamic 14 1)
                                 (ui-spacer)

                                 (ui-layout-row-dynamic 18 1)
                                 (ui-label "Dificuldade:")

                                 (ui-layout-row-dynamic 22 3)
                                 (when (ui-option "Fácil"   (eq *difficulty* :easy))
                                   (setf *difficulty* :easy))
                                 (when (ui-option "Normal"  (eq *difficulty* :normal))
                                   (setf *difficulty* :normal))
                                 (when (ui-option "Difícil" (eq *difficulty* :hard))
                                   (setf *difficulty* :hard))

                                 (ui-layout-row-dynamic 14 1)
                                 (ui-spacer)
                                 (ui-layout-row-dynamic 2 1)
                                 (ui-separator)
                                 (ui-layout-row-dynamic 14 1)
                                 (ui-spacer)

                                 (ui-layout-row-dynamic 22 1)
                                 (setf *show-hud*
                                       (ui-check "Mostrar HUD de debug" *show-hud*))

                                 (ui-layout-row-dynamic 14 1)
                                 (ui-spacer)
                                 (ui-layout-row-dynamic 2 1)
                                 (ui-separator)
                                 (ui-layout-row-dynamic 14 1)
                                 (ui-spacer)

                                 (ui-layout-row-dynamic 14 1)
                                 (ui-label-color "cl-aliengine  v0.1  demo"
                                                 120 120 120 +nk-text-centered+)

                                 (ui-layout-row-dynamic 14 1)
                                 (ui-spacer)

                                 (ui-layout-row-dynamic 36 1)
                                 (when (ui-button "✕  Sair")
                                   (glfw-set-window-should-close *window* 1)))))))

  :on-enter
  (when *pause-panel-entity*
    (set-ui-panel-visible *pause-panel-entity* t))

  :on-exit
  (when *pause-panel-entity*
    (set-ui-panel-visible *pause-panel-entity* nil))

  :on-going
  (syscall sync-hud)
  (syscall render-tilemaps)
  (syscall render-sprites)
  (syscall render-ui))

;; ------------------------------------------------------------
;; Start
;; ------------------------------------------------------------

(run-with-ui "Exemplo" 800 600 60 'gameplay)
