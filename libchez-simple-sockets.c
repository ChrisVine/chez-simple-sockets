/*
  Copyright (C) 2016 to 2021 Chris Vine

  This file is licensed under the Apache License, Version 2.0 (the
  "License"); you may not use this file except in compliance with the
  License.  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
  implied.  See the License for the specific language governing
  permissions and limitations under the License.
*/

#include <unistd.h>       // for close, fcntl, unlink, write and ssize_t

#include <sys/types.h>    // for socket, connect, getaddrinfo, accept and getsockopt
#include <sys/stat.h>     // for fstat
#include <sys/socket.h>   // for socket, connect, getaddrinfo, accept, shutdown and getsockopt
#include <sys/un.h>       // for sockaddr_un
#include <netinet/in.h>   // for sockaddr_in and sockaddr_in6
#include <arpa/inet.h>    // for htons and inet_pton
#include <netdb.h>        // for getaddrinfo
#include <fcntl.h>        // for fcntl

#include <string.h>       // for memset, memcpy, strlen and strcpy
#include <stdint.h>       // for uint8_t and uint32_t
#include <signal.h>       // for sigaction
#include <stddef.h>       // for size_t
#include <errno.h>

// these are in the 'scheme' binary and can be statically linked
// against
int Sactivate_thread(void);
void Sdeactivate_thread(void);
void Slock_object(void*);
void Sunlock_object(void*);

int ss_set_fd_non_blocking(int fd) {
  int flags = fcntl(fd, F_GETFL, 0);
  if (flags == -1) return 0;
  return fcntl(fd, F_SETFL, (flags | O_NONBLOCK)) != -1;
}

int ss_set_fd_blocking(int fd) {
  int flags = fcntl(fd, F_GETFL, 0);
  if (flags == -1) return 0;
  return fcntl(fd, F_SETFL, (flags & ~O_NONBLOCK)) != -1;
}

int ss_check_sock_error(int fd) {
  int val = 0;
  int len = sizeof(val);
  int res = getsockopt(fd, SOL_SOCKET, SO_ERROR, (void*)&val, (socklen_t*)&len);
  return val;
}

// It is almost always a mistake not to ignore or otherwise deal with
// SIGPIPE in programs using sockets.  This function is a utility
// which if called will cause SIGPIPE to be ignored: instead any
// attempt to write to a socket which has been closed at the remote
// end will cause write/send to return with -1 and errno set to EPIPE.
int ss_set_ignore_sigpipe() {
  struct sigaction sig_act_pipe;
  sig_act_pipe.sa_handler = SIG_IGN;
  // we don't need to mask off any signals
  sigemptyset(&sig_act_pipe.sa_mask);
  sig_act_pipe.sa_flags = 0;
  return sigaction(SIGPIPE, &sig_act_pipe, 0) != -1;
}

// arguments: if port is greater than 0, it is set as the port to
// which the connection will be made, otherwise this is deduced from
// the service argument.  The service argument may be NULL, in which
// case a port number greater than 0 must be given.  If 'blocking' is
// false, the file descriptor is set non-blocking and this function
// will return before the connection is made.

// return value: file descriptor of socket, or -1 on failure to look
// up address, -2 on failure to construct a socket, -3 on a failure to
// connect with blocking true.
int ss_connect_to_ipv4_host_impl(const char* address, const char* service,
				 unsigned short port, int blocking) {

  struct addrinfo hints;
  memset(&hints, 0, sizeof(hints));
  hints.ai_family = AF_INET;
  hints.ai_socktype = SOCK_STREAM;

  // getaddrinfo and connect may show latency - release the GC
  Slock_object((void*)address);
  if (service) Slock_object((void*)service);
  Sdeactivate_thread();

  struct addrinfo* info;
  int saved_errno = 0;
  if (getaddrinfo(address, service, &hints, &info)
      || info == NULL) {
    saved_errno = errno;
    Sactivate_thread();
    Sunlock_object((void*)address);
    if (service) Sunlock_object((void*)service);
    errno = saved_errno;
    return -1;
  }

  int sock;
  struct addrinfo* tmp;
  int err = 0;

  // loop through the offered numeric addresses
  for (tmp = info; tmp != NULL; tmp = tmp->ai_next) {
    err = 0;
    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock == -1) {
      saved_errno = errno;
      err = -2;
      break;
    }
    // setting FD_CLOEXEC creates the traditional race if another
    // thread is running in the program and it might exec concurrently
    // with the creation of the socket in this thread, but we can only
    // do what we can do: linux-specific versions of socket() to avoid
    // this are probably not a good idea
    fcntl(sock, F_SETFD, fcntl(sock, F_GETFD) | FD_CLOEXEC);

    if (!blocking && !(ss_set_fd_non_blocking(sock))) {
      saved_errno = errno;
      close(sock);
      err = -2;
      break;
    }

    struct sockaddr* in = tmp->ai_addr;
    // if we passed NULL to the service argument of getaddrinfo, we
    // have to set the port number by hand or connect will fail
    if (port > 0)
      ((struct sockaddr_in*)in)->sin_port = htons(port);
    int res;
    do {
      res = connect(sock, in, sizeof(struct sockaddr_in));
    } while (res == -1 && errno == EINTR);
    saved_errno = errno;
    if (res == -1 && errno != EINPROGRESS) {
      close(sock);
      err = -3;
      continue;
    }
    else break;
  }

  Sactivate_thread();
  Sunlock_object((void*)address);
  if (service) Sunlock_object((void*)service);
  freeaddrinfo(info);
  errno = saved_errno;

  if (err) return err;
  return sock;
}

