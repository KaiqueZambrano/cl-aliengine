;; src/tilemap/json-parser.lisp

(in-package :cl-aliengine)

(defun %json-read-file (path)
  "Read the entire UTF-8 file at PATH into a string and return it."
  (with-open-file (s path :direction :input :external-format :utf-8)
    (let* ((buf (make-string (+ (file-length s) 1)))
           (n   (read-sequence buf s)))
      (subseq buf 0 n))))

(defun %json-skip-ws (str pos)
  "Advance the mutable position cursor POS past any whitespace in STR.
  POS is a cons cell (index . nil) used as a mutable integer reference."
  (loop while (and (< (car pos) (length str))
                   (member (char str (car pos))
                           '(#\Space #\Tab #\Newline #\Return #\Page)))
        do (incf (car pos))))

(defun %json-expect-char (str pos ch)
  "Skip whitespace then assert that the character at POS in STR equals CH.
  Advances POS past CH on success; signals an error on mismatch."
  (%json-skip-ws str pos)
  (unless (char= (char str (car pos)) ch)
    (error "JSON: expected '~a' at position ~a, found '~a'"
           ch (car pos) (char str (car pos))))
  (incf (car pos)))

(defun %json-parse-string (str pos)
  "Parse a JSON string starting at POS in STR.  Returns the Lisp string value
  and advances POS past the closing double-quote.  Handles standard JSON
  escape sequences (\\n \\t \\r \\\\ \\\" \\/)."
  (%json-expect-char str pos #\")
  (let ((out (make-string-output-stream)))
    (loop
      (when (>= (car pos) (length str))
        (error "JSON: unexpected end of input inside string"))
      (let ((c (char str (car pos))))
        (incf (car pos))
        (cond
          ((char= c #\") (return (get-output-stream-string out)))
          ((char= c #\\)
           (let ((e (char str (car pos))))
             (incf (car pos))
             (write-char (case e
                           (#\n #\Newline) (#\t #\Tab)
                           (#\r #\Return)  (#\\ #\\)
                           (#\"  #\")      (#\/ #\/)
                           (t e))
                         out)))
          (t (write-char c out)))))))

(defun %json-parse-number (str pos)
  "Parse a JSON number starting at POS in STR.
  Uses a fast integer path for whole numbers (the common case for tile GIDs)
  and falls back to READ-FROM-STRING for decimals and scientific notation."
  (let ((start (car pos)) (neg nil))
    (when (char= (char str start) #\-)
      (setf neg t)
      (incf (car pos)))
    (let ((n 0))
      (loop while (and (< (car pos) (length str))
                       (digit-char-p (char str (car pos))))
            do (setf n (+ (* n 10) (digit-char-p (char str (car pos)))))
               (incf (car pos)))
      (if (and (< (car pos) (length str))
               (find (char str (car pos)) ".eE" :test #'char=))
          (progn
            (loop while (and (< (car pos) (length str))
                             (find (char str (car pos)) "0123456789.eE+-" :test #'char=))
                  do (incf (car pos)))
            (read-from-string (subseq str start (car pos))))
          (if neg (- n) n)))))

(defun %json-parse-array (str pos)
  "Parse a JSON array starting at POS in STR.
  Returns a Lisp list of parsed values and advances POS past the closing bracket."
  (%json-expect-char str pos #\[)
  (%json-skip-ws str pos)
  (if (char= (char str (car pos)) #\])
      (progn (incf (car pos)) '())
      (let ((items '()))
        (loop
          (push (%json-parse-value str pos) items)
          (%json-skip-ws str pos)
          (case (char str (car pos))
            (#\, (incf (car pos)))
            (#\] (incf (car pos)) (return))
            (t   (error "JSON: expected ',' or ']' at position ~a" (car pos)))))
        (nreverse items))))

(defun %json-parse-object (str pos)
  "Parse a JSON object starting at POS in STR.
  Returns an alist of (string . value) pairs and advances POS past the closing brace."
  (%json-expect-char str pos #\{)
  (%json-skip-ws str pos)
  (if (char= (char str (car pos)) #\})
      (progn (incf (car pos)) '())
      (let ((pairs '()))
        (loop
          (%json-skip-ws str pos)
          (let ((k (%json-parse-string str pos)))
            (%json-expect-char str pos #\:)
            (push (cons k (%json-parse-value str pos)) pairs))
          (%json-skip-ws str pos)
          (case (char str (car pos))
            (#\, (incf (car pos)))
            (#\} (incf (car pos)) (return))
            (t   (error "JSON: expected ',' or '}' at position ~a" (car pos)))))
        (nreverse pairs))))

(defun %json-parse-value (str pos)
  "Dispatch to the appropriate parser for the JSON value at POS in STR.
  Handles strings, objects, arrays, numbers, true, false, and null."
  (%json-skip-ws str pos)
  (when (>= (car pos) (length str))
    (error "JSON: unexpected end of input"))
  (let ((c (char str (car pos))))
    (case c
      (#\" (%json-parse-string str pos))
      (#\{ (%json-parse-object str pos))
      (#\[ (%json-parse-array  str pos))
      (t
       (cond
         ((or (digit-char-p c) (char= c #\-))
          (%json-parse-number str pos))
         ((and (<= (+ (car pos) 4) (length str))
               (string= str "true" :start1 (car pos) :end1 (+ (car pos) 4)))
          (incf (car pos) 4) t)
         ((and (<= (+ (car pos) 5) (length str))
               (string= str "false" :start1 (car pos) :end1 (+ (car pos) 5)))
          (incf (car pos) 5) nil)
         ((and (<= (+ (car pos) 4) (length str))
               (string= str "null" :start1 (car pos) :end1 (+ (car pos) 4)))
          (incf (car pos) 4) :null)
         (t (error "JSON: unexpected character '~a' at position ~a" c (car pos))))))))

(defun json-parse (str)
  "Parse the JSON string STR and return the corresponding Lisp value.
  Mapping: object → alist, array → list, string → string,
           integer → integer, float → float, true → T, false → NIL, null → :NULL."
  (%json-parse-value str (cons 0 nil)))

(defun json-get (obj key)
  "Look up KEY (a string) in the JSON object OBJ (an alist).
  Returns the associated value, or NIL if KEY is absent."
  (cdr (assoc key obj :test #'equal)))

