;; game.lisp

(in-package :cl-aliengine)

;; ------------------------------------------------------------
;; Resources
;; ------------------------------------------------------------

(defresource volume             50)
(defresource difficulty        :normal)
(defresource show-hud           t)

(defresource music
  (spawn (audio-source :path   "examples/platformer/assets/theme.mp3"
                       :volume (/ (get-resource 'volume) 100)
                       :loop   t
                       :stream t
                       :state  :play
                       :ptr    nil)))

(defresource frame-count        0)
(defresource fps-display        0)
(defresource fps-accum          0.0)

(defresource pause-panel-entity nil)

;; ------------------------------------------------------------
;; Constants
;; ------------------------------------------------------------

(defresource player-speed 600.0d0)

(defconstant +layer-player+ 1)
(defconstant +layer-walls+  2)

;; ------------------------------------------------------------
;; Components
;; ------------------------------------------------------------

(defcomponent player      ())
(defcomponent dead        ())
(defcomponent pause-panel ())
(defcomponent hud-panel   ())

;; ------------------------------------------------------------
;; Systems
;; ------------------------------------------------------------

(defsystem input
  :stage    (:update)
  :with     (player velocity sprite)
  :resource (player-speed)

  (when (key-down-p 256)
    (switch-scene 'pause-menu))

  (cond
    ((key-down-p 262) (setf velocity.vx  player-speed  sprite.flip-x nil))
    ((key-down-p 263) (setf velocity.vx (- player-speed) sprite.flip-x t))
    (t                (setf velocity.vx  0.0d0)))

  (cond
    ((key-down-p 265) (setf velocity.vy (- player-speed)))
    ((key-down-p 264) (setf velocity.vy  player-speed))
    (t                (setf velocity.vy  0.0d0))))

(defsystem select-animation
  :stage (:update)
  :with  (animator velocity)

  (setf animator.current
        (if (> (abs velocity.vx) 0.0d0) :run :idle)))

(defsystem sync-hud
  :stage    (:update)
  :with     (hud-panel ui-panel)
  :resource (frame-count fps-display fps-accum show-hud)

  (incf frame-count)
  (incf fps-accum *dt*)
  (when (>= fps-accum 1.0)
    (setf fps-display frame-count
          frame-count 0
          fps-accum   (- fps-accum 1.0)))
  (setf ui-panel.visible show-hud))

(defsystem sync-audio
  :stage    (:update)
  :resource (volume music)

  (audio-set-volume music (/ volume 100)))

;; ------------------------------------------------------------
;; Utilities
;; ------------------------------------------------------------

(defun set-ui-panel-visible (entity visible)
  (let ((ui (get-component entity 'ui-panel)))
    (when ui
      (setf (getf ui :visible) visible))))

;; ------------------------------------------------------------
;; Scenes
;; ------------------------------------------------------------

(defscene gameplay
  :on-init

  (let* ((tex-idle (asset-texture "examples/platformer/assets/idle.png"))
         (tex-run  (asset-texture "examples/platformer/assets/run.png"))
         (player-entity
           (spawn
             (player)
             (transform :x 40 :y 40)
             (sprite    :texture tex-idle
                        :src-x 0 :src-y 0 :src-w 16 :src-h 16
                        :scale 4 :flip-x nil)
             (velocity  :vx 0.0d0 :vy 0.0d0 :ax 0.0d0 :ay 0.0d0 :friction 0.0d0)
             (collider  :w 56 :h 56
                        :offset-x 4 :offset-y 4
                        :layer +layer-player+
                        :mask  +layer-walls+
                        :solid t
                        :on-collide nil)
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
        (load-tilemap "examples/platformer/assets/level.json")
      (spawn (transform :x 0 :y 0)
             (tilemap :tileset ts :width w :height h
                      :tile-width tw :tile-height th :layers ly))

      (let ((col-layer (find "collidable" ly
                             :key  (lambda (l) (getf l :name))
                             :test #'equal)))
        (when col-layer
          (dolist (obj (getf col-layer :objects))
            (spawn (transform :x (getf obj :x) :y (getf obj :y))
                   (collider  :w        (getf obj :width)
                              :h        (getf obj :height)
                              :offset-x 0
                              :offset-y 0
                              :layer    +layer-walls+
                              :mask     +layer-player+
                              :solid    nil
                              :on-collide nil)))))

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
                :visible (get-resource 'show-hud)
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
                             (ui-label (format nil "Vel  ~5,0f, ~5,0f"
                                               velocity.vx velocity.vy)
                                       +nk-text-left+)
                             (ui-layout-row-dynamic 2 1)
                             (ui-separator)
                             (ui-layout-row-dynamic 16 1)
                             (ui-label (format nil "FPS  ~3d"
                                               (get-resource 'fps-display))
                                       +nk-text-left+))

                           (unless (find-if (lambda (e) (entity-has e 'player)) *entities*)
                             (ui-layout-row-dynamic 16 1)
                             (ui-label "Player not found" +nk-text-left+))))))

  :on-going
  (run-stage :update)
  (run-collisions)
  (run-stage :render))

(defscene pause-menu
  :on-init
  (set-resource 'pause-panel-entity
    (let ((mw 300) (mh 400))
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
                             (ui-label (format nil "Volume: ~a" (get-resource 'volume)))

                             (ui-layout-row-dynamic 22 1)
                             (set-resource 'volume
                                           (ui-slider-int 0 (get-resource 'volume) 100))

                             (ui-layout-row-dynamic 14 1)
                             (ui-spacer)
                             (ui-layout-row-dynamic 2 1)
                             (ui-separator)
                             (ui-layout-row-dynamic 14 1)
                             (ui-spacer)

                             (ui-layout-row-dynamic 18 1)
                             (ui-label "Dificuldade:")

                             (ui-layout-row-dynamic 22 3)
                             (when (ui-option "Fácil"   (eq (get-resource 'difficulty) :easy))
                               (set-resource 'difficulty :easy))
                             (when (ui-option "Normal"  (eq (get-resource 'difficulty) :normal))
                               (set-resource 'difficulty :normal))
                             (when (ui-option "Difícil" (eq (get-resource 'difficulty) :hard))
                               (set-resource 'difficulty :hard))

                             (ui-layout-row-dynamic 14 1)
                             (ui-spacer)
                             (ui-layout-row-dynamic 2 1)
                             (ui-separator)
                             (ui-layout-row-dynamic 14 1)
                             (ui-spacer)

                             (ui-layout-row-dynamic 22 1)
                             (set-resource 'show-hud
                                           (ui-check "Mostrar HUD de debug"
                                                     (get-resource 'show-hud)))

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
  (let ((ppe (get-resource 'pause-panel-entity)))
    (when ppe
      (set-ui-panel-visible ppe t)))

  :on-exit
  (let ((ppe (get-resource 'pause-panel-entity)))
    (when ppe
      (set-ui-panel-visible ppe nil)))

  :on-going
  (syscall sync-hud)
  (syscall sync-audio)
  (run-stage :render))

;; ------------------------------------------------------------
;; Start
;; ------------------------------------------------------------

(run-with-ui "Exemplo" 800 600 60 'gameplay)
