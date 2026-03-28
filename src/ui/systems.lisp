;; systems.lisp

(in-package :cl-aliengine)

(defsystem render-ui :with (ui-panel)
  "Draw all visible UI panels for every entity that has a UI-PANEL component.
  Always call this as the LAST system in :on-going when using RUN-WITH-UI,
  so the panels composite on top of the sprite batch.

  Example scene:
    (defscene game
      :on-going
      (syscall update-camera)
      (syscall animate)
      (syscall render-sprites)
      (syscall render-tilemaps)
      (syscall render-ui))"
  (when (and *nk-active* ui-panel.visible)
    (when (= 1 (%nk-begin *nk-ctx*
                          ui-panel.title
                          (float ui-panel.x 1.0f0)
                          (float ui-panel.y 1.0f0)
                          (float ui-panel.w 1.0f0)
                          (float ui-panel.h 1.0f0)
                          ui-panel.flags))
      (funcall ui-panel.fn))
    (%nk-end *nk-ctx*)))
