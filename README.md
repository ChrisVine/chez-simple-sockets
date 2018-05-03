chez-simple-sockets
===================

Chez-simple-sockets is a package for Chez Scheme containing some
procedures for everyday use of IPv4, IPv6 and unix domain SOCK_STREAM
sockets.  It does not purport to provide wide-ranging support for BSD
sockets - just the procedures that users wanting to connect to remote
hosts, or to run simple servers, might generally expect to use.  It is
mainly intended as a support library for chez-a-sync at
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
remote and other hosts and for accepting synchronous connections from
remote and other hosts, and has various additional utility procedures.
The (simple-sockets a-sync) library file enables such connections to
be handled asynchronously using the chez-a-sync library.

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

&connect-condition will be raised if the connection attempt fails, to
which applying connect-condition? will return #t.

On success, this procedure returns the file descriptor of a connection
socket.  The file descriptor will be blocking.

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

&connect-condition will be raised if the connection attempt fails, to
which applying connect-condition? will return #t.

On success, this procedure returns the file descriptor of a connection
socket.  The file descriptor will be blocking.

***
`(connect-to-unix-host pathname)`

This will connect to a unix domain host.

The 'pathname' argument should be a string comprising the filesystem
name of the unix domain socket.

&connect-condition will be raised if the connection attempt fails, to
which applying connect-condition? will return #t.

On success, this procedure returns the file descriptor of a connection
socket.  The file descriptor will be blocking.

***
`(listen-on-ipv4-socket local port backlog)`

This constructs a listening IPv4 server socket.  If 'local' is true,
the socket will only bind on localhost.  If false, it will bind on any
interface.  'port' is the port to listen on.  'backlog' is the maximum
number of queueing connections provided by the socket.

&listen-condition will be raised if the making of a listening socket
fails, to which applying listen-condition? will return #t.

On success, this procedure returns the file descriptor of the server
socket.

***
`(listen-on-ipv6-socket local port backlog)`

This constructs a listening IPv6 server socket.  If 'local' is true,
the socket will only bind on localhost.  If false, it will bind on any
interface.  'port' is the port to listen on.  'backlog' is the maximum
number of queueing connections provided by the socket.

&listen-condition will be raised if the making of a listening socket
fails, to which applying listen-condition? will return #t.

On success, this procedure returns the file descriptor of the server
socket.

***
`(listen-on-unix-socket pathname backlog)`

This constructs a listening unix domain server socket.  'pathname' is
a string comprising the filesystem name of the unix domain socket.
'backlog' is the maximum number of queueing connections provided by
the socket.

&listen-condition will be raised if the making of a listening socket
fails, to which applying listen-condition? will return #t.

On success, this procedure returns the file descriptor of the server
socket.

***
`(accept-ipv4-connection sock connection)`

This procedure will accept incoming connections on a listening IPv4
socket.  It will block until a connection is made.

'sock' is the file descriptor of the socket on which to accept
connections, as returned by listen-on-ipv4-socket.  'connection' is a
bytevector of size 4 to be passed to the procedure as an out
parameter, in which the binary address of the connecting client will
be placed in network byte order, or #f.  &accept-condition will be
raised if connection attempts fail, to which applying
accept-condition? will return #t.

If 'sock' is not a blocking descriptor, it will be made blocking by
this procedure.

On success, this procedure returns the file descriptor for the
connection socket.  That file descriptor will be blocking.

***
`(accept-ipv6-connection sock connection)`

This procedure will accept incoming connections on a listening IPv6
socket.  It will block until a connection is made.

'sock' is the file descriptor of the socket on which to accept
connections, as returned by listen-on-ipv6-socket.  'connection' is a
bytevector of size 16 to be passed to the procedure as an out
parameter, in which the binary address of the connecting client will
be placed in network byte order, or #f.  &accept-condition will be
raised if connection attempts fail, to which applying
accept-condition? will return #t.

