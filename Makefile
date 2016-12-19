## -----------------------------
CHEZDIR = /usr/lib/chez-scheme
LIBDIR = /usr/lib
## -----------------------------

TARGETS = libchez-simple-sockets.so

all: $(TARGETS)

.SUFFIXES: .c .so

.c.so:
	gcc -D_XOPEN_SOURCE=600 -std=c99 -fPIC -shared -o $@ $<

install: all
	install -d $(DESTDIR)$(CHEZDIR)/simple-sockets
#	install -m644 -t $(DESTDIR)$(CHEZDIR)/arcfide sockets.sls LICENSE
#	install -m644 -t $(DESTDIR)$(CHEZDIR)/arcfide/impl sockets.ss
	install -m755 -t $(DESTDIR)$(LIBDIR) $(TARGETS)
#	install -m644 -t $(DESTDIR)$(DOCDIR)/chez-sockets LICENSE sockets.pdf

clean:
	rm -f $(TARGETS)
