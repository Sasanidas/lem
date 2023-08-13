(defpackage :lem-lisp-mode/internal
  (:use :cl
        :lem
        :lem/completion-mode
        :lem/language-mode
        :lem/button
        :lem/loading-spinner
        :lem-lisp-mode/errors
        :lem-lisp-mode/swank-protocol
        :lem-lisp-mode/connections
        :lem-lisp-mode/message-dispatcher
        :lem-lisp-mode/ui-mode
        :lem-lisp-mode/grammer)
  (:export
   ;; reexport swank-protocol.lisp
   :connection-value)
  (:export
   ;; lisp-ui-mode.lisp
   :*lisp-ui-keymap*
   :lisp-ui-default-action
   :lisp-ui-forward-button
   ;; file-conversion.lisp
   :*file-conversion-map*
   ;; lisp-mode.lisp
   :lisp-mode
   :load-file-functions
   :before-compile-functions
   :before-eval-functions
   :*default-port*
   :*localhost*
   :*lisp-mode-keymap*
   :*lisp-mode-hook*
   :self-connected-p
   :self-connected-port
   :self-connect
   :check-connection
   :*current-package*
   :buffer-package
   :current-package
   :buffer-thread-id
   :with-remote-eval
   :lisp-eval-from-string
   :lisp-eval
   :lisp-eval-async
   :eval-with-transcript
   :re-eval-defvar
   :interactive-eval
   :eval-print
   :lisp-beginning-of-defun
   :lisp-end-of-defun
   :insert-\(\)
   :move-over-\)
   :lisp-indent-sexp
   :lisp-set-package
   :prompt-for-sexp
   :lisp-eval-string
   :lisp-eval-last-expression
   :lisp-eval-defun
   :lisp-eval-region
   :lisp-load-file
   :lisp-remove-notes
   :lisp-compile-and-load-file
   :lisp-compile-region
   :lisp-compile-defun
   :lisp-macroexpand
   :lisp-macroexpand-all
   :prompt-for-symbol-name
   :show-description
   :lisp-eval-describe
   :lisp-describe-symbol
   :connect-to-swank
   :slime-connect
   :show-source-location
   :source-location-to-xref-location
   :get-lisp-command
   :run-slime
   :slime
   :slime-quit
   :slime-restart
   :slime-self-connect
   ;; repl.lisp
   :*lisp-repl-mode-keymap*
   :*lisp-repl-mode-hook*
   :open-inspector-by-repl
   :lisp-repl-interrupt
   :repl-buffer
   :clear-repl
   :get-repl-window
   :*repl-compiler-check*
   :listener-eval
   :start-lisp-repl
   :lisp-switch-to-repl-buffer
   :write-string-to-repl
   :copy-down-to-repl
   ;; apropos-mode.lisp
   :apropos-headline-attribute
   :*lisp-apropos-mode-keymap*
   :lisp-apropos
   :lisp-apropos-all
   :lisp-apropos-package
   ;; message.lisp
   :display-message
   ;;
   :self-connection
   :self-connection-p
   :*find-definitions*
   :switch-connection
   :connection
   :current-connection))
