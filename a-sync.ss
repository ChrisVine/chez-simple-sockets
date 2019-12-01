;; Copyright (C) 2016 and 2018 Chris Vine
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

#!r6rs

(library (simple-sockets a-sync)
  (export
   await-connect-to-ipv4-host!
   await-connect-to-ipv6-host!
   await-connect-to-unix-host!
   await-accept-ipv4-connection!
   await-accept-ipv6-connection!
   await-accept-unix-connection!)
  (import 
   (a-sync event-loop)
   (except (simple-sockets basic) connect-condition? listen-condition? accept-condition?)
   (chezscheme))


(include "common.ss")

(define check-sock-error(foreign-procedure "ss_check_sock_error"
					   (int)
					   int))

;; This will connect asynchronously to a remote IPv4 host.  If 'port'
;; is greater than 0, it is set as the port to which the connection
;; will be made, otherwise this is deduced from the 'service'
;; argument, which should be a string such as "html".  The 'service'
;; argument may be #f, in which case a port number greater than 0 must
;; be given.
;;
;; The 'address' argument should be a string which may be either the
;; domain name of the server to which a connection is to be made or a
;; dotted decimal address.
;;
;; The event loop will not be blocked by this procedure even if the
;; connection is not immediately available, provided that the C
;; getaddrinfo() function does not block.  In addition this procedure
;; only attempts to connect to the first address the resolver offers
;; to it.  These are important provisos which mean that this procedure
;; should only be used where 'address' has a single network address
;; which can be looked up from a local file such as /etc/host, or it
;; is a string in IPv4 dotted decimal format.  Otherwise call
;; connect-to-ipv4-host via await-task-in-thread!,
;; await-task-in-event-loop! or await-task-in-thread-pool!.
;;
;; This procedure is intended to be called in a waitable procedure
;; invoked by a-sync. The 'loop' argument is optional: this procedure
;; operates on the event loop passed in as an argument, or if none is
;; passed (or #f is passed), on the default event loop.
;;
;; A &connect-condition exception will be raised if the connection
;; attempt fails; applying connect-condition? to the raised condition
;; object will return #t.
;;
;; On success, this procedure returns the file descriptor of a
;; connection socket.  The file descriptor will be set non-blocking.
(define await-connect-to-ipv4-host!
  (case-lambda
    [(await resume address service port)
     (await-connect-to-ipv4-host! await resume #f address service port)]
    [(await resume loop address service port)
     (let ([sock (connect-to-ipv4-host-impl address service port #f)])
       (if (>= sock 0)
	   (begin
	     (event-loop-add-write-watch! sock
					  (lambda (status)
					    (resume)
					    #t)
					  loop)
	     (await)
	     (event-loop-remove-write-watch! sock loop)
	     (if (= 0 (check-sock-error sock))
		 sock
		 (check-raise-connect-exception -3 address)))
	   (check-raise-connect-exception sock address)))]))

;; This will connect asynchronously to a remote IPv6 host.  If 'port'
;; is greater than 0, it is set as the port to which the connection
;; will be made, otherwise this is deduced from the 'service'
;; argument, which should be a string such as "html".  The 'service'
;; argument may be #f, in which case a port number greater than 0 must
;; be given.
;;
;; The 'address' argument should be a string which may be either the
;; domain name of the server to which a connection is to be made or a
;; colonned IPv6 hex address.
;;
;; The event loop will not be blocked by this procedure even if the
;; connection is not immediately available, provided that the C
;; getaddrinfo() function does not block.  In addition this procedure
;; only attempts to connect to the first address the resolver offers
;; to it.  These are important provisos which mean that this procedure
;; should only be used where 'address' has a single network address
;; which can be looked up from a local file such as /etc/host, or it
;; is a string in IPv6 hex format.  Otherwise call
;; connect-to-ipv6-host via await-task-in-thread!,
;; await-task-in-event-loop! or await-task-in-thread-pool!.
;;
;; This procedure is intended to be called in a waitable procedure
;; invoked by a-sync. The 'loop' argument is optional: this procedure
;; operates on the event loop passed in as an argument, or if none is
;; passed (or #f is passed), on the default event loop.
;;
;; A &connect-condition exception will be raised if the connection
;; attempt fails; applying connect-condition? to the raised condition
;; object will return #t.
;;
;; On success, this procedure returns the file descriptor of a
;; connection socket.  The file descriptor will be set non-blocking.
(define await-connect-to-ipv6-host!
  (case-lambda
    [(await resume address service port)
     (await-connect-to-ipv6-host! await resume #f address service port)]
    [(await resume loop address service port)
     (let ([sock (connect-to-ipv6-host-impl address service port #f)])
       (if (>= sock 0)
	   (begin
	     (event-loop-add-write-watch! sock
					  (lambda (status)
					    (resume)
					    #t)
					  loop)
	     (await)
	     (event-loop-remove-write-watch! sock loop)
	     (if (= 0 (check-sock-error sock))
		 sock
		 (check-raise-connect-exception -3 address)))
	   (check-raise-connect-exception sock address)))]))

;; This will connect asynchronously to a unix domain host.
;;
;; The 'pathname' argument should be a string comprising the
;; filesystem name of the unix domain socket.
;;
;; The event loop will not be blocked by this procedure even if the
;; connection is not immediately available.
;;
;; This procedure is intended to be called in a waitable procedure
;; invoked by a-sync. The 'loop' argument is optional: this procedure
;; operates on the event loop passed in as an argument, or if none is
;; passed (or #f is passed), on the default event loop.
;;
;; A &connect-condition exception will be raised if the connection
;; attempt fails; applying connect-condition? to the raised condition
;; object will return #t.
;;
;; On success, this procedure returns the file descriptor of a
;; connection socket.  The file descriptor will be set non-blocking.
(define await-connect-to-unix-host!
  (case-lambda
    [(await resume pathname)
     (await-connect-to-unix-host! await resume #f pathname)]
    [(await resume loop pathname)
     (let ([sock (connect-to-unix-host-impl pathname #f)])
       (if (>= sock 0)
	   (begin
	     (event-loop-add-write-watch! sock
					  (lambda (status)
					    (resume)
					    #t)
					  loop)
	     (await)
	     (event-loop-remove-write-watch! sock loop)
	     (if (= 0 (check-sock-error sock))
		 sock
		 (check-raise-connect-exception -3 pathname)))
	   (check-raise-connect-exception sock pathname)))]))

;; This procedure will accept incoming connections on a listening IPv4
;; socket asynchronously.
;;
;; 'sock' is the file descriptor of the socket on which to accept
;; connections, as returned by listen-on-ipv4-socket.  'connection' is
;; a bytevector of size 4 to be passed to the procedure as an out
;; parameter, in which the binary address of the connecting client
;; will be placed in network byte order, or #f.
;;
;; This procedure will only return when a connection has been
;; accepted.  However, the event loop will not be blocked by this
;; procedure while waiting.  This procedure is intended to be called
;; in a waitable procedure invoked by a-sync. The 'loop' argument is
;; optional: this procedure operates on the event loop passed in as an
;; argument, or if none is passed (or #f is passed), on the default
;; event loop.
;;
;; An &accept-condition exception will be raised if connection
;; attempts fail; applying accept-condition? to the raised condition
;; object will return #t.
;;
;; If 'sock' is not a non-blocking descriptor, it will be made
;; non-blocking by this procedure.
;;
;; On success, this procedure returns the file descriptor for the
;; connection socket.  That file descriptor will be set non-blocking.
;;
;; This procedure will not call 'await' if a connection is immediately
;; available to be accepted without waiting: instead, after accepting
;; the connection this procedure would return straight away without
;; invoking the event loop.
(define await-accept-ipv4-connection!
  (case-lambda
    [(await resume sock connection)
     (await-accept-ipv4-connection! await resume #f sock connection)]
    [(await resume loop sock connection)
     (set-fd-non-blocking sock)
     (let lp ([con-fd (check-raise-accept-exception
		       (accept-ipv4-connection-impl sock connection))])
       (if (eq? con-fd 'eagain)
	   (begin
	     (event-loop-add-read-watch! sock
					 (lambda (status)
					   (resume)
					   #t)
					 loop)
	     (await)
	     (event-loop-remove-read-watch! sock loop)
	     (lp (check-raise-accept-exception
		  (accept-ipv4-connection-impl sock connection))))
	   (begin
	     (set-fd-non-blocking con-fd)
	     con-fd)))]))
       
;; This procedure will accept incoming connections on a listening IPv6
;; socket.
;;
;; 'sock' is the file descriptor of the socket on which to accept
;; connections, as returned by listen-on-ipv6-socket.  'connection' is
;; a bytevector of size 16 to be passed to the procedure as an out
;; parameter, in which the binary address of the connecting client
;; will be placed in network byte order, or #f.
;;
;; This procedure will only return when a connection has been
;; accepted.  However, the event loop will not be blocked by this
;; procedure while waiting.  This procedure is intended to be called
;; in a waitable procedure invoked by a-sync. The 'loop' argument is
;; optional: this procedure operates on the event loop passed in as an
;; argument, or if none is passed (or #f is passed), on the default
;; event loop.
;;
;; An &accept-condition exception will be raised if connection
;; attempts fail; applying accept-condition? to the raised condition
;; object will return #t.
;;
;; If 'sock' is not a non-blocking descriptor, it will be made
;; non-blocking by this procedure.
;;
;; On success, this procedure returns the file descriptor for the
;; connection socket.  That file descriptor will be set non-blocking.
;;
;; This procedure will not call 'await' if a connection is immediately
;; available to be accepted without waiting: instead, after accepting
;; the connection this procedure would return straight away without
;; invoking the event loop.
(define await-accept-ipv6-connection!
  (case-lambda
    [(await resume sock connection)
     (await-accept-ipv6-connection! await resume #f sock connection)]
    [(await resume loop sock connection)
     (set-fd-non-blocking sock)
     (let lp ([con-fd (check-raise-accept-exception
		       (accept-ipv6-connection-impl sock connection))])
       (if (eq? con-fd 'eagain)
	   (begin
	     (event-loop-add-read-watch! sock
					 (lambda (status)
					   (resume)
					   #t)
					 loop)
	     (await)
	     (event-loop-remove-read-watch! sock loop)
	     (lp (check-raise-accept-exception
		  (accept-ipv6-connection-impl sock connection))))
	   (begin
	     (set-fd-non-blocking con-fd)
	     con-fd)))]))

;; This procedure will accept incoming connections on a listening unix
;; domain socket asynchronously.
;;
;; 'sock' is the file descriptor of the socket on which to accept
;; connections, as returned by listen-on-unix-socket.
;;
;; This procedure will only return when a connection has been
;; accepted.  However, the event loop will not be blocked by this
;; procedure while waiting.  This procedure is intended to be called
;; in a waitable procedure invoked by a-sync. The 'loop' argument is
;; optional: this procedure operates on the event loop passed in as an
;; argument, or if none is passed (or #f is passed), on the default
;; event loop.
;;
;; An &accept-condition exception will be raised if connection
;; attempts fail; applying accept-condition? to the raised condition
;; object will return #t.
;;
;; If 'sock' is not a non-blocking descriptor, it will be made
;; non-blocking by this procedure.
;;
;; On success, this procedure returns the file descriptor for the
;; connection socket.  That file descriptor will be set non-blocking.
;;
;; This procedure will not call 'await' if a connection is immediately
;; available to be accepted without waiting: instead, after accepting
;; the connection this procedure would return straight away without
;; invoking the event loop.
(define await-accept-unix-connection!
  (case-lambda
    [(await resume sock)
     (await-accept-unix-connection! await resume #f sock)]
    [(await resume loop sock)
     (set-fd-non-blocking sock)
     (let lp ([con-fd (check-raise-accept-exception
		       (accept-unix-connection-impl sock))])
       (if (eq? con-fd 'eagain)
	   (begin
	     (event-loop-add-read-watch! sock
					 (lambda (status)
					   (resume)
					   #t)
					 loop)
	     (await)
	     (event-loop-remove-read-watch! sock loop)
	     (lp (check-raise-accept-exception
		  (accept-unix-connection-impl sock))))
	   (begin
	     (set-fd-non-blocking con-fd)
	     con-fd)))]))
       
) ;; library