// arguments: if port is greater than 0, it is set as the port to
// which the connection will be made, otherwise this is deduced from
// the service argument.  The service argument may be NULL, in which
// case a port number greater than 0 must be given.  If 'blocking' is
// false, the file descriptor is set non-blocking and this function
// will return before the connection is made.

// return value: file descriptor of socket, or -1 on failure to look
// up address, -2 on failure to construct a socket, -3 on a failure to
// connect with blocking true.
int ss_connect_to_ipv6_host_impl(const char* address, const char* service,
				 unsigned short port, int blocking) {

  struct addrinfo hints;
  memset(&hints, 0, sizeof(hints));
  hints.ai_family = AF_INET6;
  hints.ai_socktype = SOCK_STREAM;

  // getaddrinfo and connect may show latency - release the GC
  Slock_object((void*)address);
  if (service) Slock_object((void*)service);
  Sdeactivate_thread();

  struct addrinfo* info;
  int saved_errno = 0;
  if (getaddrinfo(address, service, &hints, &info)
      || info == NULL) {
    saved_errno = errno;
    Sactivate_thread();
    Sunlock_object((void*)address);
    if (service) Sunlock_object((void*)service);
    errno = saved_errno;
    return -1;
  }

  int sock;
  struct addrinfo* tmp;
  int err = 0;

  // loop through the offered numeric addresses
  for (tmp = info; tmp != NULL; tmp = tmp->ai_next) {
    err = 0;
    sock = socket(AF_INET6, SOCK_STREAM, 0);
    if (sock == -1) {
      saved_errno = errno;
      err = -2;
      break;
    }
    // setting FD_CLOEXEC creates the traditional race if another
    // thread is running in the program and it might exec concurrently
    // with the creation of the socket in this thread, but we can only
    // do what we can do: linux-specific versions of socket() to avoid
    // this are probably not a good idea
    fcntl(sock, F_SETFD, fcntl(sock, F_GETFD) | FD_CLOEXEC);

    if (!blocking && !(ss_set_fd_non_blocking(sock))) {
      saved_errno = errno;
      close(sock);
      err = -2;
      break;
    }
    
    struct sockaddr* in = tmp->ai_addr;
    // if we passed NULL to the service argument of getaddrinfo, we
    // have to set the port number by hand or connect will fail
    if (port > 0)
      ((struct sockaddr_in6*)in)->sin6_port = htons(port);
    int res;
    do {
      res = connect(sock, in, sizeof(struct sockaddr_in6));
    } while (res == -1 && errno == EINTR);
    saved_errno = errno;
    if (res == -1 && errno != EINPROGRESS) {
      close(sock);
      err = -3;
      continue;
    }
    else break;
  }

  Sactivate_thread();
  Sunlock_object((void*)address);
  if (service) Sunlock_object((void*)service);
  freeaddrinfo(info);
  errno = saved_errno;

  if (err) return err;
  return sock;
}

// arguments: if 'blocking' is false, the file descriptor is set
// non-blocking and this function may return before the connection is
// made.

