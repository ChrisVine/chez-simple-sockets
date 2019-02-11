#!/usr/bin/env scheme-script

;; Copyright (C) 2018 Chris Vine
;; 
;; This file is licensed under the Apache License, Version 2.0 (the
;; "License"); you may not use this file except in compliance with the
;; License.  You may obtain a copy of the License at
;;
;; http://www.apache.org/licenses/LICENSE-2.0
;;
;; Unless required by applicable law or agreed to in writing, software
;; distributed under the License is distributed on an "AS IS" BASIS,
;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
;; implied.  See the License for the specific language governing
;; permissions and limitations under the License.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; This is an example file for using synchronous (blocking) reads and
;; writes on sockets.  It will provide the caller's IPv4 internet
;; address from checkip.dyndns.com.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(import (simple-sockets basic)
	(chezscheme))

(define check-ip "checkip.dyndns.com")

(define (read-response sockport)
  (let lp ([header-done #f]
	   [header ""]
	   [body ""]
	   [line (get-line sockport)])
    (cond
     [(eof-object? line)
      (values header body)]
     [header-done ;; a line of the body received
      (lp #t
	  header
	  (if (string=? body "")
	      line
	      (string-append body "\n" line))
	  (get-line sockport))]
     [(string=? line "") ;; end of header
      (lp #t
	  header
	  ""
	  (get-line sockport))]
     [else ;; a line of the header received
      (lp #f
	  (if (string=? header "")
	      line
	      (string-append header "\n" line))
	  ""
	  (get-line sockport))])))
	  
(define (send-get-request host path sockport)
  (write-string sockport
		(string-append "GET " path " HTTP/1.1\nHost: " host "\nConnection: close\n\n")))

(define (make-sockport codec socket)
  ;; we can construct a port for input only as write-string does not
  ;; use the port's output buffers
  (open-fd-input-port socket (buffer-mode block)
		      (make-transcoder codec 'crlf)))

(set-ignore-sigpipe)

(let ([sockport (make-sockport (utf-8-codec)
			       (connect-to-ipv4-host check-ip "http" 0))])
  (send-get-request check-ip "/" sockport)
  (let-values ([(header body) (read-response sockport)])
    (display body)
    (newline))
  (close-port sockport))
