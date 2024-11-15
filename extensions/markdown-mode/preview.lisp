(defpackage :lem-markdown-mode/preview
  (:use #:cl
        #:lem)
  (:documentation "Live rendering of markdown documents to a browser.

This package defines the command M-x markdown-preview that opens a browser window, connects to it via a websocket, and renders and updates the markdown in the browser at each file save.

The WS connection is closed when the markdown file is closed."))

(in-package :lem-markdown-mode/preview)

(defclass server (trivial-ws:server)
  ((handler :initform nil
            :accessor server-handler)))

(defvar *server*
  (make-instance 'server
                 :on-connect 'on-connect
                 :on-disconnect 'on-disconnect
                 :on-message 'on-message))

(defun on-connect (server)
  (declare (ignore server)))

(defun on-disconnect (server)
  (declare (ignore server)))

(defun on-message (server)
  (declare (ignore server)))

(defvar *template*
  (lisp-preprocessor:compile-template
   (asdf:system-relative-pathname :lem-markdown-mode "index.html")
   :arguments '($websocket-url $body)))

(defun render (string)
  (let ((3bmd-code-blocks:*code-blocks* t))
    (with-output-to-string (stream)
      (3bmd:parse-string-and-print-to-stream string stream))))

(defun generate-html (buffer websocket-port)
  (uiop:with-temporary-file (:stream out
                             :pathname html-file
                             :keep t
                             :type "html")
    (lisp-preprocessor:run-template-into-stream
     *template*
     out
     (format nil "\"ws://localhost:~A\"" websocket-port)
     (render (buffer-text buffer)))
    :close-stream
    html-file))

(defun buffer-server (buffer)
  (buffer-value buffer 'websocket-server))

(defun get-buffer-server-or-make (buffer)
  (or (buffer-server buffer)
      (setf (buffer-value buffer 'websocket-server)
            (make-instance 'server
                           :on-connect 'on-connect
                           :on-disconnect 'on-disconnect
                           :on-message 'on-message))))

(defun setup-server (buffer)
  (let ((server (get-buffer-server-or-make buffer)))
    (when (server-handler server)
      (trivial-ws:stop (server-handler server)))
    (let ((port (lem-socket-utils:random-available-port)))
      (setf (server-handler server)
            (trivial-ws:start server port))
      port)))

(defun generate-html-and-preview (buffer)
  (let* ((port (setup-server buffer))
         (html-file (generate-html buffer port)))
    (trivial-open-browser:open-browser (namestring html-file))))

(defun refresh (buffer)
  (alexandria:when-let ((server (get-buffer-server-or-make buffer)))
    (let ((html (render (buffer-text buffer))))
      (dolist (client (trivial-ws:clients server))
        (handler-case (trivial-ws:send client html)
          (error (e)
            (log:error e)))))))

(defmethod lem-markdown-mode/internal:on-save (buffer)
  (refresh buffer))

(defmethod lem-markdown-mode/internal:on-kill (buffer)
  (alexandria:when-let* ((server (buffer-server buffer))
                         (handler (server-handler server)))
    (trivial-ws:stop handler)))

(define-command markdown-preview () ()
  "Render the markdown of the current buffer to a browser window. The preview is refreshed when the file is saved.

The connection is closed when the file is closed."
  (generate-html-and-preview (current-buffer)))
