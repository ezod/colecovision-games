BUILDDIR= build

.PHONY: all package clean

all: $(BUILDDIR)/$(PROJECT).rom

$(BUILDDIR):
	mkdir -p $@

$(BUILDDIR)/$(PROJECT).rom: src/$(PROJECT).asm ../../include/coleco.asm ../../include/library.asm | $(BUILDDIR)
	$(ASM) -Q $< $@

$(BUILDDIR)/$(PROJECT).pkg: $(BUILDDIR)/$(PROJECT).rom
	$(PACKAGER) $< > $@

package: $(BUILDDIR)/$(PROJECT).pkg

clean:
	rm -rf $(BUILDDIR)
