;;; window-purpose-configuration.el --- Configuration handling for Purpose -*- lexical-binding: t -*-

;; Copyright (C) 2015 Bar Magal

;; Author: Bar Magal (2015)
;; Package: purpose

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;; This file contains the "purpose configuration". The "purpose
;; configuration" is a set of variables that define what is the purpose
;; of each buffer.
;; The configuration is built from 3 layers: the user's config,
;; extensions' config (also called "extended config") and the default
;; config.
;; Each layer of configuration has 3 parameters for determining a
;; buffer's purpose: mode, name and regexp.
;; mode: matches a buffer's major mode
;; name: matches a buffer's name exactly
;; regexp: matches a buffer's name
;;
;; Each layer has 2 sets of variables: non-compiled variables, which are
;; easy to modify, and compiled variables which are used internally when
;; getting a buffer's purpose.
;;
;; Extensions that use Purpose and need to define a configuration,
;; should do so by using `purpose-conf' objects and the functions
;; `purpose-set-extension-configuration' and
;; `purpose-del-extension-configuration'.
;;
;; Users that want to set their own configuration, should do so by
;; customizing `purpose-user-mode-purposes',
;; `purpose-user-name-purposes' and `purpose-user-regexp-purposes'. If a
;; user changes any of these variables outside of customize, the user
;; should call `purpose-compile-user-configuration' for the changes to
;; take effect.
;; It is possible to use or ignore the default configuration by
;; customizing `purpose-use-default-configuration'.

;;; Code:

(require 'cl-lib)
(require 'eieio)
(require 'window-purpose-utils)

;;; Types

;; `purpose-conf' is not an autoload because there is a bug in autoloading
;; `defclass' in Emacs 24.3. (no problem with Emacs 24.4)
;; If we decide to drop support for Emacs 24.3, we can make `purpose-conf' an
;; autoload again.
(defclass purpose-conf ()
  ((mode-purposes :initarg :mode-purposes
                  :initform '()
                  :type purpose-mode-alist)
   (name-purposes :initarg :name-purposes
                  :initform '()
                  :type purpose-name-alist)
   (regexp-purposes :initarg :regexp-purposes
                    :initform '()
                    :type purpose-regexp-alist)))

(defmacro define-purpose-list-checker (name entry-pred)
  "Create a function named NAME to check the content of a list.
The generated function receives parameter OBJ, and checks that it is a
list and each entry in it satisifies ENTRY-PRED."
  `(defun ,name (obj)
     "Check that OBJ is a list, and each entry in it satisifies ,entry-pred."
     (and (listp obj)
          (cl-loop for entry in obj
                   always (funcall ,entry-pred entry)))))

(defun purpose-non-nil-symbol-p (obj)
  "Check that OBJ is a symbol and not nil."
  (and (symbolp obj) obj))

(defun purpose-mode-alist-entry-p (obj)
  "Check that OBJ is a pair of mode and purpose.
OBJ should be a cons cell, whose car and cdr are both
`purpose-non-nil-symbol-p'."
  (and (consp obj)
       (purpose-non-nil-symbol-p (car obj))
       (purpose-non-nil-symbol-p (cdr obj))))

(defun purpose-name-alist-entry-p (obj)
  "Check that OBJ is a pair of name and purpose.
OBJ should be a cons cell, whose car is a string and cdr is a
`purpose-non-nil-symbol-p'."
  (and (consp obj)
       (stringp (car obj))
       (purpose-non-nil-symbol-p (cdr obj))))

(defalias 'purpose-regexp-alist-entry-p #'purpose-name-alist-entry-p
  "Check that OBJ is a pair of regexp and purpose.
OBJ should be a cons cell, whose car is a string and cdr is a
`purpose-non-nil-symbol-p'.  Strictly speaking,
`purpose-regexp-alist-entry-p' doesn't actually check that the car is a
valid regexp.")

(define-purpose-list-checker purpose-mode-alist-p
  #'purpose-mode-alist-entry-p)

(define-purpose-list-checker purpose-name-alist-p
  #'purpose-name-alist-entry-p)

(define-purpose-list-checker purpose-regexp-alist-p
  #'purpose-regexp-alist-entry-p)



;;; Variables

(defcustom purpose-use-default-configuration t
  "Determine if the default configuration should be used.
If this is nil, the default configuration is ignored when getting the
purpose of a buffer.  The user configuration and extended configuration
are used anyway."
  :group 'purpose
  :type 'boolean
  :package-version "1.2")

(defcustom purpose-user-mode-purposes nil
  "User configured alist mapping of modes to purposes.
The alist should match `purpose-mode-alist-p'.
If you set this variable in elisp-code, you should call the function
`purpose-compile-user-configuration' immediately afterwards."
  :group 'purpose
  :type '(alist :key-type (symbol :tag "major mode")
                :value-type (symbol :tag "purpose"))
  :set #'(lambda (symbol value)
           (prog1 (set-default symbol value)
             (purpose-compile-user-configuration)))
  :initialize 'custom-initialize-default
  :package-version "1.2")

(defcustom purpose-user-name-purposes nil
  "User configured alist mapping of names to purposes.
The alist should match `purpose-name-alist-p'.
If you set this variable in elisp-code, you should call the function
`purpose-compile-user-configuration' immediately afterwards."
  :group 'purpose
  :type '(alist :key-type (string :tag "name")
                :value-type (symbol :tag "purpose"))
  :set #'(lambda (symbol value)
           (prog1 (set-default symbol value)
             (purpose-compile-user-configuration)))
  :initialize 'custom-initialize-default
  :package-version "1.2")

(defcustom purpose-user-regexp-purposes nil
  "User configured alist mapping of regexps to purposes.
The alist should match `purpose-regexp-alist-p'.
If you set this variable in elisp-code, you should call the function
`purpose-compile-user-configuration' immediately afterwards."
  :group 'purpose
  :type '(alist :key-type (string :tag "regexp")
                :value-type (symbol :tag "purpose"))
  :set #'(lambda (symbol value)
           (prog1 (set-default symbol value)
             (purpose-compile-user-configuration)))
  :initialize 'custom-initialize-default
  :package-version "1.2")

