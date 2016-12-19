chez-simple-sockets
===================

Chez-simple-sockets is a package for Chez Scheme containing some
procedures for everyday use of IPv4 and IPv6 SOCK_STREAM sockets.  It
does not purport to provide wide-ranging support for BSD sockets -
just the procedures that casual users wanting to connect to remote
hosts, or to run simple servers, might expect to use.  It is mainly
intended as a support library for chez-a-sync at
https://github.com/ChrisVine/chez-a-sync.

The package has been designed to be thread-safe when blocking, so it
can be used with installations of Chez Scheme with native thread
support: it releases the garbage collector when blocking in C function
calls (with appropriate protection for objects exported into C).  It
also avoids trying to provide scheme wrappers for C socket-related
structs of a particular layout, because POSIX specifies the members
that these structs must have and not their layout (accordingly,
relevant structs are accessed at the C level and not the scheme level,
which makes the code considerably more portable).

The package comes in two R6RS library files.  The (simple-sockets
basic) library file provides for making synchronous connections to
remote hosts and for accepting synchronous connections from remote
hosts, and has various additional utility procedures.  The
(simple-sockets a-sync) library file enables such connections to be
handled asynchronously using the chez-a-sync library.

How to install
--------------

First, amend the Makefile as appropriate for the system in use, then
run 'make' as user and 'make install' as root.

Assuming that the package has been installed in a library directory in
which Chez Scheme can find library files, it can be imported into user
code by importing it as (simple-sockets basic) and (simple-sockets
a-sync).  (simple-sockets a-sync) requires the chez-a-sync library;
(simple-sockets basic) does not.

(simple-sockets basic)
----------------------

The (simple-sockets basic) library file offers the following
procedures:

`(connect-to-ipv4-host address service port)`

This will connect to a remote IPv4 host.  If 'port' is greater than 0,
it is set as the port to which the connection will be made, otherwise
this is deduced from the 'service' argument, which should be a string
such as "html".  The 'service' argument may be #f, in which case a
port number greater than 0 must be given.

The 'address' argument should be a string which may be either the
domain name of the server to which a connection is to be made or a
dotted decimal address.

&connect-exception will be raised if the connection attempt fails, to
which applying connect-exception? will return #t.

On success, this procedure returns the file descriptor of a connection
socket.

***
`(connect-to-ipv6-host address service port)`

This will connect to a remote IPv6 host.  If 'port' is greater than 0,
it is set as the port to which the connection will be made, otherwise
this is deduced from the 'service' argument, which should be a string
such as "html".  The 'service' argument may be #f, in which case a
port number greater than 0 must be given.

The 'address' argument should be a string which may be either the
domain name of the server to which a connection is to be made or a
colonned IPv6 hex address.

&connect-exception will be raised if the connection attempt fails, to
which applying connect-exception? will return #t.

On success, this procedure returns the file descriptor of a connection
socket.

***
`(listen-on-ipv4-socket local port backlog)`

This constructs a listening IPv4 server socket.  If 'local' is true,
the socket will only bind on localhost.  If false, it will bind on any
interface.  'port' is the port to listen on.  'backlog' is the maximum
number of queueing connections provided by the socket.

&listen-exception will be raised if the making of a listening socket
fails, to which applying listen-exception? will return #t.

On success, this procedure returns the file descriptor of the server
socket.

***
`(listen-on-ipv6-socket local port backlog)`

This constructs a listening IPv6 server socket.  If 'local' is true,
the socket will only bind on localhost.  If false, it will bind on any
interface.  'port' is the port to listen on.  'backlog' is the maximum
number of queueing connections provided by the socket.

&listen-exception will be raised if the making of a listening socket
fails, to which applying listen-exception? will return #t.

On success, this procedure returns the file descriptor of the server
socket.

***
`(accept-ipv4-connection sock connection)`

This procedure will accept incoming connections on a listening IPv4
socket.

