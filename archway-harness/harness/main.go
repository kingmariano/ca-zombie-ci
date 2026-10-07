// archway-harness: local execution lab for CosmWasm contracts on the exact
// wasmvm/Wasmer stack that Archway mainnet runs (wasmvm v1.5.5, Wasmer 4.2.2
// Singlepass). Store -> Instantiate -> Execute with gas metering, in-process.
//
// Usage:
//
//	go run . -wasm contract.wasm -init '{"count":1}' -exec '{"increment":{}}' -repeat 3
//
// Exit codes: 0 ok; 1 error (contract/VM error reported in JSON); signal/other
// (e.g. 139 = segfault, 134 = abort) means the VM/contract crashed the process.
package main

import (
	"bufio"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"sort"
	"strings"
	"time"
	"unsafe"

	wasmvm "github.com/CosmWasm/wasmvm"
	"github.com/CosmWasm/wasmvm/types"
)

const defaultCapabilities = "iterator,staking,stargate,cosmwasm_1_1,cosmwasm_1_2,cosmwasm_1_3,cosmwasm_1_4"

// ---------------- mock KVStore ----------------

type memStore struct{ m map[string][]byte }

func newMemStore() *memStore { return &memStore{m: make(map[string][]byte)} }

func (s *memStore) Get(k []byte) []byte {
	if v, ok := s.m[string(k)]; ok {
		return v
	}
	return nil
}
func (s *memStore) Set(k, v []byte) { s.m[string(k)] = append([]byte(nil), v...) }
func (s *memStore) Delete(k []byte) { delete(s.m, string(k)) }
func (s *memStore) Iterator(start, end []byte) types.Iterator {
	return newIter(s, start, end, false)
}
func (s *memStore) ReverseIterator(start, end []byte) types.Iterator {
	return newIter(s, start, end, true)
}

type iter struct {
	keys       [][]byte
	vals       [][]byte
	i          int
	start, end []byte
}

func newIter(s *memStore, start, end []byte, reverse bool) *iter {
	all := make([]string, 0, len(s.m))
	for k := range s.m {
		if start != nil && k < string(start) {
			continue
		}
		if end != nil && k >= string(end) {
			continue
		}
		all = append(all, k)
	}
	sort.Strings(all)
	if reverse {
		for i, j := 0, len(all)-1; i < j; i, j = i+1, j-1 {
			all[i], all[j] = all[j], all[i]
		}
	}
	it := &iter{start: start, end: end}
	for _, k := range all {
		it.keys = append(it.keys, []byte(k))
		it.vals = append(it.vals, s.m[k])
	}
	return it
}

func (it *iter) Domain() ([]byte, []byte) { return it.start, it.end }
func (it *iter) Valid() bool              { return it.i >= 0 && it.i < len(it.keys) }
func (it *iter) Next()                    { it.i++ }
func (it *iter) Key() []byte              { return it.keys[it.i] }
func (it *iter) Value() []byte            { return it.vals[it.i] }
func (it *iter) Error() error             { return nil }
func (it *iter) Close() error             { return nil }

// ---------------- mock gas meter / querier / go API ----------------

type mockGasMeter struct{ consumed uint64 }

func (g *mockGasMeter) GasConsumed() types.Gas { return g.consumed }

type mockQuerier struct{ gas uint64 }

func (q *mockQuerier) Query(req types.QueryRequest, gasLimit uint64) ([]byte, error) {
	return nil, fmt.Errorf("queries disabled in harness")
}
func (q *mockQuerier) GasConsumed() uint64 { return q.gas }

// nestedQuerier routes Smart queries to a second contract, producing a nested wasmvm
// execution (the outer contract stays suspended while the inner one runs on a new stack).
type nestedQuerier struct {
	vm        *wasmvm.VM
	checksum  wasmvm.Checksum
	checksum2 wasmvm.Checksum
	depth     int
	scan      bool
	env       types.Env
	store     types.KVStore
	goapi     types.GoAPI
	gasLimit  uint64
	deserCost types.UFraction
	calls     int
}