// return value: file descriptor of socket, or -1 if 'pathname' is too
// long for the socket implementation, -2 on failure to construct a
// socket, -3 on a failure to connect with blocking true.
int ss_connect_to_unix_host_impl(const char* pathname, int blocking) {

  struct sockaddr_un addr;
  memset(&addr, 0, sizeof(addr));

  // '>=' not '>' in order to accomodate final '\0' byte
  if (strlen(pathname) >= sizeof(addr.sun_path)) {
    errno = 0;
    return -1;
  }
  addr.sun_family = AF_UNIX;
  strcpy(addr.sun_path, pathname);

  // connect may show latency - release the GC
  Sdeactivate_thread();

  int saved_errno = 0;
  int err = 0;
  int sock = socket(AF_UNIX, SOCK_STREAM, 0);

  if (sock == -1) {
    saved_errno = errno;
    err = -2;
  }
  else {
    // setting FD_CLOEXEC creates the traditional race if another
    // thread is running in the program and it might exec concurrently
    // with the creation of the socket in this thread, but we can only
    // do what we can do: linux-specific versions of socket() to avoid
    // this are probably not a good idea
    fcntl(sock, F_SETFD, fcntl(sock, F_GETFD) | FD_CLOEXEC);
    if (!blocking && !(ss_set_fd_non_blocking(sock))) {
      saved_errno = errno;
      close(sock);
      err = -2;
    }
  }

  if (!err) {
    int res;
    do {
      res = connect(sock, (struct sockaddr*)&addr, sizeof(struct sockaddr_un));
    } while (res == -1 && errno == EINTR);
    saved_errno = errno;
    if (res == -1 && errno != EINPROGRESS && errno != EAGAIN) {
      close(sock);
      err = -3;
    }
  }

  Sactivate_thread();
  errno = saved_errno;

  if (err) return err;
  return sock;
}

// arguments: address must be a string in decimal dotted notation
// giving the address to bind the socket to.  If address is NULL, the
// socket will bind on any interface.  port is the port to listen on.
// backlog is the maximum number of queueing connections.

// return value: file descriptor of socket, or -1 on failure to make
// an address, -2 on failure to create a socket, -3 on a failure to
// bind to the socket, and -4 on a failure to listen on the socket.
int ss_listen_on_ipv4_socket_impl(const char* address, unsigned short port, int backlog) {

  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));

  addr.sin_family = AF_INET;
  if (address) {
    if (!(inet_pton(AF_INET, address, &(addr.sin_addr)) == 1))
      return -1;
  }
  else
    addr.sin_addr.s_addr = htonl(INADDR_ANY);

  int sock = socket(AF_INET, SOCK_STREAM, 0);
  if (sock == -1)
    return -2;
  // setting FD_CLOEXEC creates the traditional race if another thread
  // is running in the program and it might exec concurrently with the
  // creation of the socket in this thread, but we can only do what we
  // can do: linux-specific versions of socket() to avoid this are
  // probably not a good idea
  fcntl(sock, F_SETFD, fcntl(sock, F_GETFD) | FD_CLOEXEC);

  int optval = 1;
  // we don't need to check the return value of setsockopt() here
  setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof(optval));

  addr.sin_port = htons(port);
    
  if ((bind(sock, (struct sockaddr*)&addr, sizeof(addr))) == -1) {
    int saved_errno = errno;
    close(sock);
    errno = saved_errno;
    return -3;
  }

  if ((listen(sock, backlog)) == -1) {
    int saved_errno = errno;
    close(sock);
    errno = saved_errno;
    return -4;
  }

  return sock;
}

// arguments: address must be a string in colonned hex notation giving
// the address to bind the socket to.  If address is NULL, the socket
// will bind on any interface.  port is the port to listen on.
// backlog is the maximum number of queueing connections.

