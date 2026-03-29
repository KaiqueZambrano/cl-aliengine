;; src/tilemap/map-loader.lisp

(in-package :cl-aliengine)

(defun load-tilemap (path)
  "Load a Tiled JSON map file (.tmj / .json) and return six values:
    TILESET  WIDTH  HEIGHT  TILE-WIDTH  TILE-HEIGHT  LAYERS

  TILESET — a TILEMAP-TILESET (texture + column/GID metadata).
  LAYERS  — a list of layer plists (tile layers and object layers).

  External tileset files (.tsj) are resolved relative to the map file.
  Only the first tileset entry in the map is loaded.

  Typical usage:
    (multiple-value-bind (ts w h tw th ly) (load-tilemap \"assets/level1.tmj\")
      (spawn (transform :x 0 :y 0)
             (tilemap :tileset ts :width w :height h
                      :tile-width tw :tile-height th :layers ly)))"
  (let* ((dir      (%tiled-dir path))
         (json     (json-parse (%json-read-file path)))
         (mw       (json-get json "width"))
         (mh       (json-get json "height"))
         (tw       (json-get json "tilewidth"))
         (th       (json-get json "tileheight"))
         (ts-ref   (first (json-get json "tilesets")))
         (firstgid (or (json-get ts-ref "firstgid") 1))
         (tileset
           (let ((src (json-get ts-ref "source")))
             (if src
                 (let* ((tsj-path (%tiled-resolve src dir))
                        (tsj      (json-parse (%json-read-file tsj-path))))
                   (%tiled-load-tileset-json tsj dir firstgid))
                 (%tiled-load-tileset-json ts-ref dir firstgid))))
         (layers
           (mapcar #'%tiled-parse-layer
                   (or (json-get json "layers") '()))))
    (values tileset mw mh tw th layers)))

