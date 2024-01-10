#+ros.installing
(uiop:with-current-directory ((uiop:pathname-directory-pathname *load-truename*))
  (unless (uiop:directory-exists-p (merge-pathnames #P".qlot/"))
    (setf (uiop:getenv "SBCL_HOME") "")
    (uiop:run-program '("qlot" "install" "--no-deps")
                      :output t
                      :error-output t))
  #+quicklisp
  (setf ql:*quicklisp-home* (merge-pathnames #P".qlot/"))
  (let ((local-project-dir (or roswell:*local-project-directories*
                               #+quicklisp (copy-list ql:*local-project-directories*))))
    (load (merge-pathnames #P".qlot/setup.lisp"))
    ;; XXX: Not to modify the local project directories to install ros scripts in ~/.roswell/bin
    ;;   ref. https://github.com/roswell/roswell/blob/5b267381a66d36a514e2eee7283543f828541a63/lisp/util-install-quicklisp.lisp#L146
    (set (intern (string :*local-project-directories*) :ql) local-project-dir)))

(defsystem "lem"
  :version "2.1.0"
  :depends-on ("alexandria"
               "trivial-gray-streams"
               "trivial-types"
               "cl-ppcre"
               "micros"
               "inquisitor"
               "babel"
               "bordeaux-threads"
               "yason"
               "log4cl"
               "split-sequence"
               "str"
               "dexador"
               "lem-base"
               "lem-encodings"
	       #+sbcl
	       sb-concurrency
	       "lem-mailbox"
               #+ip-management
	       "ip-management")
  :pathname "src"
  :serial t
  :components ((:module "common"
                :components ((:file "ring")
                             (:file "killring")
                             (:file "history")
                             (:file "timer")
                             (:file "command")
                             (:file "color")
                             (:file "queue")))
               (:file "internal-packages")
               (:file "quicklisp-utils")
               (:file "version")
               (:file "config")
               (:file "errors")
               (:file "system")
               (:file "key")
               (:file "macros")
               (:file "attribute")
               (:file "clipboard")
               (:file "killring")
               (:file "file")
               (:file "frame")
               (:file "echo")
               (:file "prompt")
               (:module "window"
                :serial t
                :components ((:file "window-tree")
                             (:file "window")
                             (:file "virtual-line")
                             (:file "floating-window")
                             (:file "header-window")
                             (:file "side-window")))
               (:file "popup")
               (:file "modeline")
               (:file "command")
               (:file "defcommand")
               (:file "mode")
               (:file "keymap")
               (:file "event-queue")
               (:file "interp")
               (:file "mouse")
               (:file "context-menu")
               (:file "input")
               (:file "overlay")
               (:file "streams")
               (:file "fundamental-mode")
               (:file "completion")
               (:file "typeout")
               (:file "cursors")
               (:file "command-advices")
               (:file "interface")
               (:file "highlight-line")
               (:file "site-init")
               (:file "lem")

               (:file "color-theme")

               (:module "commands"
                :serial t
                :components ((:file "move")
                             (:file "edit" :depends-on ("move"))
                             (:file "mark")
                             (:file "word" :depends-on ("edit"))
                             (:file "s-expression" :depends-on ("edit"))
                             (:file "file" :depends-on ("edit"))
                             (:file "project" :depends-on ("file"))
                             (:file "buffer")
                             (:file "window" :depends-on ("move"))
                             (:file "multiple-cursors")
                             (:file "process")
                             (:file "help")
                             (:file "font")
                             (:file "other" :depends-on ("file"))
                             (:file "frame")))

               (:module "display"
                :serial t
                :components ((:file "base")
                             (:file "char-type")
                             (:file "logical-line")
                             (:file "physical-line")))

               (:file "external-packages")

               (:module "ext"
                :serial t
                :components ((:file "popup-window")
                             (:file "popup-message")
                             (:file "popup-menu")
                             (:file "markdown-buffer")
                             (:file "multi-column-list")
                             (:file "context-menu")
                             (:file "list-buffers")
                             (:file "completion-mode")
                             (:file "prompt-window")
                             (:file "tmlanguage")
                             (:file "button")
                             (:file "loading-spinner")
                             (:file "listener-mode")
                             (:file "universal-argument")
                             (:file "kbdmacro")
                             (:file "isearch")
                             (:file "showparen")
                             (:file "line-numbers")
                             (:file "peek-source")
                             (:file "grep")
                             (:file "go-back")
                             (:file "hover")
                             (:file "language-mode")
                             (:file "language-mode-tools")
                             (:file "link")
                             (:file "thingatp")
                             (:file "gtags")
                             (:file "directory-mode")
                             (:file "abbrev")
                             (:file "rectangle")
                             (:file "auto-save")
                             (:file "tabbar")
                             (:file "frame-multiplexer")
                             (:file "filer")
                             (:file "deepl")
                             (:file "themes")
                             (:file "detective")
                             #+ip-management
			     (:file "run-process")))))

(defsystem "lem/extensions"
  :depends-on (#+sbcl
               "lem-lsp-mode"
               "lem-vi-mode"
               #+sbcl
               "lem-lisp-mode"
               #+sbcl
               "lem-go-mode"
               "lem-swift-mode"

               "lem-c-mode"
               "lem-xml-mode"
               "lem-html-mode"
               "lem-python-mode"
               "lem-posix-shell-mode"
               "lem-markdown-mode"
               "lem-js-mode"
               "lem-json-mode"
               "lem-css-mode"
               "lem-rust-mode"
               "lem-paredit-mode"
               "lem-nim-mode"
               #-clasp
               "lem-scheme-mode"

               "lem-patch-mode"
               "lem-yaml-mode"
               "lem-review-mode"
               "lem-asciidoc-mode"
               "lem-dart-mode"
               "lem-scala-mode"
               "lem-dot-mode"
               "lem-java-mode"
               "lem-haskell-mode"
               "lem-ocaml-mode"
               "lem-asm-mode"
               "lem-makefile-mode"
               "lem-shell-mode"
               "lem-sql-mode"
               "lem-base16-themes"
               #+sbcl
               "lem-elixir-mode"
               "lem-documentation-mode"
               "lem-elisp-mode"))

(defsystem "lem/legit"
  :serial t
  :depends-on ("lem")
  :components ((:module "extensions/legit"
                :components ((:file "porcelain")
                             (:file "peek-legit")
                             (:file "legit")
                             (:file "legit-rebase")
                             (:file "legit-commit")))
               (:module "scripts"
                :components ((:static-file "dumbrebaseeditor.sh")))))

(defsystem "lem/executable"
  :build-operation program-op
  :build-pathname "lem"
  :entry-point "lem:main"
  :depends-on ("lem-ncurses"))
