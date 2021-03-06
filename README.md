# Purpose

[![MELPA](http://melpa.org/packages/window-purpose-badge.svg)](http://melpa.org/#/window-purpose)
[![MELPA Stable](http://stable.melpa.org/packages/window-purpose-badge.svg)](http://stable.melpa.org/#/window-purpose)
[![Build Status](https://travis-ci.org/bmag/emacs-purpose.svg?branch=master)](https://travis-ci.org/bmag/emacs-purpose)
[![Coverage Status](https://coveralls.io/repos/bmag/emacs-purpose/badge.svg?branch=master)](https://coveralls.io/r/bmag/emacs-purpose?branch=master)

## Notices
**A full explanation can be found in the [GitHub wiki](https://github.com/bmag/emacs-purpose/wiki).**

Plans for the near future:

- Improve popup-windows extension to automatically close popup window

- Add extension for combining Purpose and [perspective](https://github.com/nex3/perspective-el)

- Update Wiki

- Maybe add some more tests

Recent changes:

- Option `purpose-preferred-prompt`: choose IDO or Helm

- Command `purpose-switch-buffer-with-some-purpose`: open a buffer with a
  specific purpose

- Update tests and test framework

- New extension for popup-windows (popwin emulation): enable with
  command `purpose-x-popwin-setup`

## Introduction

Purpose ("window-purpose" on MELPA) provides a new window management system for
Emacs, which gives you a better control over where Emacs displays buffers.

With Purpose, each buffer has a configurable "purpose" and each window
can interactivaly be dedicated to a certain "purpose". When you dedicate
a window (`C-c , d`), Purpose makes sure that this window will be used
only for buffers which have the same purpose as the buffer that is
currently displayed in that window. The purpose of a buffer can be
customized via the variables `purpose-user-mode-purposes`,
`purpose-user-name-purposes`, `purpose-user-regexp-purposes` and
`purpose-use-default-configuration` (see the
[wiki](https://github.com/bmag/emacs-purpose/wiki/Purpose-Configuration)).

### Supported Emacs Versions
Purpose is tested with Emacs versions 24.3, 24.4 and 24.5. Backward-compatibility for earlier versions might be added in the future - if you want such support, contact me.

## Quickstart

### Activate Purpose
Manually: `M-x purpose-mode`

In your init file:
```elisp
(require 'window-purpose)
(purpose-mode)
```

### Configure Purpose
Manually: `M-x customize-group purpose`. Look at:
- "Purpose User Mode Purposes": recognize purpose according to major mode
- "Purpose User Name Purposes": recognize purpose according to buffer
  name (for exact names)
- "Purpose User Regexp Purposes": recognize purpose according to buffer
  name (for name patterns)
- "Purpose Use Default Configuration": toggle default configuration
  on/off

In init file:
```elisp
(add-to-list 'purpose-user-mode-purposes '(<major-mode> . <purpose>))
(add-to-list 'purpose-user-name-purposes '(<name> . <purpose>))
(add-to-list 'purpose-user-regexp-purposes '(<pattern> . <purpose>))
(setq purpose-use-default-configuration t) ; not really necessary, default is t
(purpose-compile-user-configuration) ; activates your changes
```

### Useful Commands
| Key         | Command                                                                                                                   |
| :---------- | :------------------------------------------------------------------------------------------------------------------------ |
| `C-c , b`   | `purpose-switch-buffer-with-purpose`: switch to a buffer with the same purpose as the current one                         |
| `C-u C-x b` | `switch-buffer-without-purpose`: switch to a buffer, but don't use Purpose for it. Handy for changing the current layout. |
| `C-c , d`   | `purpose-toggle-window-purpose-dedicated`                                                                                 |
| `C-c , D`   | `purpose-toggle-window-buffer-dedicated`                                                                                  |
| `C-c , 1`   | `purpose-delete-non-dedicated-windows`                                                                                    |
|             | `purpose-save-window-layout`: save current layout to file                                                                 |
|             | `purpose-load-window-layout`: load layout from file                                                                       |
|             | `purpose-reset-window-layout`: reload previously loaded layout                                                            |

### Example: Simple Python Layout
How to get a simple and persistent layout for coding in Python that
looks like this:

![simple python layout](https://github.com/bmag/emacs-purpose/blob/master/images/simple-python-layout.png)

#### step 1: configuration
```elisp
(add-to-list 'purpose-user-mode-purposes '(python-mode . py))
(add-to-list 'purpose-user-mode-purposes '(inferior-python-mode . py-repl))
(purpose-compile-user-configuration)
```

#### step 2: change window layout
If you have a previously saved layout, you can load it with
`purpose-load-window-layout` and skip step 2 and step 3.

1. open a Python file
2. `C-c , d` (`purpose-toggle-window-purpose-dedicated`) so window is
   dedicated ("[py]" in the status bar will change to "[py!]")
3. `C-x 1` (`delete-other-windows`)
4. `C-x 2` (`split-window-below`)
5. `C-c C-z` (`python-shell-switch-to-shell`)
6. `C-c , d` so window is dedicated
7. `C-x o` (`other-window`) to select the python file's window
8. `C-x ^` (`enlarge-window`) until you like the sizes of the windows

#### step 3: save window layout
`M-x purpose-save-window-layout`

## Using Purpose

### Dedicating windows
Dedicating a window limits which buffers will be displayed in it. There are two
types of window dedication: buffer-dedication and purpose-dedication.

Use `purpose-toggle-window-buffer-dedicated` to dedicate a window to its buffer.
This window will not display any other buffer while it is buffer-dedicated. A
"#" in the mode-line next to the window's purpose indicates that the window is
buffer-dedicated.

Use `purpose-toggle-window-purpose-dedicated` to dedicate a window to its
purpose. This window will only display buffers with the same purpose. A "!" in
the mode-line next to the window's purpose indicates that the window is
purpose-dedicated.

### Switching buffers
When switching buffers, Purpose will display the new buffer in the correct
window, according to the current configuration.

Use `switch-to-buffer` to switch to any buffer. The buffer will be displayed
according to the current purpose-configuration.

Use `purpose-switch-buffer-with-purpose` to switch to another buffer with the
same purpose as the current buffer.

Use `purpose-switch-buffer-with-some-purpose` to select a purpose and then
switch to a buffer with that purpose.

Use `switch-buffer-without-purpose` to switch to any buffer. The buffer will be
displayed using Emacs' original behavior. This is useful when you want to change
the window layout.

Use `purpose-set-window-purpose` to switch the purpose of the current window. If
there is a buffer with the chosen purpose, that buffer will be displayed in the
current window. Otherwise, a dummy buffer will be created and used.

### Changing layout
Purpose lets you save, load and reset the window layout.

Use `purpose-save-window-layout` to save the current window layout to a file.

Use `purpose-load-window-layout` to load a window layout from a file.

Use `purpose-reset-window-layout` to reset the window layout to the latest
layout that you loaded.

You may want to store all your layouts in a directory, and change the value of
`purpose-default-layout-file` to point to that directory.

You can delete all non-dedicated windows by using
`purpose-delete-non-dedicated-windows`. 

## Customizing Purpose

### Prompts
With `purpose-preferred-prompt`, you can choose whether you want Purpose to use
IDO or Helm when it needs information from the user. By default, when both IDO
and Helm are enabled, Purpose prefers IDO.

### Changing purpose configuration
Purpose lets you define your own purposes. You can do so by using the variables
`purpose-user-mode-purposes`, `purpose-user-name-purposes` and
`purpose-user-regexp-purposes`. You can also deactivate the default purpose
configuration if it bothers you, by setting `purpose-use-default-configuration`
to nil.

### Changing display rules
If you want, you can the rules of how certain buffers are displayed. To do so,
use the variable `purpose-special-action-sequences`. Let's explain this with an
example. The following code makes all help buffers appear in a separate
frame. This means you will get a "popup" frame for help buffers.

```elisp
(setq pop-up-frames t) ; allows emacs to popup new frames
;; give help buffers the 'popup-frame purpose
(add-to-list 'purpose-user-mode-purposes
             '(help-mode . popup-frame))
(purpose-compile-user-configuration)
;; new rules for buffers with the 'popup-frame purpose
(add-to-list 'purpose-special-action-sequences
             '(popup-frame
               purpose-display-reuse-window-buffer
               purpose-display-reuse-window-purpose
               purpose-display-pop-up-frame))
```

## Using Purpose with other packages
See [Integration With Other Packages](https://github.com/bmag/emacs-purpose/wiki/Integration-With-Other-Packages)
for information about how some packages relate to Purpose.
