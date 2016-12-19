chez-simple-sockets
===================

Chez-simple-sockets is a library for Chez Scheme containing a few
useful procedures for everyday use of IPv4 and IPv6 SOCK_STREAM
sockets.  It does not purport to provide wide-ranging support for BSD
sockets - just the procedures that casual users wanting to connect to
remote hosts, or to run simple servers, might expect to use.  It is
mainly intended as a support library for chez-a-sync.

The library has been designed to be thread-safe when blocking, so it
can be used with installations of Chez Scheme with native thread
support: it releases the garbage collector when blocking in C function
calls (with appropriate protection for objects exported into C).


How to install
--------------

First, amend the Makefile as appropriate for the system in use, then
run 'make' as user and 'make install' as root.

Assuming the simple-sockets.ss has been installed in a library
directory in which Chez Scheme can find library files, it can be
imported into user code by importing it as (simple-sockets).

Library procedures
------------------

It offers the following procedures:

`(connect-to-ipv4-host address service port)`

This will connect to a remote ipv4 host.  If 'port' is greater than 0,
it is set as the port to which the connection will be made, otherwise
this is deduced from the 'service' argument, which should be a string
such as "html".  The 'service' argument may be #f, in which case a
port number greater than 0 must be given.

The 'address' argument should be a string which may be either the
domain name of the server to which a connection is to be made or a
dotted decimal address.

On success, this procedure returns a positive number which is the file
descriptor of a connection socket.  On error it returns -1 on failure
to look up 'address', -2 on failure to construct a socket and -3 on a
failure to connect.

***
`(connect-to-ipv6-host address service port)`

This will connect to a remote ipv6 host.  If 'port' is greater than 0,
it is set as the port to which the connection will be made, otherwise
this is deduced from the 'service' argument, which should be a string
such as "html".  The 'service' argument may be #f, in which case a
port number greater than 0 must be given.

The 'address' argument should be a string which may be either the
domain name of the server to which a connection is to be made or a
colonned hex IPv6 address.

On success, this procedure returns a positive number which is the file
descriptor of a connection socket.  On error it returns -1 on failure
to look up 'address', -2 on failure to construct a socket and -3 on a
failure to connect.

