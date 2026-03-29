;; src/ecs/dot-notation.lisp

(in-package :cl-aliengine)

(defun %expand-dots (form with-list)
  "Walk FORM replacing dot-notation symbols (e.g. transform.x) with
  (getf transform :x) when the prefix matches a name in WITH-LIST.
  Used internally by DEFSYSTEM to enable the compact field-access syntax."
  (cond
    ((and (symbolp form) (not (keywordp form)))
     (let* ((name    (symbol-name form))
            (dot-pos (position #\. name)))
       (if dot-pos
           (let ((comp  (intern (subseq name 0 dot-pos) *package*))
                 (field (intern (subseq name (1+ dot-pos)) :keyword)))
             (if (member comp with-list :test #'string=)
                 `(getf ,comp ,field)
                 form))
           form)))
    ((atom form) form)
    (t (mapcar (lambda (x) (%expand-dots x with-list)) form))))