// return value: file descriptor of socket, or -1 on failure to make
// an address, -2 on failure to create a socket, -3 on a failure to
// bind to the socket, and -4 on a failure to listen on the socket.
int ss_listen_on_ipv6_socket_impl(const char* address, unsigned short port, int backlog) {

  struct sockaddr_in6 addr;
  memset(&addr, 0, sizeof(addr));

  addr.sin6_family = AF_INET6;
  if (address) {
    if (!(inet_pton(AF_INET6, address, &(addr.sin6_addr)) == 1))
      return -1;
  }
  else
    addr.sin6_addr = in6addr_any;

  int sock = socket(AF_INET6, SOCK_STREAM, 0);
  if (sock == -1)
    return -2;
  // setting FD_CLOEXEC creates the traditional race if another thread
  // is running in the program and it might exec concurrently with the
  // creation of the socket in this thread, but we can only do what we
  // can do: linux-specific versions of socket() to avoid this are
  // probably not a good idea
  fcntl(sock, F_SETFD, fcntl(sock, F_GETFD) | FD_CLOEXEC);

  int optval = 1;
  // we don't need to check the return value of setsockopt() here
  setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof(optval));

  addr.sin6_port = htons(port);
    
  if ((bind(sock, (struct sockaddr*)&addr, sizeof(addr))) == -1) {
    int saved_errno = errno;
    close(sock);
    errno = saved_errno;
    return -3;
  }

  if ((listen(sock, backlog)) == -1) {
    int saved_errno = errno;
    close(sock);
    errno = saved_errno;
    return -4;
  }

  return sock;
}

// arguments: backlog is the maximum number of queueing connections.
// If error_on_existing is true, any existing or stale socket or other
// file by the name of pathname will cause an error to arise when the
// unix domain socket is bound.  If false (the default), then any
// prior existing socket will be deleted before binding.

// return value: file descriptor of socket, or -1 if 'pathname' is too
// long for the socket implementation, -2 on failure to create a
// socket, -3 on a failure to bind to the socket, and -4 on a failure
// to listen on the socket.
int ss_listen_on_unix_socket_impl(const char* pathname, int backlog, int error_on_existing) {

  struct sockaddr_un addr;
  memset(&addr, 0, sizeof(addr));

  // '>=' not '>' in order to accomodate final '\0' byte
  if (strlen(pathname) >= sizeof(addr.sun_path)) {
    errno = 0;
    return -1;
  }
  addr.sun_family = AF_UNIX;
  strcpy(addr.sun_path, pathname);

  if (!error_on_existing) unlink(pathname);

  int sock = socket(AF_UNIX, SOCK_STREAM, 0);
  if (sock == -1)
    return -2;
  // setting FD_CLOEXEC creates the traditional race if another thread
  // is running in the program and it might exec concurrently with the
  // creation of the socket in this thread, but we can only do what we
  // can do: linux-specific versions of socket() to avoid this are
  // probably not a good idea
  fcntl(sock, F_SETFD, fcntl(sock, F_GETFD) | FD_CLOEXEC);
    
  if ((bind(sock, (struct sockaddr*)&addr, sizeof(addr))) == -1) {
    int saved_errno = errno;
    close(sock);
    errno = saved_errno;
    return -3;
  }

  if ((listen(sock, backlog)) == -1) {
    int saved_errno = errno;
    close(sock);
    errno = saved_errno;
    return -4;
  }

  return sock;
}

// arguments: sock is the file descriptor of the socket on which to
// accept connections, as returned by listen_on_ipv4_socket.
// connection is an array of size 4 in which the binary address of the
// connecting client will be placed in network byte order, or NULL.

// return value: file descriptor for the connection on success, -1 on
// failure or -2 if EAGAIN or EWOULDBLOCK encountered on non-blocking
// socket.
int ss_accept_ipv4_connection_impl(int sock, uint32_t* connection) {

  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  socklen_t addr_len = sizeof(addr);

  // release the GC for accept() call
  if (connection) Slock_object((void*)connection);
  Sdeactivate_thread();

  int connect_sock;
  do {
    connect_sock = accept(sock, (struct sockaddr*)&addr, &addr_len);
    if (connect_sock != -1) {
      // setting FD_CLOEXEC creates the traditional race if another
      // thread is running in the program and it might exec
      // concurrently with the creation of the connection socket in
      // this thread, but we can only do what we can do:
      // linux-specific versions of accept() to avoid this are
      // probably not a good idea
      fcntl(connect_sock, F_SETFD, fcntl(connect_sock, F_GETFD) | FD_CLOEXEC);
    }
  } while (connect_sock == -1 && errno == EINTR);

  int saved_errno = errno;
  Sactivate_thread();
  if (connection) Sunlock_object((void*)connection);

  if (addr_len > sizeof(addr)) {
    close(connect_sock);
    errno = saved_errno;
    return -1;
  }
  if (connect_sock == -1) {
    errno = saved_errno;
    if (saved_errno == EAGAIN || saved_errno == EWOULDBLOCK)
      return -2;
    return -1;
  }
  if (connection) memcpy(connection, &addr.sin_addr.s_addr, sizeof(uint32_t));
  return connect_sock;
}

