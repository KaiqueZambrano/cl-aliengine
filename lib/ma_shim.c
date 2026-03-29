/*
 * ma_shim.c — thin C wrapper over miniaudio for aliengine.
 *
 * Build (see build-audio.sh):
 *   Linux  : gcc -O2 -shared -fPIC -o lib/libma_shim.so  lib/ma_shim.c -lpthread -lm -ldl
 *   macOS  : clang -O2 -shared -fPIC -o lib/libma_shim.dylib lib/ma_shim.c \
 *              -framework CoreFoundation -framework CoreAudio -framework AudioToolbox
 *   Windows: gcc -O2 -shared -o lib/ma_shim.dll lib/ma_shim.c -lole32
 *
 * miniaudio.h must be present alongside this file (single-header, no other deps).
 * Download: https://raw.githubusercontent.com/mackron/miniaudio/master/miniaudio.h
 */

#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* ── last-error buffer ───────────────────────────────────────────────────── */

static char g_last_error[256] = "";

static void set_error(const char* msg)
{
    strncpy(g_last_error, msg, sizeof(g_last_error) - 1);
    g_last_error[sizeof(g_last_error) - 1] = '\0';
}

/* Return a static C string describing the last failure.
   Valid until the next call to any ma_shim_* function. */
const char* ma_shim_get_last_error(void)
{
    return g_last_error;
}

/* ── engine singleton ─────────────────────────────────────────────────────── */

static ma_engine g_engine;
static int       g_ready = 0;

int ma_shim_init(void)
{
    if (g_ready) return 1;
    ma_result r = ma_engine_init(NULL, &g_engine);
    if (r != MA_SUCCESS) {
        snprintf(g_last_error, sizeof(g_last_error),
                 "ma_engine_init failed: %s", ma_result_description(r));
        return 0;
    }
    g_ready = 1;
    return 1;
}

void ma_shim_uninit(void)
{
    if (!g_ready) return;
    ma_engine_uninit(&g_engine);
    g_ready = 0;
}

/* ── per-sound lifecycle ──────────────────────────────────────────────────── */

/*
 * ma_shim_sound_load — allocate and initialise a sound from a file path.
 *
 *   decode == 1 : pre-decode entire file into RAM (best for short SFX).
 *   decode == 0 : stream directly from disk       (best for long music).
 *
 * Returns an opaque ma_sound* on success, NULL on failure.
 * Call ma_shim_get_last_error() after NULL to get the reason.
 */
void* ma_shim_sound_load(const char* path, int decode)
{
    if (!g_ready) { set_error("audio engine not initialised"); return NULL; }
    if (!path)    { set_error("null path");                    return NULL; }

    /* Probe existence before asking miniaudio — gives a cleaner error. */
    FILE* probe = fopen(path, "rb");
    if (!probe) {
        snprintf(g_last_error, sizeof(g_last_error),
                 "file not found or not readable: %s", path);
        return NULL;
    }
    fclose(probe);

    ma_sound* s = (ma_sound*)malloc(sizeof(ma_sound));
    if (!s) { set_error("malloc failed"); return NULL; }

    ma_uint32 flags = decode ? MA_SOUND_FLAG_DECODE : 0;
    ma_result r = ma_sound_init_from_file(&g_engine, path, flags, NULL, NULL, s);
    if (r != MA_SUCCESS) {
        snprintf(g_last_error, sizeof(g_last_error),
                 "ma_sound_init_from_file(\"%s\"): %s",
                 path, ma_result_description(r));
        free(s);
        return NULL;
    }

    g_last_error[0] = '\0';
    return s;
}

void ma_shim_sound_free(void* ptr)
{
    if (!ptr) return;
    ma_sound_uninit((ma_sound*)ptr);
    free(ptr);
}

/* ── playback control ─────────────────────────────────────────────────────── */

void ma_shim_sound_play(void* ptr)
{
    if (!ptr) return;
    ma_sound_seek_to_pcm_frame((ma_sound*)ptr, 0);
    ma_sound_start((ma_sound*)ptr);
}

void ma_shim_sound_resume(void* ptr)
{
    if (ptr) ma_sound_start((ma_sound*)ptr);
}

void ma_shim_sound_stop(void* ptr)
{
    if (ptr) ma_sound_stop((ma_sound*)ptr);
}

void ma_shim_sound_rewind(void* ptr)
{
    if (ptr) ma_sound_seek_to_pcm_frame((ma_sound*)ptr, 0);
}

/* ── sound parameters ─────────────────────────────────────────────────────── */

void ma_shim_sound_set_loop(void* ptr, int loop)
{
    if (ptr) ma_sound_set_looping((ma_sound*)ptr, loop ? MA_TRUE : MA_FALSE);
}

void ma_shim_sound_set_volume(void* ptr, float vol)
{
    if (ptr) ma_sound_set_volume((ma_sound*)ptr, vol);
}

void ma_shim_sound_set_pitch(void* ptr, float pitch)
{
    if (ptr) ma_sound_set_pitch((ma_sound*)ptr, pitch);
}

/* ── state queries ────────────────────────────────────────────────────────── */

int ma_shim_sound_is_playing(void* ptr)
{
    if (!ptr) return 0;
    return ma_sound_is_playing((ma_sound*)ptr) ? 1 : 0;
}

int ma_shim_sound_at_end(void* ptr)
{
    if (!ptr) return 0;
    return ma_sound_at_end((ma_sound*)ptr) ? 1 : 0;
}

/* ── global engine ────────────────────────────────────────────────────────── */

void ma_shim_set_master_volume(float vol)
{
    if (g_ready) ma_engine_set_volume(&g_engine, vol);
}
