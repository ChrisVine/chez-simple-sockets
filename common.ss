;; Copyright (C) 2016 Chris Vine
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



;; signature: (connect-to-ipv4-host-impl address service port blocking)

;; arguments: if port is greater than 0, it is set as the port to
;; which the connection will be made, otherwise this is deduced from
;; the service argument.  The service argument may be #f, in which
;; case a port number greater than 0 must be given.  If 'blocking' is
;; false, the file descriptor is set non-blocking and this function
;; will return before the connection is made.

;; return value: file descriptor of socket, or -1 on failure to loop
;; up address, -2 on failure to construct a socket and -3 on a failure
;; to connect with blocking true.
(define connect-to-ipv4-host-impl (foreign-procedure "ss_connect_to_ipv4_host_impl"
						     (string string unsigned-short boolean)
						     int))

;; signature: (connect-to-ipv6-host-impl address service port blocking)

;; arguments: if port is greater than 0, it is set as the port to
;; which the connection will be made, otherwise this is deduced from
;; the service argument.  The service argument may be #f, in which
;; case a port number greater than 0 must be given.  If 'blocking' is
;; false, the file descriptor is set non-blocking and this function
;; will return before the connection is made.

;; return value: file descriptor of socket, or -1 on failure to loop
;; up address, -2 on failure to construct a socket and -3 on a failure
;; to connect with blocking true.
(define connect-to-ipv6-host-impl (foreign-procedure "ss_connect_to_ipv6_host_impl"
						     (string string unsigned-short boolean)
						     int))

;; signature: (listen-on-ipv4-socket-impl local port backlog)

;; arguments: if local is true, the socket will only bind on
;; localhost.  If false, it will bind on any interface.  port is the
;; port to listen on.  backlog is the maximum number of queueing
;; connections.

;; return value: file descriptor of socket, or -1 on failure to make
;; an address, -2 on failure to create a socket, -3 on a failure to
;; bind to the socket, and -4 on a failure to listen on the socket
(define listen-on-ipv4-socket-impl (foreign-procedure "ss_listen_on_ipv4_socket_impl"
						      (boolean unsigned-short int)
						      int))

;; signature: (listen-on-ipv6-socket-impl local port backlog)

;; arguments: if local is true, the socket will only bind on
;; localhost.  If false, it will bind on any interface.  port is the
;; port to listen on.  backlog is the maximum number of queueing
;; connections.

;; return value: file descriptor of socket, or -1 on failure to make
;; an address, -2 on failure to create a socket, -3 on a failure to
;; bind to the socket, and -4 on a failure to listen on the socket
(define listen-on-ipv6-socket-impl (foreign-procedure "ss_listen_on_ipv6_socket_impl"
						      (boolean unsigned-short int)
						      int))

;; signature: (accept-ipv4-connection-impl sock connection)

;; arguments: sock is the file descriptor of the socket on which to
;; accept connections, as returned by listen_on_ipv4_socket.
;; connection is an array of size 4 as an out parameter, in which the
;; binary address of the connecting client will be placed in network
;; byte order, or #f.

;; return value: file descriptor for the connection on success, -1 on
;; failure or -2 if EAGAIN or EWOULDBLOCK encountered on non-blocking
;; socket
(define accept-ipv4-connection-impl (foreign-procedure "ss_accept_ipv4_connection_impl"
						       (int u32*)
						       int))

;; signature: (accept-ipv6-connection-impl sock connection)

;; arguments: sock is the file descriptor of the socket on which to
;; accept connections, as returned by listen_on_ipv4_socket.
;; connection is an array of size 16 as an out parameter, in which the
;; binary address of the connecting client will be placed in network
;; byte order, or #f.

;; return value: file descriptor for the connection on success, -1 on
;; failure or -2 if EAGAIN or EWOULDBLOCK encountered on non-blocking
;; socket
(define accept-ipv6-connection-impl (foreign-procedure "ss_accept_ipv6_connection_impl"
						       (int u8*)
						       int))

(define-condition-type
  &connect-condition &condition make-connect-condition connect-condition?)
(define-condition-type
  &listen-condition &condition make-listen-condition listen-condition?)
(define-condition-type
  &accept-condition &condition make-accept-condition accept-condition?)


(define (check-raise-connect-exception sock addr)
  (case sock
    [(-1) (raise (condition (make-connect-condition)
			    (make-who-condition "check-raise-connect-exception")
			    (make-message-condition (string-append "Unable to look up address for "
								   addr))))]
    [(-2) (raise (condition (make-connect-condition)
			    (make-who-condition "check-raise-connect-exception")
			    (make-message-condition "Unable to construct socket")))]
    [(-3) (raise (condition (make-connect-condition)
			    (make-who-condition "check-raise-connect-exception")
			    (make-message-condition (string-append "Unable to connect to "
								   addr))))]
    [else sock]))

(define (check-raise-listen-exception sock local)
  (case sock
    [(-1) (raise (condition (make-listen-condition)
			    (make-who-condition "check-raise-listen-exception")
			    (make-message-condition "Unable to make address for localhost")))]
    [(-2) (raise (condition (make-listen-condition)
			    (make-who-condition "check-raise-listen-exception")
			    (make-message-condition "Unable to construct socket\n")))]
    [(-3) (raise (condition (make-listen-condition)
			    (make-who-condition "check-raise-listen-exception")
			    (make-message-condition (string-append "Unable to bind to "
								   (if local
								       "localhost"
								       "universal addresses")))))]
    [(-4) (raise (condition (make-listen-condition)
			    (make-who-condition "check-raise-listen-exception")
			    (make-message-condition "Unable to listen on socket")))]

    [else sock]))

(define (check-raise-accept-exception sock) 
  (case sock
    [(-1) (raise (condition (make-accept-condition)
			    (make-who-condition "check-raise-accept-exception")
			    (make-message-condition "Unable to accept connection on socket")))]
    [(-2) 'eagain]
    [else sock]))