// arguments: sock is the file descriptor of the socket on which to
// accept connections, as returned by listen_on_ipv6_socket.
// connection is an array of size 16 in which the binary address of
// the connecting client will be placed in network byte order, or
// NULL.

// return value: file descriptor for the connection on success, -1 on
// failure or -2 if EAGAIN or EWOULDBLOCK encountered on non-blocking
// socket.
int ss_accept_ipv6_connection_impl(int sock, uint8_t* connection) {

  struct sockaddr_in6 addr;
  memset(&addr, 0, sizeof(addr));
  socklen_t addr_len = sizeof(addr);

  // release the GC for accept() call
  if (connection) Slock_object((void*)connection);
  Sdeactivate_thread();

  int connect_sock;
  do {
    connect_sock = accept(sock, (struct sockaddr*)&addr, &addr_len);
    if (connect_sock != -1) {
      // setting FD_CLOEXEC creates the traditional race if another
      // thread is running in the program and it might exec
      // concurrently with the creation of the connection socket in
      // this thread, but we can only do what we can do:
      // linux-specific versions of accept() to avoid this are
      // probably not a good idea
      fcntl(connect_sock, F_SETFD, fcntl(connect_sock, F_GETFD) | FD_CLOEXEC);
    }
  } while (connect_sock == -1 && errno == EINTR);

  int saved_errno = errno;
  Sactivate_thread();
  if (connection) Sunlock_object((void*)connection);

  if (addr_len > sizeof(addr)) {
    close(connect_sock);
    errno = saved_errno;
    return -1;
  }
  if (connect_sock == -1) {
    errno = saved_errno;
    if (saved_errno == EAGAIN || saved_errno == EWOULDBLOCK)
      return -2;
    return -1;
  }
  if (connection) memcpy(connection, &addr.sin6_addr.s6_addr, sizeof(addr.sin6_addr.s6_addr));
  return connect_sock;
}

// argument: sock is the file descriptor of the socket on which to
// accept connections, as returned by listen_on_unix_socket.

// return value: file descriptor for the connection on success, -1 on
// failure or -2 if EAGAIN or EWOULDBLOCK encountered on non-blocking
// socket.
int ss_accept_unix_connection_impl(int sock) {

  struct sockaddr_un addr;
  memset(&addr, 0, sizeof(addr));
  socklen_t addr_len = sizeof(addr);

  // release the GC for accept() call
  Sdeactivate_thread();

  int connect_sock;
  do {
    connect_sock = accept(sock, (struct sockaddr*)&addr, &addr_len);
    if (connect_sock != -1) {
      // setting FD_CLOEXEC creates the traditional race if another
      // thread is running in the program and it might exec
      // concurrently with the creation of the connection socket in
      // this thread, but we can only do what we can do:
      // linux-specific versions of accept() to avoid this are
      // probably not a good idea
      fcntl(connect_sock, F_SETFD, fcntl(connect_sock, F_GETFD) | FD_CLOEXEC);
    }
  } while (connect_sock == -1 && errno == EINTR);

  int saved_errno = errno;
  Sactivate_thread();

  if (addr_len > sizeof(addr)) {
    close(connect_sock);
    errno = saved_errno;
    return -1;
  }
  if (connect_sock == -1) {
    errno = saved_errno;
    if (saved_errno == EAGAIN || saved_errno == EWOULDBLOCK)
      return -2;
    return -1;
  }
  return connect_sock;
}

int ss_shutdown_(int fd, int how) {
  switch (how) {
  case 0:
    return (shutdown(fd, SHUT_RD) == 0);
  case 1:
    return (shutdown(fd, SHUT_WR) == 0);
  case 2:
    return (shutdown(fd, SHUT_RDWR) == 0);
  default:
    return 0;
  }
}

int ss_close_fd(int fd) {
  return (close(fd) == 0);
}

int ss_write_bytevector(int fd, const char* buf, size_t count) {
  ssize_t res;
  do {
    res = write(fd, buf, count);
    if (res > 0) {
      buf += res;
      count -= res;
    }
  } while (count && (res != -1 || errno == EINTR));
  return res != -1;
}

int ss_regular_file_p(int fd) {
  struct stat buf;
  if (fstat(fd, &buf) == -1)
    return -1;
  if (S_ISREG(buf.st_mode))
    return 1;
  return 0;
}

int ss_get_errno(void) {
  return errno;
}