If 'sock' is not a blocking descriptor, it will be made blocking by
this procedure.

On success, this procedure returns the file descriptor for the
connection socket.  That file descriptor will be blocking.

***
`(accept-unix-connection sock)`

This procedure will accept incoming connections on a listening unix
domain socket.  It will block until a connection is made.

'sock' is the file descriptor of the socket on which to accept
connections, as returned by listen-on-unix-socket.  &accept-condition
will be raised if connection attempts fail, to which applying
accept-condition? will return #t.

If 'sock' is not a blocking descriptor, it will be made blocking by
this procedure.

On success, this procedure returns the file descriptor for the
connection socket.  That file descriptor will be blocking.

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
`(set-ignore-sigpipe)`

It is almost always a mistake not to ignore or otherwise deal with
SIGPIPE in programs using sockets.  This procedure is a utility which
if called will cause SIGPIPE to be ignored: instead any attempt to
write to a socket which has been closed at the remote end will cause
write/send to return with -1 and errno set to EPIPE.  If something
other than ignoring the signal is required, use Chez Scheme's
register-signal-handler procedure.

This procedure returns #t if it succeeds, otherwise #f.

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

***
`(write-bytevector port bv)`

In chez scheme, ports can be constructed from file descriptors using
the open-fd-input-port, open-fd-output-port and
open-fd-input/output-port procedures.  The last of those would be
useful for sockets, except that chez scheme's port implementation has
the infortunate feature that a port opened and used for both reading
and writing via the port's buffers must be seekable (that is to say,
its underlying file descriptor must have a file position pointer).
For ports representing non-seekable read/write file descriptors such
as sockets, this means that with any port other than a non-buffered
binary port, an exception will arise if attempting to write to the
port using R6RS procedures after it has previously been read from,
unless an intervening call is made to clear-input-port between the
last read and the first next write.

As having buffering enabled on input ports is usually desirable, this
procedure is designed to circumvent the problem mentioned above: it
by-passes the port's output buffers entirely and sends the output to
the underlying file descriptor directly.  (This means that if the port
has previously been used for writing using chez scheme's R6RS write
procedures, the port must be flushed before this procedure is called;
but the best thing with a socket is to carry out all writing to the
socket port using this procedure or the write-string procedure, and
all reading using R6RS read procedures, in which case all is good.
This can be enforced by constructing the socket port with
open-fd-input-port rather than open-fd-input/output-port.)

One remaining point to watch out for is that clear-input-port must
normally be called before an input/output port representing a socket
is closed or otherwise flushed for output, otherwise the exception
mentioned above might arise.

'port' can be a binary port or a textual port.  However, this
procedure will raise a &i/o-write-error exception if passed a port
representing a regular file with a file position pointer.

This procedure will return #t if the write succeeded, or #f if a local
error arose.

Do not use this procedure with a non-blocking socket: use
chez-a-sync's await-put-bytevector! procedure instead.

***
`(write-string port text)`

See the documentation on the write-bytevector procedure for more
information about this procedure.  This procedure applies
string->bytevector to 'text' using the transcoder associated with
'port', and then applies write-bytevector to the result.  'port' must
be a textual port.

Do not use this procedure with a non-blocking socket: use
chez-a-sync's await-put-string! procedure instead.


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

The event loop will not be blocked by this procedure even if the
connection is not immediately available, provided that the C
getaddrinfo() function does not block.  In addition this procedure
only attempts to connect to the first address the resolver offers to
it.  These are important provisos which mean that this procedure
should only be used where 'address' has a single network address which
can be looked up from a local file such as /etc/hosts, or it is a
string in IPv4 dotted decimal format.  Otherwise call
connect-to-ipv4-host via await-task-in-thread!,
await-task-in-event-loop! or await-task-in-thread-pool!.

