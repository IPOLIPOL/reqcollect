.PHONY: all build merge collector clean

SUBMISSIONS := $(wildcard submissions/*.sexp)

all: build

build:
	dune build

merge: build
	mkdir -p repo
	./_build/default/bin/main.exe merge \
	  schemas/crane.v1.sexp \
	  $(SUBMISSIONS) \
	  -o repo/merged.sexp -b batch-001

collector: build
	mkdir -p dist
	sed -e '/__INJECT_JS__/{' \
	    -e '  r _build/default/web/main.bc.js' \
	    -e '  d' \
	    -e '}' web/template.html > dist/collector.html
	@echo "Wrote dist/collector.html (self-contained)"

clean:
	dune clean
	rm -rf repo dist