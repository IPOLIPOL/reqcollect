.PHONY: all build merge collector clean render

SUBMISSIONS := $(wildcard submissions/*.sexp)

all: build

build:
	dune build

merge: build
	mkdir -p repo
	./_build/default/bin/main.exe merge \
	  schemas/example.v1.sexp \
	  $(SUBMISSIONS) \
	  -o repo/merged.sexp -b batch-001

render: build
	mkdir -p repo
	./_build/default/bin/main.exe render \
	  repo/merged.sexp \
	  -s schemas/example.v1.sexp \
	  -t web/merged_template.html \
	  -o repo/merged.html
	@echo "Open repo/merged.html in a browser"

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




