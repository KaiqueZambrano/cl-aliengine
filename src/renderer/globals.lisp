;; src/renderer/globals.lisp

(in-package :cl-aliengine)

(defvar *sprite-shader* nil
  "The compiled OpenGL shader program used for all sprite and tile rendering.")

(defparameter *vert-src* "
#version 150 core
in vec2 aPos;
in vec2 aTexCoord;
out vec2 vTexCoord;
void main() {
    float x = (aPos.x / 400.0) - 1.0;
    float y = 1.0 - (aPos.y / 300.0);
    gl_Position = vec4(x, y, 0.0, 1.0);
    vTexCoord = aTexCoord;
}
"
  "Vertex shader source.  Converts pixel-space positions (origin top-left,
  half-extents 400x300) to normalised device coordinates.")

(defparameter *frag-src* "
#version 150 core
in vec2 vTexCoord;
out vec4 fragColor;
uniform sampler2D uTexture;
uniform vec4 uTint;
void main() {
    fragColor = texture(uTexture, vTexCoord) * uTint;
}
"
  "Fragment shader source.  Samples uTexture and multiplies by uTint.")

(defparameter *batch-max-sprites* 10000
  "Maximum number of sprites (quads) per texture per frame.
  Each quad uses 6 vertices × 4 floats = 24 floats.
  Increase this if you see sprites being silently dropped on large tilemaps.")

(defparameter *batch-group-floats* (* *batch-max-sprites* 6 4)
  "Total float capacity of a single batch group's vertex buffer.")

(defparameter *batch-vbo-bytes* (* *batch-group-floats* 4)
  "Byte size of the VBO allocated for one batch group.")

(defparameter *batch-groups* (make-hash-table :test #'eql)
  "Hash table mapping integer OpenGL texture IDs to their BATCH-GROUP.")

(defvar *batch-vao* nil "The VAO shared by all batch groups.")
(defvar *batch-vbo* nil "The VBO shared by all batch groups (re-uploaded each flush).")