(defvar purpose-extended-configuration nil
  "A plist containing `purpose-conf' objects.
An example of `purpose-extended-configuration':
 (list :python (purpose-conf
                :mode-purposes '((python-mode . python)
                                (python-inferior-mode . interpreter)))
       :popups (purpose-conf
                :mode-purposes '((help-mode . right)
                                 (occur-mode . bottom)
                                 (grep-mode . bottom))))")

;;; Compiled variables

(defvar purpose--user-mode-purposes (make-hash-table)
  "The compiled user mapping of modes to purposes.
The contents of this variable are generated by
`purpose-compile-user-configuration'.")

(defvar purpose--user-name-purposes (make-hash-table :test #'equal)
  "The compiled user mapping of names to purposes.
The contents of this variable are generated by
`purpose-compile-user-configuration'.")

(defvar purpose--user-regexp-purposes (make-hash-table :test #'equal)
  "The compiled user mapping of regexps to purposes.
The contents of this variable are generated by
`purpose-compile-user-configuration'.")

(defvar purpose--extended-mode-purposes (make-hash-table)
  "The combined mapping of modes to purposes, of all extensions.
The contents of this variable are generated by
`purpose-compile-extended-configuration'.")

(defvar purpose--extended-name-purposes (make-hash-table :test #'equal)
  "The combined mapping of names to purposes, of all extensions.
The contents of this variable are generated by
`purpose-compile-extended-configuration'.")

(defvar purpose--extended-regexp-purposes (make-hash-table :test #'equal)
  "The combined mapping of regexps to purposes, of all extensions.
The contents of this variable are generated by
`purpose-compile-extended-configuration'.")

(defvar purpose--default-mode-purposes (make-hash-table)
  "The default mapping of modes to purposes.
The contents of this variable are generated by
`purpose-compile-default-configuration'.")

(defvar purpose--default-name-purposes (make-hash-table :test #'equal)
  "The default mapping of names to purposes.
The contents of this variable are generated by
`purpose-compile-default-configuration'.")

(defvar purpose--default-regexp-purposes (make-hash-table :test #'equal)
  "The default mapping of regexps to purposes.
The contents of this variable are generated by
`purpose-compile-default-configuration'.")



;;; Configuration compiler functions

(defun purpose--fill-hash (table alist &optional dont-clear)
  "Fill hash table TABLE with ALIST's entries.
TABLE is cleared before filling it, unless DONT-CLEAR is non-nil."
  (unless dont-clear
    (clrhash table))
  (mapc #'(lambda (entry)
            (puthash (car entry) (cdr entry) table))
        alist))

(defun purpose--set-and-compile-configuration (symbol value)
  "Set SYMBOL's value to VALUE and recompile user configuration.
Recompilation is done by calling `purpose-compile-user-configuration'."
  (prog1
      (set-default symbol value)
    (purpose-compile-user-configuration)))

(defun purpose-compile-user-configuration ()
  "Compile the purpose configuration of the user.
Fill `purpose--user-mode-purposes', `purpose--user-name-purposes' and
`purpose--user-regexp-purposes' according to
`purpose-user-mode-purposes', `purpose-user-name-purposes' and
`purpose-user-regexp-purposes'."
  (purpose--fill-hash purpose--user-mode-purposes purpose-user-mode-purposes)
  (purpose--fill-hash purpose--user-name-purposes purpose-user-name-purposes)
  (purpose--fill-hash purpose--user-regexp-purposes
                      purpose-user-regexp-purposes))

(defun purpose-compile-extended-configuration ()
  "Compile the purpose configuration of extensions.
Fill `purpose--extended-mode-purposes',
`purpose--extended-name-purposes' and
`purpose--extended-regexp-purposes' according to
`purpose-extended-configuration'."
  ;; clear compiled purposes
  (purpose--fill-hash purpose--extended-mode-purposes nil)
  (purpose--fill-hash purpose--extended-name-purposes nil)
  (purpose--fill-hash purpose--extended-regexp-purposes nil)

  ;; populate compiled purposes
  (mapc #'(lambda (extension-config)
            (purpose--fill-hash purpose--extended-mode-purposes
                                (oref extension-config :mode-purposes)
                                t)
            (purpose--fill-hash purpose--extended-name-purposes
                                (oref extension-config :name-purposes)
                                t)
            (purpose--fill-hash purpose--extended-regexp-purposes
                                (oref extension-config :regexp-purposes)
                                t))
        (delq nil (purpose-plist-values purpose-extended-configuration))))

(defun purpose-compile-default-configuration ()
  "Compile the default purpose configuraion."

  (purpose--fill-hash purpose--default-mode-purposes
                      '((prog-mode . edit)
                        (text-mode . edit)
                        (comint-mode . terminal)
                        (dired-mode . dired)
                        (ibuffer-mode . buffers)
                        (Buffer-menu-mode . buffers)
                        (occur-mode . search)
                        (grep-mode . search)
                        (compilation-mode . search)
                        (image-mode . image)
                        (package-menu-mode . package)))

  (purpose--fill-hash purpose--default-name-purposes
                      '((".gitignore" . edit)
                        (".hgignore" . edit)
                        ;; the `shell' command displays its buffer before
                        ;; setting its major-mode, so we must detect it by name
                        ("*shell*" . terminal)))

  (purpose--fill-hash purpose--default-regexp-purposes
                      '(("^ \\*Minibuf-[0-9]*\\*$" . minibuf))))



;;; API functions for extensions

;;;###autoload
(defun purpose-set-extension-configuration (keyword config)
  "Set an extension's entry in `purpose-extended-configuration'.
KEYWORD should be a keyword used to identify the extension.
CONFIG is a `purpose-conf' object containing the extension's purpose
configuration.
Example:
 (purpose-set-extension-configuration
     :python
     (purpose-conf :mode-purposes
                   '((python-mode . python)
                     (python-inferior-mode . interpreter))))

This function calls `purpose-compile-extended-configuration' when its
done."
  (unless (keywordp keyword)
    (signal 'wrong-type-argument `(keywordp ,keyword)))
  (setq purpose-extended-configuration
        (plist-put purpose-extended-configuration keyword config))
  (purpose-compile-extended-configuration))

(defun purpose-del-extension-configuration (keyword)
  "Delete an extension's entry in `purpose-extended-configuration'.
KEYWORD is the same as in `purpose-set-extension-configuration'.
Deletion is actually done by setting the extension's entry to nil.
This function calls `purpose-compile-extended-configuration' when its
done."
  (purpose-set-extension-configuration keyword nil))



;;; Initial compilation

(purpose-compile-user-configuration)
(purpose-compile-extended-configuration)
(purpose-compile-default-configuration)


(provide 'window-purpose-configuration)

;;; window-purpose-configuration.el ends here
