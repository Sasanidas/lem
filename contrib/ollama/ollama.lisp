(defpackage #:lem-ollama 
  (:use :cl :lem :alexandria)
  (:export #:*host* 
           #:*model* 
           #:*close-hook* 
           #:*ollama-mode-keymap*
           #:ollama-prompt 
           #:ollama-request 
           #:handle-stream))
(in-package :lem-ollama)

(define-major-mode ollama-mode nil 
    (:name "ollama"
     :keymap *ollama-mode-keymap*))

(define-key *ollama-mode-keymap* "C-c C-c" 'ollama-close)

;; Customize these:
(defparameter *host* "192.168.68.110:11434")
(defparameter *model* "mistral")
(defvar *close-hook* nil)

;; global response stream
(defvar *resp* nil)

(define-command ollama-close () ()
  "close any ollama response currently being processed"
  (when *resp*
    (close *resp*)
    (setf *resp* nil))
  (when *close-hook*
    (ignore-errors (funcall *close-hook*))))

(defun chunga-read-line (stream)
  "chunga:read-line* doesnt work, so use this."
  (ignore-errors
    (loop :with line := ""
          :for c := (chunga:read-char* stream)
          :while (not (eql c #\newline))
          :do (setf line (concatenate 'string line (string c)))
          :finally (return line))))

(defun handle-stream (output)
  "direct the stream created by #'ollama-request to output"
  (loop :for line := (chunga-read-line *resp*)
        :while line
        :for data := (cl-json:decode-json-from-string line)
        :while (not (assoc-value data :done))
        :do (format output (assoc-value data :response))
        :do (redraw-display))
  (ollama-close))

(defun ollama-request (prompt)
  "prompt the ollama server and set the response stream variable"
  (setf *resp*
        (dex:post
         (format nil "http://~a/api/generate" *host*)
         :want-stream t
         :force-binary t
         :keep-alive nil
         :read-timeout 120
         :headers '(("content-type" . "application/json"))
         :content (cl-json:encode-json-to-string
                   `(("model" . ,*model*)
                     ("prompt" . ,prompt))))))

(define-command ollama-prompt (prompt) ("sPrompt: ")
  "prompt ollama, and stream the response to a temp buffer"
  (let ((buf (make-buffer "*ollama*" :temporary t)))
    (unless (eq (buffer-major-mode buf) 'ollama-mode)
      (change-buffer-mode buf 'ollama-mode))
    (pop-to-buffer buf)
    (bt2:make-thread 
     (lambda () 
       (ignore-errors
         (setf *close-hook* (lambda () (message "done")))
         (ollama-request prompt)
         (with-open-stream (out (make-buffer-output-stream (buffer-point buf)))
           (handle-stream out)))))))
