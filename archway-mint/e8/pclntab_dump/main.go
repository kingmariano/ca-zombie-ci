// pclntab_dump: enumerate every function in a Go binary via its .gopclntab
// (works even when the ELF symbol table is stripped — which is the case for
// the archwayd release binary).
//
// Output: one line per function: "<entry-hex>\t<full-go-name>", sorted by entry.
// Diagnostics go to stderr. Exit code 0 on success.
package main

import (
	"debug/elf"
	"debug/gosym"
	"fmt"
	"os"
	"sort"
)

type funcEntry struct {
	entry uint64
	name  string
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: pclntab_dump <go-binary>")
		os.Exit(2)
	}
	path := os.Args[1]

	f, err := elf.Open(path)
	if err != nil {
		fmt.Fprintln(os.Stderr, "elf open:", err)
		os.Exit(1)
	}
	defer f.Close()

	// Locate the pclntab. Modern Go: .gopclntab (non-PIE) or
	// .data.rel.ro.gopclntab (PIE / external linking variants).
	var pcln *elf.Section
	for _, name := range []string{".gopclntab", ".data.rel.ro.gopclntab"} {
		if s := f.Section(name); s != nil {
			pcln = s
			break
		}
	}
	if pcln == nil {
		fmt.Fprintln(os.Stderr, "no .gopclntab section found")
		os.Exit(1)
	}

	data, err := pcln.Data()
	if err != nil {
		fmt.Fprintln(os.Stderr, "pclntab read:", err)
		os.Exit(1)
	}
	fmt.Fprintf(os.Stderr, "pclntab: %s at 0x%x, %d bytes\n", pcln.Name, pcln.Addr, len(data))

	// The base address passed to gosym is the address the pclntab's PCs are
	// relative to. For non-PIE ET_EXEC that is the .text address; some binaries
	// want the pclntab's own address. Try both.
	candidates := make([]uint64, 0, 2)
	if t := f.Section(".text"); t != nil {
		candidates = append(candidates, t.Addr)
	}
	candidates = append(candidates, pcln.Addr)

	var funcs []funcEntry
	var lastErr error
	for _, base := range candidates {
		lt := gosym.NewLineTable(data, base)
		tab, err := gosym.NewTable(nil, lt)
		if err != nil {
			lastErr = err
			continue
		}
		funcs = funcs[:0]
		for _, gfn := range tab.Funcs {
			funcs = append(funcs, funcEntry{gfn.Entry, gfn.Name})
		}
		if len(funcs) > 0 {
			fmt.Fprintf(os.Stderr, "parsed with base=0x%x: %d functions\n", base, len(funcs))
			break
		}
	}
	if len(funcs) == 0 {
		if lastErr != nil {
			fmt.Fprintln(os.Stderr, "gosym parse failed:", lastErr)
		} else {
			fmt.Fprintln(os.Stderr, "no functions parsed")
		}
		os.Exit(1)
	}

	sort.Slice(funcs, func(i, j int) bool { return funcs[i].entry < funcs[j].entry })
	for _, x := range funcs {
		fmt.Printf("%x\t%s\n", x.entry, x.name)
	}
}
