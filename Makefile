## -----------------------------
CHEZDIR = /usr/lib/chez-scheme
LIBDIR = /usr/lib
## -----------------------------

TARGETS = libchez-simple-sockets.so
SOURCES = basic.ss common.ss a-sync.ss

all: $(TARGETS)

.SUFFIXES: .c .so

.c.so:
	gcc -D_XOPEN_SOURCE=600 -std=c99 -fPIC -shared -o $@ $<

install: all
	install -d $(DESTDIR)$(CHEZDIR)/simple-sockets
	install -m644 -t $(DESTDIR)$(CHEZDIR)/simple-sockets $(SOURCES) LICENSE
	install -m755 -t $(DESTDIR)$(LIBDIR) $(TARGETS)

clean:
	rm -f $(TARGETS)
