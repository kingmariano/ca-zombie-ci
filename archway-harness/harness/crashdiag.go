package main

// crashdiag.go — cgo bridge that makes sure the C crash-report handler
// (crashdump.c) is installed AFTER the Go runtime installs its own signal
// handlers, so our register/stack/code dump wins for the cgo/wasmvm crashes.

/*
void crashdiag_install_now(void);
*/
import "C"

// crashdiagInstall re-installs the crash handler. Call as late as possible
// (after runtime init) so it overrides the Go runtime's SIGSEGV/SIGILL setup.
func crashdiagInstall() {
	C.crashdiag_install_now()
}
