/*
 * nk_shim.c — Nuklear + GLFW3/OpenGL3 backend shim for cl-aliengine.
 *
 * This file compiles Nuklear's header-only implementation and wraps every
 * function that needs struct/pointer arguments into flat C functions that
 * are trivial to call from SBCL's alien FFI.
 *
 * ── Compilation ──────────────────────────────────────────────────────────────
 *
 *  Linux:
 *    gcc -shared -fPIC -O2 -o libnk_shim.so nk_shim.c \
 *        -lglfw -lGL -lm -ldl
 *
 *  macOS:
 *    gcc -dynamiclib -O2 -o libnk_shim.dylib nk_shim.c \
 *        -lglfw -framework OpenGL -lm
 *
 *  Windows (MinGW):
 *    gcc -shared -O2 -o nk_shim.dll nk_shim.c \
 *        -lglfw3 -lopengl32 -lgdi32 -lm
 *
 */

/* ── OpenGL — expose all core/extension prototypes before Nuklear ──────────── *
 * nuklear_glfw_gl3.h uses GL 3.x functions (glCreateProgram, glGenBuffers,   *
 * glMapBuffer, …) that <GL/gl.h> alone does not declare on most systems.     *
 * GL_GLEXT_PROTOTYPES makes <GL/glext.h> emit extern declarations for every  *
 * extension/core function without requiring GLEW or GLAD.                    *
 * The actual symbols are resolved at link time from libGL (-lGL).             */
#define GL_GLEXT_PROTOTYPES
#include <GL/gl.h>
#include <GL/glext.h>
#include <GLFW/glfw3.h>

/* ── Nuklear configuration ─────────────────────────────────────────────────── */
#define NK_INCLUDE_FIXED_TYPES
#define NK_INCLUDE_STANDARD_IO
#define NK_INCLUDE_STANDARD_VARARGS
#define NK_INCLUDE_DEFAULT_ALLOCATOR
#define NK_INCLUDE_VERTEX_BUFFER_OUTPUT
#define NK_INCLUDE_FONT_BAKING
#define NK_INCLUDE_DEFAULT_FONT
#define NK_IMPLEMENTATION
#define NK_GLFW_GL3_IMPLEMENTATION
#include "nuklear.h"
#include "nuklear_glfw_gl3.h"

/* ── Private globals ───────────────────────────────────────────────────────── */
static struct nk_glfw _nk_glfw   = {0};
static struct nk_context *_nk_ctx = NULL;

#define _MAX_VERTEX_BUF   (512 * 1024)
#define _MAX_ELEMENT_BUF  (128 * 1024)


/* ══════════════════════════════════════════════════════════════════════════════
 *  Lifecycle
 * ══════════════════════════════════════════════════════════════════════════════ */

/*
 * alien_nk_init — initialise Nuklear for the given GLFW window.
 * Returns the nk_context pointer on success, NULL on failure.
 * Installs GLFW input callbacks automatically.
 * Bakes and uploads the default built-in font.
 */
struct nk_context *
alien_nk_init(GLFWwindow *win)
{
    struct nk_font_atlas *atlas;
    _nk_ctx = nk_glfw3_init(&_nk_glfw, win, NK_GLFW3_INSTALL_CALLBACKS);
    if (!_nk_ctx) return NULL;
    nk_glfw3_font_stash_begin(&_nk_glfw, &atlas);
    nk_glfw3_font_stash_end(&_nk_glfw);
    return _nk_ctx;
}

/* alien_nk_shutdown — free all Nuklear GPU resources. */
void alien_nk_shutdown(void) { nk_glfw3_shutdown(&_nk_glfw); _nk_ctx = NULL; }

/* alien_nk_new_frame — begin a Nuklear frame; call after glfwPollEvents. */
void alien_nk_new_frame(void) { nk_glfw3_new_frame(&_nk_glfw); }

/* alien_nk_render — composite Nuklear draw lists; call before glfwSwapBuffers. */
void alien_nk_render(void)
{
    nk_glfw3_render(&_nk_glfw, NK_ANTI_ALIASING_ON,
                    _MAX_VERTEX_BUF, _MAX_ELEMENT_BUF);
}


/* ══════════════════════════════════════════════════════════════════════════════
 *  Window management
 * ══════════════════════════════════════════════════════════════════════════════ */

/*
 * alien_nk_begin — open a panel.
 * Returns 1 if the panel is visible and widgets should be submitted, 0 otherwise.
 * Always pair with alien_nk_end regardless of the return value.
 */
int
alien_nk_begin(struct nk_context *ctx,
               const char *title,
               float x, float y, float w, float h,
               unsigned int flags)
{
    return nk_begin(ctx, title, nk_rect(x, y, w, h), (nk_flags)flags);
}

/* alien_nk_end — close the most recently opened panel. */
void alien_nk_end(struct nk_context *ctx) { nk_end(ctx); }


/* ══════════════════════════════════════════════════════════════════════════════
 *  Layout
 * ══════════════════════════════════════════════════════════════════════════════ */

void alien_nk_layout_row_dynamic(struct nk_context *ctx, float h, int cols)
{
    nk_layout_row_dynamic(ctx, h, cols);
}

void alien_nk_layout_row_static(struct nk_context *ctx, float h,
                                 int item_w, int cols)
{
    nk_layout_row_static(ctx, h, item_w, cols);
}

/* Ratio-based layout: pass COLS floats as a plain C array via a pointer. */
void alien_nk_layout_row(struct nk_context *ctx, float h,
                          int cols, const float *ratios)
{
    nk_layout_row(ctx, NK_DYNAMIC, h, cols, ratios);
}

/* Space-layout: manually position widgets with nk_layout_space_push calls. */
void alien_nk_layout_space_begin(struct nk_context *ctx, float h, int widget_count)
{
    nk_layout_space_begin(ctx, NK_STATIC, h, widget_count);
}