func (q *nestedQuerier) Query(req types.QueryRequest, gasLimit uint64) ([]byte, error) {
	if req.Wasm == nil || req.Wasm.Smart == nil {
		return nil, fmt.Errorf("nestedQuerier: only smart queries are supported")
	}
	q.calls++
	q.depth++
	defer func() { q.depth-- }()
	if q.scan {
		scanPlants(q.depth, q.calls)
	}
	cs := q.checksum
	if q.depth >= 2 {
		cs = q.checksum2
	}
	resp, _, err := q.vm.Query(cs, q.env, req.Wasm.Smart.Msg, q.store, q.goapi, q, &mockGasMeter{}, q.gasLimit, q.deserCost)
	return resp, err
}
func (q *nestedQuerier) GasConsumed() uint64 { return 0 }

var dumpAll bool

// scanPlants: while a wasm execution is suspended in this callback, find every
// occurrence of the distinct plant values 0x0041414100000000+k in mapped ~1 MiB
// fiber-stack regions; report a per-region summary with the newest (highest) hit.
func scanPlants(depth int, n int) {
	f, err := os.Open("/proc/self/maps")
	if err != nil {
		return
	}
	defer f.Close()
	type reg struct{ lo, hi uint64 }
	var regs []reg
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 1<<20), 1<<20)
	for sc.Scan() {
		ln := sc.Text()
		if !strings.Contains(ln, "rw") {
			continue
		}
		if strings.Contains(ln, "[stack]") || strings.Contains(ln, "[heap]") ||
			strings.Contains(ln, "vvar") || strings.Contains(ln, "vdso") {
			continue
		}
		var lo, hi uint64
		if k, _ := fmt.Sscanf(ln, "%x-%x", &lo, &hi); k != 2 {
			continue
		}
		sz := hi - lo
		if sz < 1<<20 || sz > (1<<20)+(512<<10) {
			continue
		}
		regs = append(regs, reg{lo, hi})
	}
	var parts []string
	for _, r := range regs {
		count := 0
		var newestAddr uint64 = 0
		var newestSeq string
		for a := r.lo; a+8 <= r.hi; a += 8 {
			v := *(*uint64)(unsafe.Pointer(uintptr(a)))
			if (v>>32) == 0x00414141 && (v&0xffffffff) < 16 {
				count++
				if a >= newestAddr {
					newestAddr = a
					newestSeq = fmt.Sprintf("k%d", v&0xffffffff)
				}
			}
		}
		if count > 0 {
			parts = append(parts, fmt.Sprintf("reg=0x%x hits=%d newest=%s@0x%x", r.lo, count, newestSeq, newestAddr))
		}
		// top-of-region dump (last 0x1c0 bytes): JIT-ish pointers and plants only
		var topv []string
		for a := r.hi - 0x1000; a+8 <= r.hi; a += 8 {
			v := *(*uint64)(unsafe.Pointer(uintptr(a)))
			if dumpAll || (v>>32) == 0x00414141 || (v >= 0x7f0000000000 && v < 0x800000000000) || (v>>32) == 0xcafebabe {
				topv = append(topv, fmt.Sprintf("+%x=0x%x", a-r.lo, v))
			}
		}
		if len(topv) > 0 {
			parts = append(parts, fmt.Sprintf("TOP[0x%x]: %s", r.lo, strings.Join(topv, " ")))
		}
	}
	fmt.Fprintf(os.Stderr, "PLANTSCAN d=%d n=%d | %s\n", depth, n, strings.Join(parts, " | "))
}

func humanAddress(canonical []byte) (string, uint64, error) {
	return hex.EncodeToString(canonical), 10, nil
}
func canonicalAddress(human string) ([]byte, uint64, error) {
	b, err := hex.DecodeString(human)
	return b, 10, err
}

// ---------------- main ----------------

type stepResult struct {
	Gas      uint64          `json:"gas"`
	Error    string          `json:"error,omitempty"`
	Response json.RawMessage `json:"response,omitempty"`
}

type report struct {
	Wasm         string       `json:"wasm"`
	Checksum     string       `json:"checksum"`
	Capabilities string       `json:"capabilities"`
	MemoryLimit  uint         `json:"memory_limit_mb"`
	Instantiate  stepResult   `json:"instantiate"`
	Executes     []stepResult `json:"executes"`
	TotalGas     uint64       `json:"total_gas"`
}