'sock' is the file descriptor of the socket on which to accept
connections, as returned by listen-on-ipv4-socket.  'connection' is a
bytevector of size 4 to be passed to the procedure as an out
parameter, in which the binary address of the connecting client will
be placed in network byte order, or #f.  &accept-exception will be
raised if connection attempts fail, to which applying
accept-exception?  will return #t.

On success, this procedure returns the file descriptor for the
connection socket.

***
`(accept-ipv6-connection sock connection)`

This procedure will accept incoming connections on a listening IPv6
socket.

'sock' is the file descriptor of the socket on which to accept
connections, as returned by listen-on-ipv6-socket.  'connection' is a
bytevector of size 16 to be passed to the procedure as an out
parameter, in which the binary address of the connecting client will
be placed in network byte order, or #f.  &accept-exception will be
raised if connection attempts fail, to which applying
accept-exception?  will return #t.

On success, this procedure returns the file descriptor for the
connection socket.

***
`(ipv4-address->string addr)`

This procedure takes a bytevector of size 4 containing an IPv4 address
in network byte order, say as supplied as the 'connection' argument of
accept-ipv4-connection, and returns a string with the address
converted to decimal dotted format.

***
`(ipv6-address->string addr)`

This procedure takes a bytevector of size 16 containing an IPv6
address in network byte order, say as supplied as the 'connection'
argument of accept-ipv6-connection, and returns a string with the
address converted to fully uncompressed hex colonned upper case
format.

***
`(set-fd-non-blocking fd)`

This procedure makes the file descriptor 'fd' non-blocking if it is
not already non-blocking, otherwise this procedure does nothing.  It
returns #t if it succeeds (including if it does nothing because the
descriptor is already non-blocking), otherwise #f.

***
`(set-fd-blocking fd)`

This procedure makes the file descriptor 'fd' blocking if it is not
already blocking, otherwise this procedure does nothing.  It returns #t
if it succeeds (including if it does nothing because the descriptor is
already blocking), otherwise #f.

***
`(connect-condition? cond)`

This procedure returns #t if the condition object 'cond' is a
&connection-condition object, otherwise #f.

***
`(listen-condition? cond)`

This procedure returns #t if the condition object 'cond' is a
&listen-condition object, otherwise #f.

***
`(accept-condition? cond)`

This procedure returns #t if the condition object 'cond' is an
&accept-condition object, otherwise #f.

***
`(shutdown fd how)`

This procedure shuts down a socket.  'fd' is the socket's file
descriptor.  'how' is a symbol which can be 'rd, 'wr, or 'rdwr.  This
procedure returns #t on success and #f on failure.

***
`(close-fd fd)`

This closes a file descriptor.  It returns #t on success and #f on
failure.  This procedure should only be used with file descriptors
which are not owned by a port - otherwise apply the close-port
procedure to the port.


(simple-sockets a-sync)
----------------------

Importing the (simple-sockets a-sync) library file requires
chez-a-sync to be installed.  It offers the following procedures:

`(await-connect-to-ipv4-host! accept resume [loop] address service port)`

This will connect asynchronously to a remote IPv4 host.  If 'port' is
greater than 0, it is set as the port to which the connection will be
made, otherwise this is deduced from the 'service' argument, which
should be a string such as "html".  The 'service' argument may be #f,
in which case a port number greater than 0 must be given.

The 'address' argument should be a string which may be either the
domain name of the server to which a connection is to be made or a
dotted decimal address.

If 'port' is a non-blocking port, the event loop will not be blocked
by this procedure even if the connection is not immediately available,
provided that the C getaddrinfo() function does not block.  In
addition this procedure only attempts to connect to the first address
the resolver offers to it.  These are important provisos which mean
that this procedure should only be used where 'address' has a single
network address which can be looked up from a local file such as
/etc/host, or it is a string in IPv4 dotted decimal format.  Otherwise
call connect-to-ipv4-host via await-task-in-thread! or
await-task-in-event-loop!.

