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

(load-shared-object "libchez-simple-sockets.so")

(library (simple-sockets basic)
  (export
   connect-to-ipv4-host
   connect-to-ipv6-host
   connect-to-unix-host
   listen-on-ipv4-socket
   listen-on-ipv6-socket
   listen-on-unix-socket
   accept-ipv4-connection
   accept-ipv6-connection
   accept-unix-connection
   ipv4-address->string
   ipv6-address->string
   set-fd-non-blocking
   set-fd-blocking
   set-ignore-sigpipe
   connect-condition?
   listen-condition?
   accept-condition?
   shutdown
   close-fd
   write-bytevector
   write-string
   get-errno)
  (import (chezscheme))


(include "common.ss")

;; signature: (set-fd-non-blocking fd)
;;
;; arguments: a file descriptor.  The descriptor will be made
;; non-blocking if it is not already non-blocking, otherwise this
;; procedure does nothing.
;;
;; return value: true if it succeeded (including if it did nothing
;; because the descriptor is already non-blocking), otherwise false.
(define set-fd-non-blocking (foreign-procedure "ss_set_fd_non_blocking"
					       (int)
					       boolean))

;; signature: (set-fd-non-blocking fd)
;;
;; arguments: a file descriptor.  The descriptor will be made blocking
;; if it is not already blocking, otherwise this procedure does
;; nothing.
;;
;; return value: true if it succeeded (including if it did nothing
;; because the descriptor is already blocking), otherwise false.
(define set-fd-blocking (foreign-procedure "ss_set_fd_blocking"
					   (int)
					   boolean))

;; signature: (set-ignore-sigpipe)
;;
;; It is almost always a mistake not to ignore or otherwise deal with
;; SIGPIPE in programs using sockets.  This procedure is a utility
;; which if called will cause SIGPIPE to be ignored: instead any
;; attempt to write to a socket which has been closed at the remote
;; end will cause write/send to return with -1 and errno set to EPIPE.
;; If something other than ignoring the signal is required, use Chez
;; Scheme's register-signal-handler procedure.
;;
;; return value: true if it succeeded, otherwise false.
(define set-ignore-sigpipe (foreign-procedure "ss_set_ignore_sigpipe"
					      ()
					      boolean))

;; This procedure makes a connection to a remote IPv4 host.
;;
;; arguments: if 'port' is greater than 0, it is set as the port to
;; which the connection will be made, otherwise this is deduced from
;; the 'service' argument.  The 'service' argument may be #f, in which
;; case a port number greater than 0 must be given.
;; &connect-exception will be raised if the connection attempt fails,
;; to which applying connect-exception? will return #t.
;;
;; return value: file descriptor of the socket.  The file descriptor
;; will be blocking.
(define (connect-to-ipv4-host address service port)
  (check-raise-connect-exception
   (connect-to-ipv4-host-impl address service port #t)
   address))

;; This procedure makes a connection to a remote IPv6 host.
;;
;; arguments: if 'port' is greater than 0, it is set as the port to
;; which the connection will be made, otherwise this is deduced from
;; the 'service' argument.  The 'service' argument may be #f, in which
;; case a port number greater than 0 must be given.
;; &connect-exception will be raised if the connection attempt fails,
;; to which applying connect-exception? will return #t.
;;
;; return value: file descriptor of the socket.  The file descriptor
;; will be blocking.
(define (connect-to-ipv6-host address service port)
  (check-raise-connect-exception
   (connect-to-ipv6-host-impl address service port #t)
   address))

;; This procedure makes a connection to a unix domain host.
;;
;; arguments: pathname is the filesystem name of the unix domain
;; socket.  &connect-exception will be raised if the connection
;; attempt fails, to which applying connect-exception? will return #t.
;;
;; return value: file descriptor of the socket.  The file descriptor
;; will be blocking.
(define (connect-to-unix-host pathname)
  (check-raise-connect-exception
   (connect-to-unix-host-impl pathname #t)
   pathname))

;; This procedure builds a listening IPv4 socket.
;;
;; arguments: if 'local' is true, the socket will only bind on
;; localhost.  If false, it will bind on any interface. ' port' is the
;; port to listen on.  'backlog' is the maximum number of queueing
;; connections.  &listen-exception will be raised if the making of a
;; listening socket fails, to which applying listen-exception? will
;; return #t.
;;
;; return value: file descriptor of socket.
(define (listen-on-ipv4-socket local port backlog)
  (check-raise-listen-exception
   (listen-on-ipv4-socket-impl local port backlog)
   (if local "localhost" "universal addresses")))

;; This procedure builds a listening IPv6 socket.
;;
;; arguments: if 'local' is true, the socket will only bind on
;; localhost.  If false, it will bind on any interface.  'port' is the
;; port to listen on.  'backlog' is the maximum number of queueing
;; connections.  &listen-exception will be raised if the making of a
;; listening socket fails, to which applying listen-exception? will
;; return #t.
;;
;; return value: file descriptor of socket.
(define (listen-on-ipv6-socket local port backlog)
  (check-raise-listen-exception
   (listen-on-ipv6-socket-impl local port backlog)
   (if local "localhost" "universal addresses")))

;; This procedure builds a listening unix domain socket.
;;
;; arguments: pathname is the filesystem name of the unix domain
;; socket.  'backlog' is the maximum number of queueing connections.
;; &listen-exception will be raised if the making of a listening
;; socket fails, to which applying listen-exception? will return #t.
;;
;; return value: file descriptor of socket.
(define (listen-on-unix-socket pathname backlog)
  (check-raise-listen-exception
   (listen-on-unix-socket-impl pathname backlog)
   pathname))

;; This procedure will accept incoming connections on a listening IPv4
;; socket.  It will block until a connection is made.
;;
;; arguments: sock is the file descriptor of the socket on which to
;; accept connections, as returned by listen-on-ipv4-socket.
;; connection is a bytevector of size 4 to be passed to the procedure
;; as an out parameter, in which the binary address of the connecting
;; client will be placed in network byte order, or #f.
;; &accept-exception will be raised if connection attempts fail, to
;; which applying accept-exception? will return #t.
;;
;; If 'sock' is not a blocking descriptor, it will be made blocking by
;; this procedure.
;;
;; return value: file descriptor for the connection socket.  That file
;; descriptor will be blocking.
(define (accept-ipv4-connection sock connection)
  (set-fd-blocking sock)
  (check-raise-accept-exception
   (accept-ipv4-connection-impl sock connection)))

;; This procedure will accept incoming connections on a listening IPv6
;; socket.  It will block until a connection is made.
;;
;; arguments: sock is the file descriptor of the socket on which to
;; accept connections, as returned by listen-on-ipv6-socket.
;; connection is a bytevector of size 16 to be passed to the procedure
;; as an out parameter, in which the binary address of the connecting
;; client will be placed in network byte order, or #f.
;; &accept-exception will be raised if connection attempts fail, to
;; which applying accept-exception? will return #t.
;;
;; If 'sock' is not a blocking descriptor, it will be made blocking by
;; this procedure.
;;
;; return value: file descriptor for the connection socket.  That file
;; descriptor will be blocking.
(define (accept-ipv6-connection sock connection)
  (set-fd-blocking sock)
  (check-raise-accept-exception
   (accept-ipv6-connection-impl sock connection)))

;; This procedure will accept incoming connections on a listening unix
;; domain socket.  It will block until a connection is made.
;;
;; arguments: sock is the file descriptor of the socket on which to
;; accept connections, as returned by listen-on-unix-socket.
;; &accept-exception will be raised if connection attempts fail, to
;; which applying accept-exception? will return #t.
;;
;; If 'sock' is not a blocking descriptor, it will be made blocking by
;; this procedure.
;;
;; return value: file descriptor for the connection socket.  That file
;; descriptor will be blocking.
(define (accept-unix-connection sock)
  (set-fd-blocking sock)
  (check-raise-accept-exception
   (accept-unix-connection-impl sock)))

;; takes a bytevector of size 4 containing an IPv4 address in network
;; byte order, say as supplied as the 'connection' argument of
;; accept-ipv4-connection, and returns a string with the address
;; converted to decimal dotted format.
(define (ipv4-address->string addr)
  (string-append (number->string (bytevector-u8-ref addr 0))
		 "."
		 (number->string (bytevector-u8-ref addr 1))
		 "."
		 (number->string (bytevector-u8-ref addr 2))
		 "."
		 (number->string (bytevector-u8-ref addr 3))))

;; helper for ipv6-address->string; converts a two-byte integer into
;; an uppercase hex string of length 4, inserting leading '0's where
;; necessary
(define (u16->hex h)
  (let ([hex (number->string h 16)])
    (case (string-length hex)
      [(1) (string-append "000" hex)]
      [(2) (string-append "00" hex)]
      [(3) (string-append "0" hex)]
      [(4) hex])))

;; takes a bytevector of size 16 containing an IPv6 address in network
;; byte order, say as supplied as the 'connection' argument of
;; accept-ipv6-connection, and returns a string with the address
;; converted to fully uncompressed hex colonned upper case format.
(define (ipv6-address->string addr)
  ;; the bytevector is short enough that we can do the loop unrolling
  ;; by hand
  (string-append (u16->hex (bytevector-u16-ref addr 0 (endianness big)))
		 ":"
		 (u16->hex (bytevector-u16-ref addr 2 (endianness big)))
		 ":"
		 (u16->hex (bytevector-u16-ref addr 4 (endianness big)))
		 ":"
		 (u16->hex (bytevector-u16-ref addr 6 (endianness big)))
		 ":"
		 (u16->hex (bytevector-u16-ref addr 8 (endianness big)))
		 ":"
		 (u16->hex (bytevector-u16-ref addr 10 (endianness big)))
		 ":"
		 (u16->hex (bytevector-u16-ref addr 12 (endianness big)))
		 ":"
		 (u16->hex (bytevector-u16-ref addr 14 (endianness big)))))
		 
(define shutdown_ (foreign-procedure "ss_shutdown_"
				     (int int)
				     boolean))

;; 'fd' is the socket file descriptor to be shutdown.  'how' should be
;; 'rd, 'wr, or 'rdwr.  This procedure returns #t on success and #f on
;; failure.
(define (shutdown fd how)
  (case how
    [(rd) (shutdown_ fd 0)]
    [(wr) (shutdown_ fd 1)]
    [(rdwr) (shutdown_ fd 2)]
    [else (error "shutdown" "Incorrect second argument passed to shutdown procedure")]))

;; closes a file descriptor.  This procedure returns #t on success and
;; #f on failure .  This procedure should only be used with file
;; descriptors which are not owned by a port - otherwise apply
;; close-port to the port.
(define close-fd (foreign-procedure "ss_close_fd"
				    (int)
				    boolean))

(define write-bytevector-impl (foreign-procedure "ss_write_bytevector"
						 (int u8* size_t)
						 boolean))

(define regular-file-p-impl (foreign-procedure "ss_regular_file_p"
					       (int)
					       int))

(define (raise-exception-if-regular-file fd)
  (case (regular-file-p-impl fd)
    [(0) #f]
    [(1) (raise (condition (make-i/o-write-error)
                           (make-who-condition "raise-exception-if-regular-file")
                           (make-message-condition "write-bytevector procedure cannot be used with regular files")))]
    [(-1) (raise (condition (make-i/o-write-error)
                            (make-who-condition "raise-exception-if-regular-file")
                            (make-message-condition "C fstat() function returned an error")))]))

;; In chez scheme, ports can be constructed from file descriptors
;; using the open-fd-input-port, open-fd-output-port and
;; open-fd-input/output-port procedures.  The last of those would be
;; useful for sockets, except that chez scheme's port implementation
;; has the infortunate feature that a port opened and used for both
;; reading and writing via the port's buffers must be seekable (that
;; is to say, its underlying file descriptor must have a file position
;; pointer).  For ports representing non-seekable read/write file
;; descriptors such as sockets, this means that with any port other
;; than a non-buffered binary port, an exception will arise if
;; attempting to write to the port using R6RS procedures after it has
;; previously been read from, unless an intervening call is made to
;; clear-input-port between the last read and the first next write.
;;
;; As having buffering enabled on input ports is usually desirable,
;; this procedure is designed to circumvent the problem mentioned
;; above: it by-passes the port's output buffers entirely and sends
;; the output to the underlying file descriptor directly.  (This means
;; that if the port has previously been used for writing using chez
;; scheme's R6RS write procedures, the port must be flushed before
;; this procedure is called; but the best thing with a socket is to
;; carry out all writing to the socket port using this procedure or
;; the write-string procedure, and all reading using R6RS read
;; procedures, in which case all is good.  This can be enforced by
;; constructing the socket port with open-fd-input-port rather than
;; open-fd-input/output-port.)
;;
;; One remaining point to watch out for is that clear-input-port must
;; normally be called before an input/output port representing a
;; socket (that is, one which has been constructed with
;; open-fd-input/output-port) is closed or otherwise flushed for
;; output, otherwise the exception mentioned above might arise.
;;
;; 'port' can be a binary port or a textual port.  However, this
;; procedure will raise a &i/o-write-error exception if passed a port
;; representing a regular file with a file position pointer.
;;
;; This procedure will return #t if the write succeeded, or #f if a
;; local error arose.
;;
;; Do not use this procedure with a non-blocking socket: use
;; chez-a-sync's await-put-bytevector! procedure instead.
(define (write-bytevector port bv)
  (let ([fd (port-file-descriptor port)])
    (raise-exception-if-regular-file fd)
    (write-bytevector-impl fd bv (bytevector-length bv))))

;; See the documentation on the write-bytevector procedure for more
;; information about this procedure.  This procedure applies
;; string->bytevector to 'text' using the transcoder associated with
;; 'port', and then applies write-bytevector to the result.  'port'
;; must be a textual port.
;;
;; Do not use this procedure with a non-blocking socket: use
;; chez-a-sync's await-put-string! procedure instead.
(define (write-string port text)
  (write-bytevector port (string->bytevector text (port-transcoder port))))

;; This returns the current C errno value.  Its main purpose is to be
;; called after write-bytevector or write-string has returned #f in
;; order to determine the source of the failure to write.  For
;; example, if errno is 32 then on BSDs and linux, EPIPE has arisen.
;; Call this procedure immediately after the failure has arisen or its
;; value may be superceded by a newer error.
(define get-errno (foreign-procedure "ss_get_errno"
				     ()
				     int))

) ;; library
