OD = dist/build/test
ID = /usr/hs/bin
HC = mkdir -p $(OD); ghc -XHaskell2010 --make -O1 -outputdir build -Wall


all: api-tools


api-tools: .prep
	cabal build

.prep: Data/API/Scan.hs
	hub load    api-tools <api-tools.har
	hub comment api-tools "api-tools build"
	hub set     api-tools
#	ghc-pkg hide monads-tf
	cabal configure --enable-tests
	touch .prep

Data/API/Scan.hs: Data/API/Scan.x
	alex $<

save-hub:
	hub save api-tools >api-tools.har

test: .prep
	cabal test

clean:
	cabal clean
	rm -rf build .prep
