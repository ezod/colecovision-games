BUILDDIR= build
INCLUDEDIR= ../../include

.PHONY: all package clean

all: $(BUILDDIR)/$(PROJECT).rom

$(BUILDDIR):
	mkdir -p $@

$(BUILDDIR)/$(PROJECT).rom: $(PROJECT).asm $(INCLUDEDIR)/*.asm | $(BUILDDIR)
	$(ASM) -Q -I$(INCLUDEDIR) $< $@

$(BUILDDIR)/$(PROJECT).pkg: $(BUILDDIR)/$(PROJECT).rom
	$(PACKAGER) $< > $@

package: $(BUILDDIR)/$(PROJECT).pkg

clean:
	rm -rf $(BUILDDIR)
