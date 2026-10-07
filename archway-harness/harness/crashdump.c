// crashdump.c — minimal crash-time diagnostic for the nested harness.
// Installs SIGSEGV/SIGILL/SIGBUS/SIGFPE handlers that append a report with the
// full register file, the code bytes at RIP (clamped to the page), and a stack
// window at RSP — then exits. This is the "mini debugger" equivalent for the
// wasmvm JIT crashes (no gdb needed).
#define _GNU_SOURCE
#include <signal.h>
#include <ucontext.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <fcntl.h>

void crashdiag_install_now(void);  // fwd decl (used by the constructor)

static void crashdiag(int sig, siginfo_t *si, void *uctx) {
    ucontext_t *uc = (ucontext_t *)uctx;
    greg_t *g = uc->uc_mcontext.gregs;
    char buf[16384];
    int n = 0;
    n += snprintf(buf + n, sizeof(buf) - n, "=== CRASHDIAG sig=%d addr=%p ===\n", sig, si->si_addr);
    n += snprintf(buf + n, sizeof(buf) - n,
        "RIP=%#llx RSP=%#llx RBP=%#llx RAX=%#llx RBX=%#llx RCX=%#llx RDX=%#llx\n"
        "RSI=%#llx RDI=%#llx R8=%#llx R9=%#llx R10=%#llx R11=%#llx R12=%#llx R13=%#llx R14=%#llx R15=%#llx\n",
        (unsigned long long)g[REG_RIP], (unsigned long long)g[REG_RSP], (unsigned long long)g[REG_RBP],
        (unsigned long long)g[REG_RAX], (unsigned long long)g[REG_RBX], (unsigned long long)g[REG_RCX],
        (unsigned long long)g[REG_RDX], (unsigned long long)g[REG_RSI], (unsigned long long)g[REG_RDI],
        (unsigned long long)g[REG_R8], (unsigned long long)g[REG_R9], (unsigned long long)g[REG_R10],
        (unsigned long long)g[REG_R11], (unsigned long long)g[REG_R12], (unsigned long long)g[REG_R13],
        (unsigned long long)g[REG_R14], (unsigned long long)g[REG_R15]);
    // code bytes at RIP, clamped to the containing page
    unsigned long rip = (unsigned long)g[REG_RIP];
    unsigned long page_off = rip & 0xfff;
    int back = page_off < 32 ? (int)page_off : 32;
    int fwd = 64;
    const unsigned char *code = (const unsigned char *)rip;
    n += snprintf(buf + n, sizeof(buf) - n, "CODE base=%#lx back=%d:", (unsigned long)(rip - back), back);
    for (int i = -back; i < fwd; i++) {
        n += snprintf(buf + n, sizeof(buf) - n, " %02x", code[i]);
    }
    n += snprintf(buf + n, sizeof(buf) - n, "\n");
    // write the essential part FIRST (survives a nested fault reading the stack window)
    int fd = open("/tmp/harness_crash_report.txt", O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd >= 0) { ssize_t w = write(fd, buf, n); (void)w; }
    ssize_t w2 = write(2, buf, n);
    (void)w2;

    n = 0;
    n += snprintf(buf + n, sizeof(buf) - n, "RSPWINDOW:");
    const unsigned char *rsp = (const unsigned char *)g[REG_RSP];
    for (int i = 0; i < 512; i += 8) {
        unsigned long long v;
        memcpy(&v, rsp + i, 8);
        n += snprintf(buf + n, sizeof(buf) - n, " +%x=%#llx", i, v);
    }
    n += snprintf(buf + n, sizeof(buf) - n, "\n\n");
    if (fd >= 0) { ssize_t w = write(fd, buf, n); close(fd); }
    ssize_t w = write(2, buf, n);
    (void)w;
    _exit(139);
}

__attribute__((constructor)) static void crashdiag_install(void) {
    crashdiag_install_now();
}

void crashdiag_install_now(void) {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = crashdiag;
    sa.sa_flags = SA_SIGINFO;
    sigaction(SIGSEGV, &sa, NULL);
    sigaction(SIGILL, &sa, NULL);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGFPE, &sa, NULL);
}
