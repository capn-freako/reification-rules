# include ../my-cabal-make.inc

install:
	cabal install -j1 --disable-documentation --force-reinstalls

suite:
	cabal install -j1 --disable-documentation --force-reinstalls --enable-tests
	cabal test

clean:
	cabal clean

fresh:
	cabal clean && make install

tags: dist
	cd src ; find . -name '*.*hs' | egrep -v 'Junk|Old|Unused|Setup' | xargs hasktags -e

# Hack: depend on dist, which updates whenever we build. Is there a standard
# GNU make technique for running a rule whenever the target is called for?