This procedure is intended to be called within a waitable procedure
invoked by a-sync (which supplies the 'await' and 'resume' arguments).
The 'loop' argument is optional: this procedure operates on the event
loop passed in as an argument, or if none is passed (or #f is passed),
on the default event loop.

&connect-condition will be raised if the connection attempt fails, to
which applying connect-condition? will return #t.

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

The event loop will not be blocked by this procedure even if the
connection is not immediately available, provided that the C
getaddrinfo() function does not block.  In addition this procedure
only attempts to connect to the first address the resolver offers to
it.  These are important provisos which mean that this procedure
should only be used where 'address' has a single network address which
can be looked up from a local file such as /etc/hosts, or it is a
string in IPv6 hex format.  Otherwise call connect-to-ipv6-host via
await-task-in-thread!, await-task-in-event-loop! or
await-task-in-thread-pool!.

This procedure is intended to be called within a waitable procedure
invoked by a-sync (which supplies the 'await' and 'resume' arguments).
The 'loop' argument is optional: this procedure operates on the event
loop passed in as an argument, or if none is passed (or #f is passed),
on the default event loop.

&connect-condition will be raised if the connection attempt fails, to
which applying connect-condition? will return #t.

On success, this procedure returns the file descriptor of a connection
socket.  The file descriptor will be set non-blocking.

***
`(await-connect-to-unix-host! accept resume [loop] pathname)`

This will connect asynchronously to a unix domain host.

The 'pathname' argument should be a string comprising the filesystem
name of the unix domain socket.

The event loop will not be blocked by this procedure even if the
connection is not immediately available.

This procedure is intended to be called within a waitable procedure
invoked by a-sync (which supplies the 'await' and 'resume' arguments).
The 'loop' argument is optional: this procedure operates on the event
loop passed in as an argument, or if none is passed (or #f is passed),
on the default event loop.

&connect-condition will be raised if the connection attempt fails, to
which applying connect-condition? will return #t.

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
waiting.  This procedure is intended to be called within a waitable
procedure invoked by a-sync (which supplies the 'await' and 'resume'
arguments).  The 'loop' argument is optional: this procedure operates
on the event loop passed in as an argument, or if none is passed (or
\#f is passed), on the default event loop.

&accept-condition will be raised if connection attempts fail, to which
applying accept-condition? will return #t.

If 'sock' is not a non-blocking descriptor, it will be made
non-blocking by this procedure.

On success, this procedure returns the file descriptor for the
connection socket.  That file descriptor will be set non-blocking.

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
waiting.  This procedure is intended to be called within a waitable
procedure invoked by a-sync (which supplies the 'await' and 'resume'
arguments).  The 'loop' argument is optional: this procedure operates
on the event loop passed in as an argument, or if none is passed (or
\#f is passed), on the default event loop.

&accept-condition will be raised if connection attempts fail, to which
applying accept-condition? will return #t.

If 'sock' is not a non-blocking descriptor, it will be made
non-blocking by this procedure.

On success, this procedure returns the file descriptor for the
connection socket.  That file descriptor will be set non-blocking.

***
`(await-accept-unix-connection! await resume [loop] sock)`

This procedure will accept incoming connections on a listening unix
domain socket asynchronously.

'sock' is the file descriptor of the socket on which to accept
connections, as returned by listen-on-unix-socket.

This procedure will only return when a connection has been accepted.
However, the event loop will not be blocked by this procedure while
waiting.  This procedure is intended to be called within a waitable
procedure invoked by a-sync (which supplies the 'await' and 'resume'
arguments).  The 'loop' argument is optional: this procedure operates
on the event loop passed in as an argument, or if none is passed (or
\#f is passed), on the default event loop.

&accept-condition will be raised if connection attempts fail, to which
applying accept-condition? will return #t.

If 'sock' is not a non-blocking descriptor, it will be made
non-blocking by this procedure.

On success, this procedure returns the file descriptor for the
connection socket.  That file descriptor will be set non-blocking.