void alien_nk_layout_space_push(struct nk_context *ctx,
                                  float x, float y, float w, float h)
{
    nk_layout_space_push(ctx, nk_rect(x, y, w, h));
}

void alien_nk_layout_space_end(struct nk_context *ctx)
{
    nk_layout_space_end(ctx);
}


/* ══════════════════════════════════════════════════════════════════════════════
 *  Widgets
 * ══════════════════════════════════════════════════════════════════════════════ */

void alien_nk_label(struct nk_context *ctx, const char *str, unsigned int align)
{
    nk_label(ctx, str, (nk_flags)align);
}

void alien_nk_label_colored(struct nk_context *ctx, const char *str,
                              unsigned int align,
                              unsigned char r, unsigned char g,
                              unsigned char b, unsigned char a)
{
    nk_label_colored(ctx, str, (nk_flags)align, nk_rgba(r, g, b, a));
}

/* Returns 1 when clicked. */
int alien_nk_button(struct nk_context *ctx, const char *label)
{
    return nk_button_label(ctx, label);
}

/*
 * alien_nk_slider_float — draw a float slider.
 * Passes val by value; returns the new value to avoid pointer indirection.
 */
float alien_nk_slider_float(struct nk_context *ctx,
                              float mn, float val, float mx, float step)
{
    nk_slider_float(ctx, mn, &val, mx, step);
    return val;
}

/* alien_nk_slider_int — integer variant. */
int alien_nk_slider_int(struct nk_context *ctx,
                         int mn, int val, int mx, int step)
{
    nk_slider_int(ctx, mn, &val, mx, step);
    return val;
}

/* alien_nk_progress — returns the (possibly modified) cur value. */
nk_size alien_nk_progress(struct nk_context *ctx, nk_size cur,
                            nk_size mx, int modifiable)
{
    nk_progress(ctx, &cur, mx, modifiable ? NK_MODIFIABLE : NK_FIXED);
    return cur;
}

/* alien_nk_check — checkbox; returns new boolean as int. */
int alien_nk_check(struct nk_context *ctx, const char *label, int active)
{
    return nk_check_label(ctx, label, active);
}

/* alien_nk_option — radio button; returns 1 when this option is selected. */
int alien_nk_option(struct nk_context *ctx, const char *label, int active)
{
    return nk_option_label(ctx, label, active);
}

/*
 * alien_nk_property_int — spinner property for integers; returns new value.
 * inc_per_pixel controls sensitivity when dragging over the widget.
 */
int alien_nk_property_int(struct nk_context *ctx,
                            const char *name,
                            int mn, int val, int mx,
                            int step, float inc_per_pixel)
{
    nk_property_int(ctx, name, mn, &val, mx, step, inc_per_pixel);
    return val;
}

/* alien_nk_property_float — float variant. */
float alien_nk_property_float(struct nk_context *ctx,
                                const char *name,
                                float mn, float val, float mx,
                                float step, float inc_per_pixel)
{
    nk_property_float(ctx, name, mn, &val, mx, step, inc_per_pixel);
    return val;
}

/* alien_nk_edit_string — single-line text input.
 * buf must be a writable C string; max is the buffer capacity.
 * Returns the new length of the string. */
int alien_nk_edit_string(struct nk_context *ctx, char *buf, int len, int max)
{
    nk_edit_string(ctx, NK_EDIT_SIMPLE, buf, &len, max, nk_filter_default);
    return len;
}

/* alien_nk_spacer — skip one layout cell without drawing. */
void alien_nk_spacer(struct nk_context *ctx)
{
    nk_spacing(ctx, 1);
}

/* alien_nk_separator — horizontal line spanning the full row width. */
void alien_nk_separator(struct nk_context *ctx)
{
    struct nk_rect bounds = nk_layout_widget_bounds(ctx);
    struct nk_command_buffer *canvas = nk_window_get_canvas(ctx);
    nk_stroke_line(canvas,
                   bounds.x, bounds.y + bounds.h / 2.0f,
                   bounds.x + bounds.w, bounds.y + bounds.h / 2.0f,
                   1.0f,
                   ctx->style.text.color);
}


/* ══════════════════════════════════════════════════════════════════════════════
 *  Colour helpers  (values in 0–255 range for easy Lisp usage)
 * ══════════════════════════════════════════════════════════════════════════════ */

/* Set window/panel background colour. */
void alien_nk_style_window_bg(struct nk_context *ctx,
                                unsigned char r, unsigned char g,
                                unsigned char b, unsigned char a)
{
    struct nk_color col = nk_rgba(r, g, b, a);
    ctx->style.window.background              = col;
    ctx->style.window.fixed_background        = nk_style_item_color(col);
}

/* Set button normal/hover/active colours. */
void alien_nk_style_button_color(struct nk_context *ctx,
                                   unsigned char nr, unsigned char ng,
                                   unsigned char nb, unsigned char na,
                                   unsigned char hr, unsigned char hg,
                                   unsigned char hb, unsigned char ha,
                                   unsigned char ar, unsigned char ag,
                                   unsigned char ab, unsigned char aa)
{
    ctx->style.button.normal = nk_style_item_color(nk_rgba(nr, ng, nb, na));
    ctx->style.button.hover  = nk_style_item_color(nk_rgba(hr, hg, hb, ha));
    ctx->style.button.active = nk_style_item_color(nk_rgba(ar, ag, ab, aa));
}

/* Set text colour globally. */
void alien_nk_style_text_color(struct nk_context *ctx,
                                 unsigned char r, unsigned char g,
                                 unsigned char b, unsigned char a)
{
    ctx->style.text.color = nk_rgba(r, g, b, a);
}