func main() {
	wasmFile := flag.String("wasm", "", "path to contract .wasm (required)")
	initMsg := flag.String("init", "{}", "instantiate msg JSON")
	execMsg := flag.String("exec", "{}", "execute msg JSON")
	gas := flag.Uint64("gas", 500_000_000_000, "gas limit per call (wasmvm gas units)")
	repeat := flag.Int("repeat", 1, "number of execute calls")
	capabilities := flag.String("capabilities", defaultCapabilities, "wasmvm capabilities")
	memoryLimit := flag.Uint("memory-mb", 32, "memory limit (MiB)")
	printDebug := flag.Bool("print-debug", false, "print VM debug output")
	outFile := flag.String("out", "", "write JSON report to this file")
	triggerFile := flag.String("trigger", "", "drift trigger .wasm (enables nested holder/trigger mode)")
	benignFile := flag.String("benign", "", "benign trigger .wasm for nested warm-ups")
	warmups := flag.Int("warmups", 0, "nested warm-up executions to grow the coroutine stack pool")
	queryMsg := flag.String("query", "", "run a query on the contract instead of execute")
	scanFlag := flag.Bool("scan", false, "scan fiber-stack mappings for distinct plant values during nested queries")
	dumpAllFlag := flag.Bool("dumpall", false, "dump ALL qwords in the scanned top windows (writer forensics)")
	flag.Parse()
	dumpAll = *dumpAllFlag

	if *wasmFile == "" {
		fmt.Fprintln(os.Stderr, "usage: harness -wasm contract.wasm [-init json] [-exec json] [-repeat N] [-gas N]")
		os.Exit(2)
	}
	code, err := os.ReadFile(*wasmFile)
	if err != nil {
		fmt.Fprintln(os.Stderr, "read wasm:", err)
		os.Exit(2)
	}


	dataDir, err := os.MkdirTemp("", "wasmvm-harness-")
	if err != nil {
		fmt.Fprintln(os.Stderr, "tmpdir:", err)
		os.Exit(2)
	}
	defer os.RemoveAll(dataDir)

	vm, err := wasmvm.NewVM(dataDir, *capabilities, uint32(*memoryLimit), *printDebug, 0)
	if err != nil {
		fmt.Fprintln(os.Stderr, "NewVM:", err)
		os.Exit(2)
	}
	defer vm.Cleanup()

	checksum, err := vm.StoreCode(code)
	if err != nil {
		fmt.Fprintln(os.Stderr, "StoreCode:", err)
		os.Exit(2)
	}

	// nested mode: store the drift trigger + the benign warm-up trigger
	var triggerChecksum, benignChecksum wasmvm.Checksum
	if *triggerFile != "" {
		tcode, err := os.ReadFile(*triggerFile)
		if err != nil {
			fmt.Fprintln(os.Stderr, "read trigger:", err)
			os.Exit(2)
		}
		triggerChecksum, err = vm.StoreCode(tcode)
		if err != nil {
			fmt.Fprintln(os.Stderr, "StoreCode trigger:", err)
			os.Exit(2)
		}
	}
	if *benignFile != "" {
		bcode, err := os.ReadFile(*benignFile)
		if err != nil {
			fmt.Fprintln(os.Stderr, "read benign:", err)
			os.Exit(2)
		}
		benignChecksum, err = vm.StoreCode(bcode)
		if err != nil {
			fmt.Fprintln(os.Stderr, "StoreCode benign:", err)
			os.Exit(2)
		}
	}

	store := newMemStore()
	env := types.Env{
		Block: types.BlockInfo{
			Height:  17645027,
			Time:    uint64(time.Now().UnixNano()),
			ChainID: "archway-1",
		},
		Transaction: &types.TransactionInfo{Index: 0},
		Contract:    types.ContractInfo{Address: "archway1harnesscontract0000000000000000000000000"},
	}
	info := types.MessageInfo{
		Sender: "archway1harnesssender00000000000000000000000000",
		Funds:  types.Coins{},
	}
	goapi := types.GoAPI{HumanAddress: humanAddress, CanonicalAddress: canonicalAddress}
	var querier types.Querier = &mockQuerier{}
	deserCost := types.UFraction{Numerator: 1, Denominator: 1}

	rep := report{
		Wasm:         *wasmFile,
		Checksum:     hex.EncodeToString(checksum),
		Capabilities: *capabilities,
		MemoryLimit:  *memoryLimit,
	}

	// instantiate
	resp, g, err := vm.Instantiate(checksum, env, info, []byte(*initMsg), store, goapi, querier, &mockGasMeter{}, *gas, deserCost)
	rep.Instantiate = stepResult{Gas: g}
	if err != nil {
		rep.Instantiate.Error = err.Error()
	} else if resp != nil {
		b, _ := json.Marshal(resp)
		rep.Instantiate.Response = b
	}
	rep.TotalGas += g
	if err != nil {
		writeReport(rep, *outFile)
		fmt.Fprintln(os.Stderr, "instantiate error:", err)
		os.Exit(1)
	}

	// query-only mode: exercise the contract's query entry point directly
	if *queryMsg != "" {
		qres, qgas, qerr := vm.Query(checksum, env, []byte(*queryMsg), store, goapi, querier, &mockGasMeter{}, *gas, deserCost)
		emsg := ""
		if qerr != nil {
			emsg = qerr.Error()
		}
		fmt.Fprintf(os.Stderr, "query gas=%d err=%v\n", qgas, emsg)
		sr := stepResult{Gas: qgas, Error: emsg}
		if qres != nil {
			sr.Response = qres
		}
		rep.Executes = append(rep.Executes, sr)
		writeReport(rep, *outFile)
		return
	}

	// nested mode: instantiate the triggers, warm up the coroutine stack pool, then attack
	if *triggerFile != "" {
		if _, _, err := vm.Instantiate(triggerChecksum, env, info, []byte("{}"), store, goapi, &mockQuerier{}, &mockGasMeter{}, *gas, deserCost); err != nil {
			fmt.Fprintln(os.Stderr, "instantiate trigger:", err)
			os.Exit(2)
		}
		nq := &nestedQuerier{vm: vm, checksum: triggerChecksum, env: env, store: store, goapi: goapi, gasLimit: *gas, deserCost: deserCost, scan: *scanFlag}
		nq.checksum2 = benignChecksum
		if *benignFile != "" && *warmups > 0 {
			if _, _, err := vm.Instantiate(benignChecksum, env, info, []byte("{}"), store, goapi, &mockQuerier{}, &mockGasMeter{}, *gas, deserCost); err != nil {
				fmt.Fprintln(os.Stderr, "instantiate benign:", err)
				os.Exit(2)
			}
			nq.checksum = benignChecksum
			for i := 0; i < *warmups; i++ {
				_, _, werr := vm.Execute(checksum, env, info, []byte(*execMsg), store, goapi, nq, &mockGasMeter{}, *gas, deserCost)
				fmt.Fprintf(os.Stderr, "warmup %d err=%v nested_calls=%d\n", i, werr, nq.calls)
			}
		}
		nq.checksum = triggerChecksum
		querier = nq
		fmt.Fprintf(os.Stderr, "nested mode armed: trigger=%x warmups=%d\n", triggerChecksum, *warmups)
	}

	// execute N times
	for i := 0; i < *repeat; i++ {
		resp, g, err := vm.Execute(checksum, env, info, []byte(*execMsg), store, goapi, querier, &mockGasMeter{}, *gas, deserCost)
		sr := stepResult{Gas: g}
		if err != nil {
			sr.Error = err.Error()
		} else if resp != nil {
			b, _ := json.Marshal(resp)
			sr.Response = b
		}
		rep.Executes = append(rep.Executes, sr)
		rep.TotalGas += g
		if err != nil {
			writeReport(rep, *outFile)
			fmt.Fprintln(os.Stderr, "execute error:", err)
			os.Exit(1)
		}
	}

	writeReport(rep, *outFile)
	fmt.Printf("OK checksum=%s instantiate_gas=%d exec_gas=%d total_gas=%d\n",
		rep.Checksum, rep.Instantiate.Gas, rep.Executes[0].Gas, rep.TotalGas)
}

func writeReport(r report, out string) {
	b, _ := json.MarshalIndent(r, "", "  ")
	if out != "" {
		_ = os.WriteFile(out, b, 0o644)
	}
	fmt.Println(string(b))
}
