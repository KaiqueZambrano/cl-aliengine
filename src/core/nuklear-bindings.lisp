;; nuklear-bindings.lisp

(in-package :cl-aliengine)

(define-alien-routine ("alien_nk_init"      %nk-init)      (* t) (win (* t)))
(define-alien-routine ("alien_nk_shutdown"  %nk-shutdown)  void)
(define-alien-routine ("alien_nk_new_frame" %nk-new-frame) void)
(define-alien-routine ("alien_nk_render"    %nk-render)    void)


(define-alien-routine ("alien_nk_begin" %nk-begin) int
  (ctx (* t)) (title c-string)
  (x single-float) (y single-float)
  (w single-float) (h single-float)
  (flags unsigned-int))

(define-alien-routine ("alien_nk_end" %nk-end) void (ctx (* t)))


(define-alien-routine ("alien_nk_layout_row_dynamic" %nk-layout-dynamic) void
  (ctx (* t)) (height single-float) (cols int))

(define-alien-routine ("alien_nk_layout_row_static" %nk-layout-static) void
  (ctx (* t)) (height single-float) (item-width int) (cols int))

(define-alien-routine ("alien_nk_layout_space_begin" %nk-space-begin) void
  (ctx (* t)) (height single-float) (count int))

(define-alien-routine ("alien_nk_layout_space_push" %nk-space-push) void
  (ctx (* t)) (x single-float) (y single-float)
  (w single-float) (h single-float))

(define-alien-routine ("alien_nk_layout_space_end" %nk-space-end) void
  (ctx (* t)))


(define-alien-routine ("alien_nk_label" %nk-label) void
  (ctx (* t)) (str c-string) (align unsigned-int))

(define-alien-routine ("alien_nk_label_colored" %nk-label-colored) void
  (ctx (* t)) (str c-string) (align unsigned-int)
  (r unsigned-char) (g unsigned-char) (b unsigned-char) (a unsigned-char))

(define-alien-routine ("alien_nk_button" %nk-button) int
  (ctx (* t)) (label c-string))

(define-alien-routine ("alien_nk_slider_float" %nk-slider-float) single-float
  (ctx (* t))
  (mn single-float) (val single-float) (mx single-float) (step single-float))

(define-alien-routine ("alien_nk_slider_int" %nk-slider-int) int
  (ctx (* t)) (mn int) (val int) (mx int) (step int))

(define-alien-routine ("alien_nk_progress" %nk-progress) unsigned-long
  (ctx (* t)) (cur unsigned-long) (mx unsigned-long) (modifiable int))

(define-alien-routine ("alien_nk_check" %nk-check) int
  (ctx (* t)) (label c-string) (active int))

(define-alien-routine ("alien_nk_option" %nk-option) int
  (ctx (* t)) (label c-string) (active int))

(define-alien-routine ("alien_nk_property_int" %nk-prop-int) int
  (ctx (* t)) (name c-string)
  (mn int) (val int) (mx int) (step int) (inc single-float))

(define-alien-routine ("alien_nk_property_float" %nk-prop-float) single-float
  (ctx (* t)) (name c-string)
  (mn single-float) (val single-float) (mx single-float)
  (step single-float) (inc single-float))

(define-alien-routine ("alien_nk_spacer"    %nk-spacer)    void (ctx (* t)))
(define-alien-routine ("alien_nk_separator" %nk-separator) void (ctx (* t)))


(define-alien-routine ("alien_nk_style_window_bg" %nk-style-window-bg) void
  (ctx (* t))
  (r unsigned-char) (g unsigned-char) (b unsigned-char) (a unsigned-char))

(define-alien-routine ("alien_nk_style_button_color" %nk-style-button-color) void
  (ctx (* t))
  (nr unsigned-char) (ng unsigned-char) (nb unsigned-char) (na unsigned-char)
  (hr unsigned-char) (hg unsigned-char) (hb unsigned-char) (ha unsigned-char)
  (ar unsigned-char) (ag unsigned-char) (ab unsigned-char) (aa unsigned-char))

(define-alien-routine ("alien_nk_style_text_color" %nk-style-text-color) void
  (ctx (* t))
  (r unsigned-char) (g unsigned-char) (b unsigned-char) (a unsigned-char))
