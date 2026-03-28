;; widget-macros.lisp

(in-package :cl-aliengine)

(defmacro with-ui-window ((title &key (x 10) (y 10) (w 200) (h 300)
                                       (flags '+nk-window-default+))
                          &body body)
  "Open a Nuklear panel titled TITLE at screen position (X, Y) with size (W×H).
  BODY is evaluated only when the panel is visible (not minimised/closed).
  Always pairs BEGIN with END even when the panel is hidden.

  Keyword options:
    :x :y       — top-left screen position in pixels  (default 10, 10)
    :w :h       — panel size in pixels                (default 200, 300)
    :flags      — nk_panel_flags integer              (default +NK-WINDOW-DEFAULT+)

  Example:
    (with-ui-window (\"Settings\" :x 20 :y 20 :w 200 :h 140
                                  :flags +nk-window-static+)
      (ui-layout-row-dynamic 24 1)
      (ui-label (format nil \"Volume: ~a\" *vol*))
      (setf *vol* (ui-slider-int 0 *vol* 100)))"
  (let ((ctx (gensym "CTX")))
    `(when *nk-active*
       (let ((,ctx *nk-ctx*))
         (when (= 1 (%nk-begin ,ctx ,title
                               (float ,x 1.0f0) (float ,y 1.0f0)
                               (float ,w 1.0f0) (float ,h 1.0f0)
                               ,flags))
           ,@body)
         (%nk-end ,ctx)))))

(defmacro ui-layout-row-dynamic (height cols)
  "COLS equally-spaced columns of HEIGHT pixels each.
  Columns resize with the window.  Most common layout choice."
  `(%nk-layout-dynamic *nk-ctx* (float ,height 1.0f0) ,cols))

(defmacro ui-layout-row-static (height item-width cols)
  "COLS fixed-width (ITEM-WIDTH px) columns of HEIGHT pixels."
  `(%nk-layout-static *nk-ctx* (float ,height 1.0f0) ,item-width ,cols))

(defmacro with-ui-space ((height count) &body body)
  "Free-placement layout: positions up to COUNT widgets manually.
  Use UI-PLACE inside BODY to position each widget.

  Example (absolute pixel positions within the panel):
    (with-ui-space (80 2)
      (ui-place 0 0 60 20)  (ui-label \"Name\")
      (ui-place 64 0 120 20) (ui-label *player-name*))"
  `(progn
     (%nk-space-begin *nk-ctx* (float ,height 1.0f0) ,count)
     ,@body
     (%nk-space-end *nk-ctx*)))

(defmacro ui-place (x y w h)
  "Set the position for the next widget inside WITH-UI-SPACE."
  `(%nk-space-push *nk-ctx*
                   (float ,x 1.0f0) (float ,y 1.0f0)
                   (float ,w 1.0f0) (float ,h 1.0f0)))

(defmacro ui-label (text &optional (align '+nk-text-left+))
  "Draw TEXT as a plain label.  ALIGN is one of the +NK-TEXT-*+ constants."
  `(%nk-label *nk-ctx* ,text ,align))

(defmacro ui-label-color (text r g b &optional (align '+nk-text-left+) (a 255))
  "Like UI-LABEL but with an explicit RGBA colour (0–255 per channel)."
  `(%nk-label-colored *nk-ctx* ,text ,align ,r ,g ,b ,a))

(defmacro ui-button (label)
  "Draw a push-button with LABEL.  Returns T on the frame it is clicked."
  `(= 1 (%nk-button *nk-ctx* ,label)))

(defmacro ui-slider-float (min val max &optional (step 0.01))
  "Float slider from MIN to MAX in steps of STEP.  Returns the new float value."
  `(%nk-slider-float *nk-ctx*
                     (float ,min 1.0f0) (float ,val 1.0f0)
                     (float ,max 1.0f0) (float ,step 1.0f0)))

(defmacro ui-slider-int (min val max &optional (step 1))
  "Integer slider from MIN to MAX in steps of STEP.  Returns the new integer."
  `(%nk-slider-int *nk-ctx* ,min ,val ,max ,step))

(defmacro ui-progress (cur max &optional (modifiable t))
  "Progress bar.  CUR and MAX are non-negative integers.
  When MODIFIABLE is T the user can drag the bar.
  Returns the (possibly updated) CUR value."
  `(%nk-progress *nk-ctx* ,cur ,max (if ,modifiable 1 0)))

(defmacro ui-check (label val)
  "Checkbox labelled LABEL.  VAL is the current boolean state.
  Returns the new boolean state (T or NIL)."
  `(= 1 (%nk-check *nk-ctx* ,label (if ,val 1 0))))

(defmacro ui-option (label active-p)
  "Radio button labelled LABEL.  Returns T when this option is selected.
  Manage exclusivity manually:
    (let ((sel (cond ((ui-option \"Easy\"   (eq *diff* :easy))   :easy)
                     ((ui-option \"Medium\" (eq *diff* :medium)) :medium)
                     ((ui-option \"Hard\"   (eq *diff* :hard))   :hard)
                     (t *diff*)))
      (setf *diff* sel))"
  `(= 1 (%nk-option *nk-ctx* ,label (if ,active-p 1 0))))

(defmacro ui-property-int (name min val max &optional (step 1) (inc 1.0))
  "Spinner property field for integers.  Returns the new integer value.
  INC-PER-PIXEL controls sensitivity when the user drags over the field."
  `(%nk-prop-int *nk-ctx* ,name ,min ,val ,max ,step (float ,inc 1.0f0)))

(defmacro ui-property-float (name min val max &optional (step 0.1) (inc 0.5))
  "Spinner property field for floats.  Returns the new float value."
  `(%nk-prop-float *nk-ctx* ,name
                   (float ,min 1.0f0) (float ,val 1.0f0)
                   (float ,max 1.0f0) (float ,step 1.0f0)
                   (float ,inc 1.0f0)))

(defmacro ui-spacer ()
  "Skip one layout cell without drawing anything."
  `(%nk-spacer *nk-ctx*))

(defmacro ui-separator ()
  "Draw a thin horizontal dividing line across the current row."
  `(%nk-separator *nk-ctx*))

(defun ui-style-window-bg (r g b &optional (a 255))
  "Set the background colour of the most recently opened panel.
  R G B A are integers in [0, 255]."
  (when *nk-active*
    (%nk-style-window-bg *nk-ctx* r g b a)))

(defun ui-style-text-color (r g b &optional (a 255))
  "Set the global text colour.  R G B A are integers in [0, 255]."
  (when *nk-active*
    (%nk-style-text-color *nk-ctx* r g b a)))

(defun ui-style-button-colors (nr ng nb
                                hr hg hb
                                ar ag ab
                                &optional (na 255) (ha 255) (aa 255))
  "Set button colours for normal / hover / active states.
  Pass RGB integer triples (0–255); alpha defaults to 255."
  (when *nk-active*
    (%nk-style-button-color *nk-ctx*
                             nr ng nb na
                             hr hg hb ha
                             ar ag ab aa)))