This procedure is intended to be called in a waitable procedure
invoked by a-sync. The 'loop' argument is optional: this procedure
operates on the event loop passed in as an argument, or if none is
passed (or #f is passed), on the default event loop.

&connect-exception will be raised if the connection attempt fails, to
which applying connect-exception? will return #t.

On success, this procedure returns the file descriptor of a connection
socket.  The file descriptor will be set non-blocking.

***
`(await-connect-to-ipv6-host! accept resume [loop] address service port)`

This will connect asynchronously to a remote IPv6 host.  If 'port' is
greater than 0, it is set as the port to which the connection will be
made, otherwise this is deduced from the 'service' argument, which
should be a string such as "html".  The 'service' argument may be #f,
in which case a port number greater than 0 must be given.

The 'address' argument should be a string which may be either the
domain name of the server to which a connection is to be made or a
colonned IPv6 hex address.

If 'port' is a non-blocking port, the event loop will not be blocked
by this procedure even if the connection is not immediately available,
provided that the C getaddrinfo() function does not block.  In
addition this procedure only attempts to connect to the first address
the resolver offers to it.  These are important provisos which mean
that this procedure should only be used where 'address' has a single
network address which can be looked up from a local file such as
/etc/host, or it is a string in IPv6 hex format.  Otherwise call
connect-to-ipv6-host via await-task-in-thread! or
await-task-in-event-loop!.

This procedure is intended to be called in a waitable procedure
invoked by a-sync. The 'loop' argument is optional: this procedure
operates on the event loop passed in as an argument, or if none is
passed (or #f is passed), on the default event loop.

&connect-exception will be raised if the connection attempt fails, to
which applying connect-exception? will return #t.

On success, this procedure returns the file descriptor of a connection
socket.  The file descriptor will be set non-blocking.

***
`(await-accept-ipv4-connection! await resume [loop] sock connection)`

This procedure will accept incoming connections on a listening IPv4
socket asynchronously.

'sock' is the file descriptor of the socket on which to accept
connections, as returned by listen-on-ipv4-socket.  'connection' is a
bytevector of size 4 to be passed to the procedure as an out
parameter, in which the binary address of the connecting client will
be placed in network byte order, or #f.

This procedure will only return when a connection has been accepted.
However, the event loop will not be blocked by this procedure while
waiting.  This procedure is intended to be called in a waitable
procedure invoked by a-sync. The 'loop' argument is optional: this
procedure operates on the event loop passed in as an argument, or if
none is passed (or #f is passed), on the default event loop.

&accept-exception will be raised if connection attempts fail, to which
applying accept-exception? will return #t.

If 'sock' is not a non-blocking descriptor, it will be made
non-blocking by this procedure.

On success, this procedure returns the file descriptor for the
connection socket.  The file descriptor will be set non-blocking.

***
`(await-accept-ipv6-connection! await resume [loop] sock connection)`

This procedure will accept incoming connections on a listening IPv6
socket.

'sock' is the file descriptor of the socket on which to accept
connections, as returned by listen-on-ipv6-socket.  'connection' is a
bytevector of size 16 to be passed to the procedure as an out
parameter, in which the binary address of the connecting client will
be placed in network byte order, or #f.

This procedure will only return when a connection has been accepted.
However, the event loop will not be blocked by this procedure while
waiting.  This procedure is intended to be called in a waitable
procedure invoked by a-sync. The 'loop' argument is optional: this
procedure operates on the event loop passed in as an argument, or if
none is passed (or #f is passed), on the default event loop.

&accept-exception will be raised if connection attempts fail, to which
applying accept-exception? will return #t.

If 'sock' is not a non-blocking descriptor, it will be made
non-blocking by this procedure.

On success, this procedure returns the file descriptor for the
connection socket.  The file descriptor will be set non-blocking.
